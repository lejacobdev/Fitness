import SwiftUI

// MARK: - The workout editor

/// Change anything in a workout: swap an exercise for another, add and
/// remove exercises, drag them into a new order, and set the sets, reps,
/// time and rest of each one.
struct WorkoutEditorView: View {
    let heading: String
    let sportSlug: String?
    /// "Back to the app's version" (for a planned workout the athlete edited).
    var onReset: (() -> Void)? = nil
    let onSave: (CustomWorkout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomWorkout
    @State private var catalogue = Catalogue()
    @State private var picking: Picking?
    @State private var dosing: CustomItem?
    @State private var confirmReset = false
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    /// Adding a new exercise, or swapping the one with this id.
    struct Picking: Identifiable {
        let id = UUID()
        let replacing: UUID?
    }

    init(heading: String, workout: CustomWorkout, sportSlug: String?, onReset: (() -> Void)? = nil, onSave: @escaping (CustomWorkout) -> Void) {
        self.heading = heading
        self.sportSlug = sportSlug
        self.onReset = onReset
        self.onSave = onSave
        _draft = State(initialValue: workout)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $draft.title)
                        .font(.title3.weight(.semibold))
                    Label("About \(draft.estimatedMinutes) min · \(draft.items.count) exercises", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text("Tap an exercise to change its sets, reps and rest. ⇄ swaps it for another, swipe left removes it, and Reorder lets you drag them into a new order.")
                }
                .listRowBackground(AppTheme.card)

                Section {
                    ForEach(draft.items) { item in
                        row(item)
                    }
                    .onDelete { draft.items.remove(atOffsets: $0) }
                    #if os(iOS)
                    .onMove { draft.items.move(fromOffsets: $0, toOffset: $1) }
                    #endif
                    Button {
                        picking = Picking(replacing: nil)
                    } label: {
                        Label("Add an exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        #if os(iOS)
                        Button(editMode == .active ? "Done" : "Reorder") {
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        }
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                        #endif
                    }
                }
                .listRowBackground(AppTheme.card)

                if let onReset {
                    Section {
                        Button("Back to the app's version", role: .destructive) { confirmReset = true }
                    } footer: {
                        Text("Your changes go; the workout is built for you again each week.")
                    }
                    .listRowBackground(AppTheme.card)
                    .confirmationDialog("Undo your changes to this workout?", isPresented: $confirmReset, titleVisibility: .visible) {
                        Button("Undo my changes", role: .destructive) {
                            onReset()
                            dismiss()
                        }
                    }
                }
            }
            #if os(iOS)
            .environment(\.editMode, $editMode)
            #endif
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(heading)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = draft
                        saved.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My workout" : draft.title
                        onSave(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.items.isEmpty)
                }
            }
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
            .sheet(item: $picking) { picking in
                ExercisePickerView(catalogue: catalogue, sportSlug: sportSlug, suggestions: suggestions(for: picking)) { item in
                    if let id = picking.replacing, let index = draft.items.firstIndex(where: { $0.id == id }) {
                        draft.items[index] = CustomItem(item: item)
                    } else {
                        draft.items.append(CustomItem(item: item))
                    }
                    self.picking = nil
                }
            }
            .sheet(item: $dosing) { item in
                DoseEditorSheet(name: name(item.itemSlug), item: item) { updated in
                    if let index = draft.items.firstIndex(where: { $0.id == updated.id }) { draft.items[index] = updated }
                }
            }
        }
    }

    private func name(_ slug: String) -> String { catalogue.item(slug)?.name ?? displayName(forSlug: slug) }

    private func suggestions(for picking: Picking) -> [CatalogueItem] {
        guard let id = picking.replacing, let current = draft.items.first(where: { $0.id == id }) else { return [] }
        return alternatives(for: current)
    }

    private func row(_ item: CustomItem) -> some View {
        HStack(spacing: 12) {
            Button { dosing = item } label: {
                HStack(spacing: 12) {
                    ItemThumbnail(item: catalogue.item(item.itemSlug), size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name(item.itemSlug))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(DoseFormatter.text(item.dose)) · rest \(item.restSec) s")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { picking = Picking(replacing: item.id) } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap \(name(item.itemSlug))")
        }
    }

    /// Good swaps: the exercise's own substitutes, easier and harder
    /// versions, then others that train the same thing.
    private func alternatives(for item: CustomItem) -> [CatalogueItem] {
        guard let current = catalogue.item(item.itemSlug) else { return [] }
        var slugs = current.substitutes + current.regressions + current.progressions
        if let quality = current.qualities.max(by: { $0.value < $1.value })?.key {
            let similar = catalogue.itemsBySlug.values
                .filter { $0.kind == current.kind && ($0.qualities[quality] ?? 0) >= 0.6 && $0.fits(sport: sportSlug, position: nil) && $0.variant == nil }
                .sorted { ($0.qualities[quality] ?? 0) > ($1.qualities[quality] ?? 0) }
                .prefix(12).map(\.slug)
            slugs += similar
        }
        var seen: Set<String> = [current.slug]
        return slugs.compactMap { slug in
            guard seen.insert(slug).inserted else { return nil }
            return catalogue.item(slug)
        }
    }
}

/// Sets, reps (or time, distance, jumps), each side, and rest.
struct DoseEditorSheet: View {
    let name: String
    @State var item: CustomItem
    let onDone: (CustomItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Sets: \(item.dose.sets)", value: $item.dose.sets, in: 1...10)
                    switch item.dose.kind {
                    case "time":
                        Stepper("Time: \(DoseFormatter.duration(item.dose.seconds ?? 30))",
                                value: Binding(get: { item.dose.seconds ?? 30 }, set: { item.dose.seconds = $0 }), in: 5...900, step: 5)
                    case "distance":
                        Stepper("Distance: \(Int(item.dose.metres ?? 20)) m",
                                value: Binding(get: { Int(item.dose.metres ?? 20) }, set: { item.dose.metres = Double($0) }), in: 5...10000, step: 5)
                    case "contacts":
                        Stepper("Jumps: \(item.dose.contacts ?? 10)",
                                value: Binding(get: { item.dose.contacts ?? 10 }, set: { item.dose.contacts = $0 }), in: 1...100)
                    default:
                        Stepper("Reps: \(item.dose.reps ?? 10)",
                                value: Binding(get: { item.dose.reps ?? 10 }, set: { item.dose.reps = $0 }), in: 1...100)
                    }
                    Toggle("Each side", isOn: Binding(get: { item.dose.perSide == true }, set: { item.dose.perSide = $0 ? true : nil }))
                } footer: {
                    Text(DoseFormatter.text(item.dose))
                }
                Section {
                    Stepper("Rest: \(item.restSec) s", value: $item.restSec, in: 0...600, step: 15)
                } footer: {
                    Text("Rest between sets.")
                }
            }
            .navigationTitle(name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The library, to add an exercise or swap one: general exercises and the
/// athlete's own sport's drills, searchable, with good swaps first.
struct ExercisePickerView: View {
    let catalogue: Catalogue
    let sportSlug: String?
    var suggestions: [CatalogueItem] = []
    let onPick: (CatalogueItem) -> Void
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    private var results: [CatalogueItem] {
        let usable = catalogue.itemsBySlug.values.filter { $0.itemSportSlug == nil || $0.itemSportSlug == sportSlug }
        let query = search.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return usable.filter { $0.variant == nil }.sorted { $0.name < $1.name } }
        return CatalogueSearch.rank(Array(usable), query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if !suggestions.isEmpty, search.isEmpty {
                    Section("Good swaps") {
                        ForEach(suggestions, id: \.slug) { pickRow($0) }
                    }
                }
                Section(search.isEmpty ? "All exercises" : "Results") {
                    ForEach(results.prefix(300), id: \.slug) { pickRow($0) }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle(suggestions.isEmpty ? "Add an exercise" : "Swap for…")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .overlay {
                if catalogue.itemsBySlug.isEmpty {
                    Text("Your exercise library is still downloading.").foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private func pickRow(_ item: CatalogueItem) -> some View {
        Button { onPick(item) } label: {
            HStack(spacing: 12) {
                ItemThumbnail(item: item, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline).foregroundStyle(AppTheme.ink)
                    Text(DoseFormatter.text(item.defaultDose)).font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - The week's shape

/// How many gym days, on which days, and how long — or let the app decide.
struct PlanSettingsSheet: View {
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var settings = PlanCustomizationStore.load().settings
    @State private var chooseDays = !PlanCustomizationStore.load().settings.weekdays.isEmpty

    /// Monday first.
    private let weekdays: [(number: Int, letter: String)] = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle("Your week", subtitle: "Pick your gym days and how long each one is — or leave it to the app, which works around your practices, games and season.")

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Gym days")
                        Picker("Gym days", selection: $chooseDays) {
                            Text("Automatic").tag(false)
                            Text("I choose").tag(true)
                        }
                        #if os(iOS)
                        .pickerStyle(.segmented)
                        #endif
                        if chooseDays {
                            HStack(spacing: 8) {
                                ForEach(weekdays, id: \.number) { day in
                                    let on = settings.weekdays.contains(day.number)
                                    Button {
                                        if on { settings.weekdays.removeAll { $0 == day.number } } else { settings.weekdays.append(day.number) }
                                    } label: {
                                        Text(day.letter)
                                            .font(.headline)
                                            .foregroundStyle(on ? AppTheme.onAccent : AppTheme.ink)
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                            .background(on ? AppTheme.accent : AppTheme.fill, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Text(settings.weekdays.isEmpty ? "Tap the days you want to train in the gym." : "\(settings.weekdays.count) gym day\(settings.weekdays.count == 1 ? "" : "s") a week, always on these days.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        } else {
                            Stepper(value: Binding(get: { settings.sessionsPerWeek ?? 0 }, set: { settings.sessionsPerWeek = $0 == 0 ? nil : $0 }), in: 0...6) {
                                Text(settings.sessionsPerWeek.map { "\($0) gym day\($0 == 1 ? "" : "s") a week" } ?? "As many as your season calls for")
                                    .font(.headline)
                            }
                            Text("The app places them on days without practice or games.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Length of a gym day")
                        WrapLayout(spacing: 8) {
                            chip("Automatic", selected: settings.minutesPerSession == nil) { settings.minutesPerSession = nil }
                            ForEach(PlanSettings.minuteChoices, id: \.self) { minutes in
                                chip("\(minutes) min", selected: settings.minutesPerSession == minutes) { settings.minutesPerSession = minutes }
                            }
                        }
                    }

                    Button("Save") {
                        var saved = settings
                        if !chooseDays { saved.weekdays = [] } else { saved.sessionsPerWeek = nil }
                        PlanCustomizationStore.setSettings(saved)
                        onChanged()
                        dismiss()
                    }
                    .buttonStyle(.primary)
                    .disabled(chooseDays && settings.weekdays.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .foregroundStyle(selected ? AppTheme.onAccent : AppTheme.ink)
                .background(selected ? AppTheme.accent : AppTheme.fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sharing a workout (Pro)

/// Shares a workout under a code (a Pro feature), then shows the code, the
/// link and the QR code to pass on.
struct ShareWorkoutSheet: View {
    let workout: CustomWorkout
    let athlete: Athlete
    /// Called with the code once it exists (to remember it on the workout).
    var onShared: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var code: String?
    @State private var working = false
    @State private var message: String?
    @State private var showingPaywall = false

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenTitle("Share “\(workout.title)”", subtitle: "Anyone with the code, link or QR code gets a copy of this workout — \(workout.items.count) exercises, about \(workout.estimatedMinutes) min.")
                    if let code {
                        CodeShareView(link: .workout(code), message: "Try my workout “\(workout.title)” in Athlete OS")
                    } else if !ProAccess.isPro {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Sharing workouts is part of Athlete OS Pro", systemImage: "lock.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text("Anyone can open a shared workout for free — sharing your own takes Pro.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            Button("See Pro") { showingPaywall = true }.buttonStyle(.primary)
                        }
                        .cardStyle(padding: 18)
                    } else {
                        if let message {
                            Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.red)
                        }
                        Button {
                            Task { await share() }
                        } label: {
                            if working { ProgressView() } else { Label("Create the code", systemImage: "qrcode") }
                        }
                        .buttonStyle(.primary)
                        .disabled(working)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .onAppear { code = workout.shareCode }
            .proPaywall(isPresented: $showingPaywall, athlete: athlete, feature: .shareWorkouts)
        }
    }

    private func share() async {
        guard let token = try? KeychainTokenStore().read() else {
            message = "Sign in first (Me → Account) — shared workouts live on your account."
            return
        }
        working = true
        defer { working = false }
        do {
            let new = try await apiClient.shareWorkout(workout, sportSlug: athlete.activeSport?.sportSlug, sessionToken: token)
            code = new
            onShared(new)
        } catch {
            message = "Couldn't share it — check your connection and try again."
        }
    }
}

// MARK: - Getting a shared workout

/// Enter (or scan, or open a link to) a workout code: see the workout, then
/// keep it in My workouts or start it now. Free for everyone.
struct SharedWorkoutSheet: View {
    var initialCode: String? = nil
    let onSaved: (CustomWorkout) -> Void
    let onStart: (CustomWorkout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var shared: APIClient.SharedWorkout?
    @State private var loading = false
    @State private var message: String?
    @State private var catalogue = Catalogue()

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Add a workout", subtitle: "Got a code from a teammate or coach? Enter it, paste the link or scan the QR code.")
                    CodeField(placeholder: "ABC234", text: $code)
                    if let message {
                        Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.red)
                    }
                    if let shared {
                        preview(shared)
                    } else {
                        Button {
                            Task { await load() }
                        } label: {
                            if loading { ProgressView() } else { Text("Open") }
                        }
                        .buttonStyle(.primary)
                        .disabled(DeepLink.normalize(code) == nil || loading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                if let initialCode, shared == nil {
                    code = initialCode
                    await load()
                }
            }
            .onChange(of: code) {
                if DeepLink.normalize(code) != shared?.code { shared = nil }
            }
        }
    }

    private func preview(_ shared: APIClient.SharedWorkout) -> some View {
        let workout = shared.workout
        return VStack(alignment: .leading, spacing: 14) {
            Text(shared.title).font(.title2.bold()).foregroundStyle(AppTheme.ink)
            Text("\(workout.items.count) exercises · about \(workout.estimatedMinutes) min")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(workout.items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)").font(.headline).foregroundStyle(AppTheme.secondaryText).frame(width: 24)
                        ItemThumbnail(item: catalogue.item(item.itemSlug), size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(catalogue.item(item.itemSlug)?.name ?? displayName(forSlug: item.itemSlug))
                                .font(.headline).foregroundStyle(AppTheme.ink)
                            Text(DoseFormatter.text(item.dose)).font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .cardStyle(padding: 16)
            ButtonRow {
                Button {
                    onSaved(workout)
                    dismiss()
                } label: { Label("Save to My workouts", systemImage: "square.and.arrow.down") }
                .buttonStyle(.secondary)
                Button {
                    onStart(workout)
                    dismiss()
                } label: { Label("Start now", systemImage: "play.fill") }
                .buttonStyle(.primary)
            }
        }
    }

    private func load() async {
        guard let normalized = DeepLink.normalize(code) else { return }
        loading = true
        message = nil
        defer { loading = false }
        do {
            shared = try await apiClient.sharedWorkout(code: normalized)
        } catch APIClient.APIError.http(status: 404, _) {
            message = "No workout has that code. Check it and try again."
        } catch {
            message = "Couldn't reach Athlete OS — check your connection."
        }
    }
}

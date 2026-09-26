import SwiftData
import SwiftUI

/// Workout (V3): TODAY'S TRAINING — one recommended workout with its purpose,
/// length, focus and the reason for it — then the other modes as a compact
/// list, this week's gym days, the athlete's own workouts and the other ways
/// to train (a skill, a muscle group).
struct WorkoutTabView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let week: GeneratedWeek?
    let onPlanInputsChanged: () -> Void

    @State private var catalogue = Catalogue()
    @State private var status: DayStatus = DayStatusStore.status()
    @State private var liveLaunch: LiveSessionLaunch?
    @State private var preview: PreviewBox?
    @State private var showingImprove = false
    // Making it yours: edit any workout, the week's shape, own workouts, sharing.
    @State private var editing: EditorTarget?
    @State private var sharing: ShareTarget?
    @State private var showingPlanSettings = false
    @State private var importing = false
    @State private var startAfterImport: CustomWorkout?
    @State private var afterPreview: AfterPreview?
    @State private var myWorkouts = MyWorkoutsStore.load()
    @State private var custom = PlanCustomizationStore.load()
    @State private var showingWorkoutsPaywall = false
    @State private var confirmingNewPlan = false
    @State private var readinessOverridden = false
    @AppStorage(PlanVariant.key) private var planVariant = 0

    private var calendar: Calendar { .current }
    private var sportInfo: SportInfo? { athlete.activeSport.flatMap { allSportsBySlug[$0.sportSlug] } }
    private var gameToday: Competition? { athlete.competitions.first { calendar.isDateInToday($0.date) } }
    private var practiceToday: Bool { PracticeSchedule.hasPractice(on: .now) }
    private var band: ReadinessBand? { readinessOverridden ? nil : DailyLoop.todayBand(athlete) }

    private var context: WorkoutModeContext {
        WorkoutModeContext(
            catalogue: catalogue, sport: sportInfo, positionSlug: athlete.activeSport?.positionSlug,
            formatSlug: athlete.activeSport?.formatSlug, equipment: Set(athlete.equipmentAvailable),
            trainsUnderCoach: athlete.trainsUnderCoach, age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now),
            struggles: Struggles.selected
        )
    }

    private func adjusted(_ session: GeneratedSession) -> GeneratedSession {
        guard let band else { return session }
        return ReadinessApplier.apply(to: session, band: band).session
    }

    /// Today's gym session, or the next one this week.
    private var gymSession: (session: GeneratedSession, isToday: Bool)? {
        let sessions = week?.sessions ?? []
        if let today = sessions.first(where: { calendar.isDateInToday($0.date) }) { return (adjusted(today), true) }
        let start = calendar.startOfDay(for: .now)
        if let next = sessions.first(where: { $0.date > start }) ?? sessions.first { return (adjusted(next), false) }
        return nil
    }

    /// What to do today, and why.
    private var recommendation: (mode: WorkoutMode?, reason: String) {
        switch status {
        case .sick: return (nil, "You're resting today, so there's no training.")
        case .concussion: return (nil, "Training is paused until a doctor clears you.")
        case .travel, .holiday: return (.travel, "A short workout you can do anywhere, only if you feel like it.")
        case .active:
            if gameToday != nil { return (.mobility, "Game day: just loosen up and save your energy.") }
            if practiceToday { return (.afterPractice, "You have practice today, so the gym work is short.") }
            if gymSession?.isToday == true { return (.gymDay, "No team practice today, so this is your main session.") }
            return (.mobility, "A rest day: a few minutes of movement keeps you fresh.")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Workout")
                    Text("TODAY'S TRAINING")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.secondaryText)
                    recommendedCard
                    otherModes
                    weekSection
                    myWorkoutsSection
                    moreSection
                    customizeSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.bottom, 20)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                status = DayStatusStore.status()
            }
            // Workouts added from a link, or restored from the backup, show up.
            .onAppear {
                myWorkouts = MyWorkoutsStore.load()
                custom = PlanCustomizationStore.load()
            }
            .sheet(item: $preview, onDismiss: { runAfterPreview() }) { box in
                SessionPreviewSheet(
                    session: box.session, catalogue: catalogue,
                    onStart: {
                        preview = nil
                        liveLaunch = LiveSessionLaunch(planned: box.session, kind: box.kind)
                    },
                    onEdit: editAction(for: box),
                    onShare: {
                        afterPreview = .share(box)
                        preview = nil
                    }
                )
            }
            .sheet(item: $editing) { target in
                // Plan workouts: swapping is free, the rest is Pro. Own workouts: all of it.
                WorkoutEditorView(heading: target.heading, workout: target.workout, sportSlug: athlete.activeSport?.sportSlug,
                                  fullAccess: target.slot == nil || ProAccess.isPro,
                                  onReset: resetAction(for: target)) { saved in
                    save(saved, for: target)
                }
            }
            .sheet(item: $sharing) { target in
                ShareWorkoutSheet(workout: target.workout, athlete: athlete) { code in
                    guard let id = target.myWorkoutID, var mine = myWorkouts.first(where: { $0.id == id }) else { return }
                    mine.shareCode = code
                    MyWorkoutsStore.upsert(mine)
                    myWorkouts = MyWorkoutsStore.load()
                }
            }
            .proFeature(isPresented: $showingWorkoutsPaywall, athlete: athlete, feature: .myWorkouts)
            .sheet(isPresented: $showingPlanSettings) {
                PlanSettingsSheet {
                    custom = PlanCustomizationStore.load()
                    onPlanInputsChanged()
                }
            }
            .sheet(isPresented: $importing, onDismiss: {
                if let workout = startAfterImport {
                    startAfterImport = nil
                    liveLaunch = LiveSessionLaunch(planned: workout.session(date: .now, catalogue: catalogue), kind: .gym)
                }
            }) {
                SharedWorkoutSheet(onSaved: { workout in
                    MyWorkoutsStore.upsert(workout)
                    myWorkouts = MyWorkoutsStore.load()
                }, onStart: { workout in
                    startAfterImport = workout
                })
            }
            .sheet(isPresented: $showingImprove) {
                ImproveView(athlete: athlete, apiClient: apiClient, onPlanInputsChanged: onPlanInputsChanged)
            }
            .fullScreenCover(item: $liveLaunch) { launch in
                LiveSessionView(athlete: athlete, apiClient: apiClient, planned: launch.planned, kind: launch.kind)
            }
            .confirmationDialog("Delete this plan?", isPresented: $confirmingNewPlan, titleVisibility: .visible) {
                Button("Delete and build a new one", role: .destructive) {
                    PlanVariant.buildNew()
                    onPlanInputsChanged()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your gym days get new exercises. Workouts you already logged stay.")
            }
        }
    }

    // MARK: - Today

    /// The recommended workout for today (nil: rest).
    private var recommendedSession: GeneratedSession? {
        guard let mode = recommendation.mode else { return nil }
        return session(for: mode)
    }

    private func session(for mode: WorkoutMode) -> GeneratedSession? {
        switch mode {
        case .gymDay: gymSession?.session
        case .afterPractice: WorkoutModeBuilder.build(.afterPractice, context).map { adjusted($0) }
        case .mobility, .travel: WorkoutModeBuilder.build(mode, context)
        }
    }

    private var daysToNextGame: Int? {
        AthleteStats.upcomingCompetitions(athlete).first.map { AthleteStats.daysUntil($0.date) }
    }

    /// Why this workout, in one sentence.
    private var reason: String {
        let rec = recommendation
        if rec.mode == .mobility, status == .active, gameToday == nil, !practiceToday, gymSession?.isToday != true {
            return rec.reason
        }
        return DailyLoop.whyThisPlan(status: status, mode: rec.mode, practiceToday: practiceToday, gameToday: gameToday != nil,
                                     daysToNextGame: daysToNextGame, readiness: readinessOverridden ? nil : DailyLoop.today(athlete))
    }

    /// Short tags: what today's workout is shaped around.
    private var focusTags: [String] {
        var tags: [String] = []
        if gameToday != nil {
            tags.append("Game day")
        } else if let days = daysToNextGame, days >= 1, days <= 3 {
            tags.append(days == 1 ? "Game tomorrow" : "Game in \(days) days")
        }
        if band != nil { tags.append("Lighter today") }
        if ScheduleStore.isExamWeek(.now) { tags.append("Exam week") }
        tags += Struggles.selected.prefix(2).map(\.title)
        return tags
    }

    private func purpose(_ mode: WorkoutMode) -> String {
        switch mode {
        case .afterPractice: "Strength and injury prevention, short enough to recover."
        case .gymDay: "Your main strength and power session."
        case .mobility: "Loosen up before training, or calm down after."
        case .travel: "No equipment: hotel room, bus, holiday."
        }
    }

    @ViewBuilder
    private var recommendedCard: some View {
        let rec = recommendation
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(rec.mode.map { $0 == .gymDay ? (gymSession?.session.title ?? $0.title) : $0.title } ?? "Rest today")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(rec.mode.map(purpose) ?? "Recovery is part of the plan.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let session = recommendedSession {
                Text("\(session.estimatedMinutes) min · \(session.items.count) exercises")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
            }
            if !focusTags.isEmpty {
                WrapLayout(spacing: 8) {
                    ForEach(focusTags, id: \.self) { tag in
                        Text(tag)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.fill, in: Capsule())
                    }
                }
            }
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let mode = rec.mode, let session = recommendedSession {
                Button { liveLaunch = LiveSessionLaunch(planned: session, kind: kind(mode)) } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                Button("View workout") {
                    preview = PreviewBox(session: session, kind: kind(mode), slot: slot(for: mode, session: session))
                }
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
            } else if rec.mode != nil {
                Text(catalogue.itemsBySlug.isEmpty ? "Loading your exercises…" : "Nothing fits your equipment yet. Add some in Me → Equipment.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if band != nil || readinessOverridden {
                Button(readinessOverridden ? "Use the lighter version" : "Train as planned instead") {
                    readinessOverridden.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    /// The modes not recommended today, one line each.
    private var otherModes: some View {
        let others = [WorkoutMode.afterPractice, .gymDay, .mobility, .travel].filter { $0 != recommendation.mode }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Other modes")
            VStack(spacing: 0) {
                ForEach(others, id: \.self) { mode in
                    let modeSession = session(for: mode)
                    Button {
                        if let modeSession { preview = PreviewBox(session: modeSession, kind: kind(mode), slot: slot(for: mode, session: modeSession)) }
                    } label: {
                        ListRow(systemImage: icon(mode), color: color(mode), title: mode.title, detail: detail(mode, modeSession))
                    }
                    .buttonStyle(.plain)
                    .disabled(modeSession == nil)
                    if mode != others.last {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .cardStyle(padding: 12)
        }
    }

    private func detail(_ mode: WorkoutMode, _ session: GeneratedSession?) -> String {
        guard let session else { return "Nothing fits your equipment yet" }
        if mode == .gymDay, let gym = gymSession, !gym.isToday {
            return "\(session.estimatedMinutes) min · next on \(gym.session.date.formatted(.dateTime.weekday(.wide)))"
        }
        return "\(session.estimatedMinutes) min · \(session.items.count) exercises"
    }

    private func icon(_ mode: WorkoutMode) -> String {
        switch mode {
        case .afterPractice: "bolt.fill"
        case .gymDay: "dumbbell.fill"
        case .mobility: "figure.flexibility"
        case .travel: "suitcase.fill"
        }
    }

    private func kind(_ mode: WorkoutMode) -> WorkoutKind {
        switch mode {
        case .afterPractice: .afterPractice
        case .gymDay: .gym
        case .mobility: .mobility
        case .travel: .travel
        }
    }

    private func color(_ mode: WorkoutMode) -> Color {
        switch mode {
        case .afterPractice: ProgressColors.afterPractice
        case .gymDay: ProgressColors.workout
        case .mobility: ProgressColors.mobility
        case .travel: AppTheme.purple
        }
    }

    // MARK: - Week, more

    @ViewBuilder
    private var weekSection: some View {
        if let week, !week.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("This week's gym days")
                VStack(spacing: 0) {
                    ForEach(Array(week.sessions.enumerated()), id: \.offset) { index, session in
                        Button { preview = PreviewBox(session: adjusted(session), kind: .gym, slot: session.slot.map { PlanSlot.gym($0) }) } label: {
                            HStack(spacing: 12) {
                                Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.headline)
                                    .foregroundStyle(calendar.isDateInToday(session.date) ? AppTheme.onAccent : AppTheme.ink)
                                    .frame(width: 52, height: 40)
                                    .background(calendar.isDateInToday(session.date) ? AppTheme.accent : AppTheme.fill, in: Capsule())
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(session.title).font(.headline).foregroundStyle(AppTheme.ink)
                                        if let slot = session.slot, custom.workout(for: .gym(slot)) != nil { Tag("Yours", color: AppTheme.brand) }
                                    }
                                    Text("About \(session.estimatedMinutes) min · \(session.items.count) exercises")
                                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if index < week.sessions.count - 1 { Divider().overlay(AppTheme.hairline) }
                    }
                }
                .cardStyle(padding: 14)
            }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("More ways to train")
            Button { showingImprove = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "target")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Skill plans & muscle workouts").font(.headline).foregroundStyle(AppTheme.ink)
                        Text("One skill before a game, or chosen muscles").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
                }
                .cardStyle(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Making it yours

    /// A workout being changed: a planned one (its slot) or one of the athlete's own.
    struct EditorTarget: Identifiable {
        let id = UUID()
        let heading: String
        let workout: CustomWorkout
        var slot: PlanSlot? = nil
    }

    struct ShareTarget: Identifiable {
        let id = UUID()
        let workout: CustomWorkout
        var myWorkoutID: UUID? = nil
    }

    /// What to open once the preview sheet has gone.
    enum AfterPreview {
        case edit(PreviewBox)
        case share(PreviewBox)
    }

    private func slot(for mode: WorkoutMode, session: GeneratedSession) -> PlanSlot? {
        mode == .gymDay ? session.slot.map { PlanSlot.gym($0) } : PlanSlot.mode(mode)
    }

    private func editAction(for box: PreviewBox) -> (() -> Void)? {
        guard box.slot != nil || box.myWorkoutID != nil else { return nil }
        return {
            afterPreview = .edit(box)
            preview = nil
        }
    }

    private func resetAction(for target: EditorTarget) -> (() -> Void)? {
        guard let slot = target.slot else { return nil }
        return { resetEdits(slot) }
    }

    private func runAfterPreview() {
        guard let next = afterPreview else { return }
        afterPreview = nil
        switch next {
        case .edit(let box):
            if let id = box.myWorkoutID, let mine = myWorkouts.first(where: { $0.id == id }) {
                editing = EditorTarget(heading: "Change workout", workout: mine)
            } else if let slot = box.slot {
                editSlot(slot)
            }
        case .share(let box):
            if let id = box.myWorkoutID, let mine = myWorkouts.first(where: { $0.id == id }) {
                sharing = ShareTarget(workout: mine, myWorkoutID: id)
            } else {
                sharing = ShareTarget(workout: CustomWorkout(session: box.session))
            }
        }
    }

    /// Opens the editor on the athlete's version of a planned workout (or the app's, to start from).
    private func editSlot(_ slot: PlanSlot) {
        let heading: String
        let base: GeneratedSession?
        switch slot {
        case .gym(let index):
            heading = "Gym day \(index + 1)"
            base = week?.sessions.first { $0.slot == index }
        case .mode(let mode):
            heading = mode.title
            base = WorkoutModeBuilder.build(mode, context)
        }
        let workout = custom.workout(for: slot) ?? base.map { CustomWorkout(session: $0) }
        guard let workout else { return }
        editing = EditorTarget(heading: heading, workout: workout, slot: slot)
    }

    private func save(_ workout: CustomWorkout, for target: EditorTarget) {
        if let slot = target.slot {
            PlanCustomizationStore.setWorkout(workout, for: slot)
            custom = PlanCustomizationStore.load()
            onPlanInputsChanged()
        } else {
            MyWorkoutsStore.upsert(workout)
            myWorkouts = MyWorkoutsStore.load()
        }
    }

    private func resetEdits(_ slot: PlanSlot) {
        PlanCustomizationStore.setWorkout(nil, for: slot)
        custom = PlanCustomizationStore.load()
        onPlanInputsChanged()
    }

    /// The week's shape, and which workouts the athlete has made their own.
    private var customizeSection: some View {
        let settings = custom.settings
        let dayNames = Calendar.current.shortWeekdaySymbols
        let days = settings.weekdays.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }.map { dayNames[$0 - 1] }.joined(separator: ", ")
        let summary = [
            settings.weekdays.isEmpty ? (settings.sessionsPerWeek.map { "\($0) gym days a week" } ?? "Gym days picked for you") : days,
            settings.minutesPerSession.map { "\($0) min each" } ?? "length picked for you",
        ].joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Make it yours", subtitle: "Your gym days, their length, and any exercise (View workout → Change it).")
            Button { showingPlanSettings = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your week").font(.headline).foregroundStyle(AppTheme.ink)
                        Text(summary).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
                }
                .cardStyle(padding: 14)
            }
            .buttonStyle(.plain)
            Button { confirmingNewPlan = true } label: {
                ListRow(systemImage: "arrow.triangle.2.circlepath", color: AppTheme.ink, title: "Build a new gym plan",
                        detail: "Same rules, different exercises")
                    .cardStyle(padding: 12)
            }
            .buttonStyle(.plain)
            if planVariant > 0 {
                Button {
                    PlanVariant.backToOriginal()
                    onPlanInputsChanged()
                } label: {
                    ListRow(systemImage: "arrow.uturn.backward", color: AppTheme.ink, title: "Back to my first plan")
                        .cardStyle(padding: 12)
                }
                .buttonStyle(.plain)
            }
            let edited = custom.sessions.keys.sorted()
            if !edited.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workouts you changed").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                    ForEach(edited, id: \.self) { key in
                        if let slot = slotFromKey(key), let workout = custom.sessions[key] {
                            HStack(spacing: 10) {
                                Text(label(slot)).font(.headline).foregroundStyle(AppTheme.ink)
                                Text(workout.title).font(.subheadline).foregroundStyle(AppTheme.secondaryText).lineLimit(1)
                                Spacer()
                                Button("Change") { editSlot(slot) }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
                .cardStyle(padding: 14)
            }
        }
    }

    private func slotFromKey(_ key: String) -> PlanSlot? {
        if key.hasPrefix("gym-"), let index = Int(key.dropFirst(4)) { return .gym(index) }
        if key.hasPrefix("mode-"), let mode = WorkoutMode(rawValue: String(key.dropFirst(5))) { return .mode(mode) }
        return nil
    }

    private func label(_ slot: PlanSlot) -> String {
        switch slot {
        case .gym(let index): "Gym day \(index + 1)"
        case .mode(let mode): mode.title
        }
    }

    /// Workouts the athlete built, or added with a code.
    private var myWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("My workouts", subtitle: "Your own, or one a teammate or coach shared.")
            ForEach(myWorkouts) { workout in
                myWorkoutCard(workout)
            }
            ButtonRow {
                Button {
                    if ProGate.canKeepAnotherWorkout(isPro: ProAccess.isPro, myWorkoutCount: myWorkouts.count) {
                        editing = EditorTarget(heading: "New workout", workout: CustomWorkout(title: "My workout", items: []))
                    } else {
                        showingWorkoutsPaywall = true
                    }
                } label: { Label("New workout", systemImage: "plus") }
                .buttonStyle(.secondary)
                Button { importing = true } label: { Label("Add with a code", systemImage: "qrcode.viewfinder") }
                    .buttonStyle(.secondary)
            }
        }
    }

    private func myWorkoutCard(_ workout: CustomWorkout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.title).font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    Text("\(workout.items.count) exercises · about \(workout.estimatedMinutes) min\(workout.shareCode.map { " · shared as \($0)" } ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                #if os(iOS)
                Menu {
                    Button { editing = EditorTarget(heading: "Change workout", workout: workout) } label: { Label("Change it", systemImage: "slider.horizontal.3") }
                    Button { sharing = ShareTarget(workout: workout, myWorkoutID: workout.id) } label: { Label("Share", systemImage: "qrcode") }
                    Button(role: .destructive) {
                        MyWorkoutsStore.delete(workout.id)
                        myWorkouts = MyWorkoutsStore.load()
                    } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.fill, in: Circle())
                }
                .accessibilityLabel("More for \(workout.title)")
                #endif
            }
            ButtonRow {
                Button {
                    preview = PreviewBox(session: workout.session(date: .now, catalogue: catalogue), kind: .gym, myWorkoutID: workout.id)
                } label: { Label("View", systemImage: "list.bullet") }
                .buttonStyle(.secondary)
                Button {
                    liveLaunch = LiveSessionLaunch(planned: workout.session(date: .now, catalogue: catalogue), kind: .gym)
                } label: { Label("Start", systemImage: "play.fill") }
                .buttonStyle(.primary)
            }
        }
        .cardStyle(padding: 18)
    }
}

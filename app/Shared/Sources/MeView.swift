import Charts
import SwiftData
import SwiftUI

/// §15 Tab 5: "Sports and positions, season dates, trends (sleep first —
/// §11), load chart, history, equipment, coach-supervision toggle,
/// subscription, HealthKit, export for Pro, privacy policy, terms, and
/// delete account." Organised the way Cal AI organises its profile: a
/// profile card, stats, progress charts, then grouped menu cards whose rows
/// open focused edit sheets.
struct MeView: View {
    let athlete: Athlete
    let onPlanInputsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var catalogue = Catalogue()
    @State private var activeSheet: MeSheet?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    enum MeSheet: String, Identifiable {
        case sport, season, equipment, history, checkIns, exercises, dataExport, reminders, downloads, fuel, health, sports, help
        var id: String { rawValue }
    }

    private var athleteSport: AthleteSport? { athlete.activeSport }
    @State private var showingPaywall = false
    private var sportInfo: SportInfo? { athleteSport.flatMap { allSportsBySlug[$0.sportSlug] } }
    private var positionName: String? {
        athleteSport?.positionSlug.flatMap { slug in sportInfo?.positions.first { $0.slug == slug }?.name }
    }
    private var age: Int {
        Calendar.current.dateComponents([.year], from: athlete.birthDate, to: .now).year ?? 0
    }
    private var phase: SeasonPhase? {
        athleteSport.map { PhaseCalculator.phase(today: .now, seasonStart: $0.seasonStart, seasonEnd: $0.seasonEnd) }
    }
    private var streak: Int {
        AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: sessions.map(\.startedAt))
    }
    private var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.minutes }
    }

    private var coachSessions: [CoachSession] {
        sessions.map { session in
            CoachSession(
                date: session.startedAt, minutes: session.minutes, rpe: session.sessionRPE,
                sets: session.sets.map { CoachSet(itemSlug: $0.itemSlug, reps: $0.reps, weightKg: $0.weightKg) }
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Me")
                    profileCard
                    statsRow

                    SectionTitle("Progress")
                    SleepTrendCard(checkIns: athlete.checkIns)
                    LoadTrendCard(summary: LoadCalculator.summarize(sessions.map {
                        LoadSample(date: $0.startedAt, minutes: $0.minutes, rpe: $0.sessionRPE)
                    }))
                    MuscleBalanceCard(balance: CoachEngine.muscleBalance(sessions: coachSessions, catalogue: catalogue))

                    menuCard {
                        menuRow("Exercise progress", icon: "chart.xyaxis.line", tint: AppTheme.orange,
                                detail: ProAccess.isPro ? "\(Set(sessions.flatMap { $0.sets.map(\.itemSlug) }).count) exercises" : "Pro") {
                            if ProAccess.isPro { activeSheet = .exercises } else { showingPaywall = true }
                        }
                        menuDivider
                        menuRow("Session history", icon: "clock.arrow.circlepath", tint: AppTheme.blue, detail: "\(sessions.count)") { activeSheet = .history }
                        menuDivider
                        menuRow("Check-in history", icon: "sun.max.fill", tint: AppTheme.amber, detail: "\(athlete.checkIns.count)") { activeSheet = .checkIns }
                    }

                    SectionTitle("Fuel & health")
                    menuCard {
                        menuRow("Fuel & hydration", icon: "fork.knife", tint: AppTheme.green, detail: "Today") { activeSheet = .fuel }
                        menuDivider
                        menuRow("Apple Health", icon: "heart.fill", tint: AppTheme.red,
                                detail: HealthKitManager.shared.isAvailable ? "Connect" : "Unavailable") { activeSheet = .health }
                    }

                    SectionTitle("Training setup")
                    menuCard {
                        menuRow(athlete.sports.count > 1 ? "Sports" : "Sport & position", icon: sportInfo.map { SportIcon.name(for: $0.slug) } ?? "sportscourt.fill", tint: AppTheme.brand,
                                detail: athlete.sports.count > 1
                                    ? "\(athlete.sports.count) sports"
                                    : [sportInfo?.name, positionName].compactMap { $0 }.joined(separator: " · ")) { activeSheet = .sports }
                        menuDivider
                        menuRow("Season dates", icon: "calendar", tint: AppTheme.blue,
                                detail: athlete.sports.count > 1 ? "\(sportInfo?.name ?? "") · \(seasonDetail)" : seasonDetail) { activeSheet = .season }
                        menuDivider
                        menuRow("Equipment", icon: "dumbbell.fill", tint: AppTheme.purple,
                                detail: athlete.equipmentAvailable.isEmpty ? "Bodyweight only" : "\(athlete.equipmentAvailable.count) items") { activeSheet = .equipment }
                        menuDivider
                        coachToggleRow
                    }

                    SectionTitle("App")
                    menuCard {
                        menuRow("Help & app tour", icon: "questionmark.circle.fill", tint: AppTheme.ink, detail: "") { activeSheet = .help }
                        menuDivider
                        menuRow("Reminders", icon: "bell.fill", tint: AppTheme.amber,
                                detail: ReminderScheduler.settings.checkInEnabled ? "On" : "Off") { activeSheet = .reminders }
                        menuDivider
                        menuRow("Downloads", icon: "arrow.down.circle.fill", tint: AppTheme.blue, detail: "Offline") { activeSheet = .downloads }
                    }

                    #if os(iOS) && !APP_EXTENSION
                    SectionTitle("Subscription")
                    SubscriptionRow(athlete: athlete)
                        .cardStyle(padding: 16)
                    #endif

                    SectionTitle("Your data")
                    menuCard {
                        menuRow("Export my data", icon: "square.and.arrow.up", tint: AppTheme.green, detail: "JSON") { activeSheet = .dataExport }
                        menuDivider
                        HStack(spacing: 14) {
                            menuIcon("icloud.fill", tint: AppTheme.blue)
                            Text("Sync")
                                .font(.body)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            let pending = sessions.filter { $0.syncedAt == nil }.count
                            Text(pending == 0 ? "Up to date" : "\(pending) waiting")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.vertical, 12)
                    }

                    SectionTitle("About")
                    menuCard {
                        linkRow("Privacy policy", icon: "hand.raised.fill", url: AppConfig.backendBaseURL.appending(path: "privacy"))
                        menuDivider
                        linkRow("Terms of use", icon: "doc.text.fill", url: AppConfig.backendBaseURL.appending(path: "terms"))
                        menuDivider
                        linkRow("Support", icon: "questionmark.circle.fill", url: AppConfig.backendBaseURL.appending(path: "support"))
                    }

                    disclaimerCard

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text(isDeleting ? "Deleting…" : "Delete account")
                            .font(.headline)
                            .foregroundStyle(AppTheme.red)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.red.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)

                    Text("Sportvisor \(BuildEvidence().version) (\(BuildEvidence().build))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .sport: SportEditorSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .season: SeasonEditorSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .equipment: EquipmentEditorSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .history: SessionHistoryView()
                case .checkIns: CheckInHistoryView(checkIns: athlete.checkIns)
                case .exercises: ExerciseProgressListView(sessions: sessions, catalogue: catalogue)
                case .dataExport: DataExportView(athlete: athlete, sessions: sessions)
                case .reminders: RemindersSheet(athlete: athlete)
                case .downloads: DownloadsSheet(athlete: athlete)
                case .fuel: FuelView(athlete: athlete, todaysSession: WeeklyPlan.generate(for: athlete)?.sessions.first { Calendar.current.isDateInToday($0.date) })
                case .health: HealthPermissionView()
                case .sports: SportsManagerSheet(athlete: athlete, onChanged: onPlanInputsChanged)
                case .help: HelpCenterView()
                }
            }
            .proPaywall(isPresented: $showingPaywall, athlete: athlete, feature: .exerciseProgress)
            .confirmationDialog("Delete your account?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and everything stored on our server, and this device's copy. It can't be undone.")
            }
        }
    }

    private var seasonDetail: String {
        guard let athleteSport else { return "" }
        return "\(athleteSport.seasonStart.formatted(.dateTime.month(.abbreviated).day())) – \(athleteSport.seasonEnd.formatted(.dateTime.month(.abbreviated).day()))"
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: 16) {
            Image(systemName: sportInfo.map { SportIcon.name(for: $0.slug) } ?? "person.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.inkInverse)
                .frame(width: 72, height: 72)
                .background(AppTheme.ink, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(sportInfo?.name ?? "Athlete")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
                Text([positionName, "Age \(age)"].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Tag(AthleteStats.phaseLabel(phase), color: AppTheme.blue)
            }
            Spacer(minLength: 0)
            Button {
                activeSheet = .sport
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit sport and position")
        }
        .cardStyle()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("\(sessions.count)", "Sessions", "figure.run", AppTheme.orange)
            statTile("\(totalMinutes / 60)h \(totalMinutes % 60)m", "Trained", "clock.fill", AppTheme.blue)
            statTile("\(streak)", "Day streak", "flame.fill", AppTheme.brand)
        }
    }

    private func statTile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    // MARK: - Menu rows

    private func menuCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .cardStyle(padding: 16)
    }

    private var menuDivider: some View {
        Divider().overlay(AppTheme.hairline).padding(.leading, 50)
    }

    private func menuIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func menuRow(_ title: String, icon: String, tint: Color, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                menuIcon(icon, tint: tint)
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                menuIcon(icon, tint: AppTheme.secondaryText)
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.vertical, 12)
        }
    }

    private var coachToggleRow: some View {
        Toggle(isOn: Binding(
            get: { athlete.trainsUnderCoach },
            set: { newValue in
                athlete.trainsUnderCoach = newValue
                try? modelContext.save()
                onPlanInputsChanged()
            }
        )) {
            HStack(spacing: 14) {
                menuIcon("person.2.fill", tint: AppTheme.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Train under a coach")
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                    Text("Unlocks coached lifts")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .tint(AppTheme.green)
        .padding(.vertical, 8)
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .foregroundStyle(AppTheme.secondaryText)
            VStack(alignment: .leading, spacing: 4) {
                Text("Not a medical device")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
                Text("Sportvisor never predicts injury, diagnoses, or advises return to play. It supplements your coach and athletic trainer — it never replaces them. If something hurts, stop and tell an adult.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .cardStyle(padding: 16)
    }

    // MARK: - Delete

    private func deleteAccount() {
        isDeleting = true
        Task {
            if let token = try? KeychainTokenStore().read() {
                var request = URLRequest(url: AppConfig.backendBaseURL.appending(path: "athlete/me"))
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
            try? KeychainTokenStore().delete()
            modelContext.delete(athlete)
            try? modelContext.save()
            isDeleting = false
        }
    }
}

// MARK: - Trend cards

/// §11: "Chart sleep against training load... make that chart the first
/// thing on the trends screen."
struct SleepTrendCard: View {
    let checkIns: [CheckIn]

    private var recent: [CheckIn] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        return checkIns.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    private var average: Double? {
        guard !recent.isEmpty else { return nil }
        return Double(recent.reduce(0) { $0 + $1.sleepQuality }) / Double(recent.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sleep")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("Last 14 days")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                if let average {
                    Text(average.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("/ 5 avg")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            if recent.isEmpty {
                Text("Check in each morning and your sleep trend appears here. Teen athletes need roughly 8–10 hours — it's the highest-leverage habit there is.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Chart(recent, id: \.id) { checkIn in
                    BarMark(
                        x: .value("Day", checkIn.date, unit: .day),
                        y: .value("Sleep", checkIn.sleepQuality)
                    )
                    .foregroundStyle(AppTheme.purple.gradient)
                    .cornerRadius(5)
                }
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(values: [1, 3, 5]) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.hairline)
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 150)
            }
        }
        .cardStyle()
    }
}

struct LoadTrendCard: View {
    let summary: LoadSummary

    private var hasData: Bool { summary.daily.contains { $0.load > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training load")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("RPE × minutes, last 28 days")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text("\(summary.acute)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("this week")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if hasData {
                Chart {
                    ForEach(Array(summary.daily.enumerated()), id: \.offset) { _, day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Load", day.load))
                            .foregroundStyle(AppTheme.orange.gradient)
                            .cornerRadius(3)
                    }
                    RuleMark(y: .value("Weekly average per day", summary.chronicWeekly / 7))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 150)
            }
            if let message = summary.message {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: summary.isSharpJump ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(summary.isSharpJump ? AppTheme.amber : AppTheme.green)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            } else {
                Text(hasData ? "Your four-week comparison unlocks after three weeks of logging." : "Finish a session and rate how hard it was — your load chart starts there.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .cardStyle()
    }
}

// MARK: - Editors

struct SportEditorSheet: View {
    let athlete: Athlete
    let onSaved: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var sportSlug: String?
    @State private var positionSlug: String?
    @State private var choosingPosition = false

    private var sport: SportInfo? { sportSlug.flatMap { allSportsBySlug[$0] } }

    var body: some View {
        Group {
            if choosingPosition, let sport {
                StepScaffold(title: "Position", subtitle: sport.name, buttonTitle: "Save", onBack: { choosingPosition = false }, onContinue: save) {
                    PositionChooser(sport: sport, selection: $positionSlug)
                }
            } else {
                StepScaffold(title: "Your sport", buttonTitle: sport?.positions.isEmpty == false ? "Next" : "Save", buttonEnabled: sportSlug != nil,
                             onBack: { dismiss() }, onContinue: {
                    if sport?.positions.isEmpty == false {
                        if sportSlug != athlete.activeSport?.sportSlug { positionSlug = nil }
                        choosingPosition = true
                    } else {
                        positionSlug = nil
                        save()
                    }
                }) {
                    SportChooser(selection: $sportSlug)
                }
            }
        }
        .onAppear {
            sportSlug = athlete.activeSport?.sportSlug
            positionSlug = athlete.activeSport?.positionSlug
        }
    }

    private func save() {
        guard let sport else { return }
        if let existing = athlete.activeSport {
            if existing.sportSlug != sport.slug {
                let defaults = SeasonDefaults.dates(for: sport)
                existing.seasonStart = defaults.start
                existing.seasonEnd = defaults.end
            }
            existing.sportSlug = sport.slug
            existing.positionSlug = positionSlug
        } else {
            let defaults = SeasonDefaults.dates(for: sport)
            modelContext.insert(AthleteSport(sportSlug: sport.slug, positionSlug: positionSlug, seasonStart: defaults.start, seasonEnd: defaults.end, isPrimary: true, athlete: athlete))
        }
        try? modelContext.save()
        let slug = sport.slug
        Task { await SportPackInstaller.install(slug: slug, context: modelContext) }
        onSaved()
        dismiss()
    }
}

struct SeasonEditorSheet: View {
    let athlete: Athlete
    let onSaved: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date.now
    @State private var end = Date.now

    var body: some View {
        StepScaffold(title: "Season dates", subtitle: "Your plan's phases — build, sharpen, maintain, unload — hang off these.", buttonTitle: "Save",
                     onBack: { dismiss() }, onContinue: save) {
            SeasonEditor(start: $start, end: $end)
        }
        .onAppear {
            start = athlete.activeSport?.seasonStart ?? .now
            end = athlete.activeSport?.seasonEnd ?? .now
        }
    }

    private func save() {
        athlete.activeSport?.seasonStart = start
        athlete.activeSport?.seasonEnd = max(start, end)
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}

struct EquipmentEditorSheet: View {
    let athlete: Athlete
    let onSaved: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    var body: some View {
        StepScaffold(title: "Equipment", subtitle: "Your plan only ever uses what you pick here.", buttonTitle: "Save",
                     onBack: { dismiss() }, onContinue: save) {
            EquipmentChooser(selection: $selection)
        }
        .onAppear { selection = Set(athlete.equipmentAvailable) }
    }

    private func save() {
        athlete.equipmentAvailable = Array(selection).sorted()
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}

// MARK: - Histories

struct CheckInHistoryView: View {
    let checkIns: [CheckIn]
    @Environment(\.dismiss) private var dismiss

    private var sorted: [CheckIn] { checkIns.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("Check-ins", subtitle: "\(checkIns.count) mornings logged")
                    if sorted.isEmpty {
                        Text("No check-ins yet. Your first one is four taps on the Today tab.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .cardStyle()
                    }
                    ForEach(sorted) { checkIn in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(checkIn.date.formatted(.dateTime.weekday(.wide).month().day()))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                if let band = checkIn.readinessBand {
                                    Tag(band.rawValue.capitalized, color: AppTheme.color(for: band))
                                }
                            }
                            HStack(spacing: 8) {
                                metric("Sleep", checkIn.sleepQuality, AppTheme.purple)
                                metric("Sore", checkIn.soreness, AppTheme.orange)
                                metric("Energy", checkIn.energy, AppTheme.amber)
                                metric("Stress", checkIn.stress, AppTheme.blue)
                            }
                        }
                        .cardStyle(padding: 16)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The original idea's "track your gym progress": every exercise you've
/// logged, with its best set, and a chart of that exercise over time.
struct ExerciseProgressListView: View {
    let sessions: [Session]
    let catalogue: Catalogue
    @Environment(\.dismiss) private var dismiss

    struct ExerciseSummary: Identifiable {
        let slug: String
        let name: String
        let sessionCount: Int
        let totalSets: Int
        let best: String
        var id: String { slug }
    }

    private var summaries: [ExerciseSummary] {
        var bySlug: [String: [SetLog]] = [:]
        for session in sessions {
            for set in session.sets {
                bySlug[set.itemSlug, default: []].append(set)
            }
        }
        return bySlug.map { slug, sets in
            ExerciseSummary(
                slug: slug,
                name: catalogue.item(slug)?.name ?? displayName(forSlug: slug),
                sessionCount: Set(sets.compactMap { $0.session?.id }).count,
                totalSets: sets.count,
                best: ExerciseProgress.bestLabel(sets)
            )
        }
        .sorted { $0.totalSets > $1.totalSets }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("Exercise progress", subtitle: "Your best sets, and how they've moved.")
                    if summaries.isEmpty {
                        Text("Log a session and every exercise you do shows up here with its own progress chart.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .cardStyle()
                    }
                    ForEach(summaries) { summary in
                        NavigationLink {
                            ExerciseProgressDetailView(slug: summary.slug, name: summary.name, sessions: sessions, item: catalogue.item(summary.slug))
                        } label: {
                            HStack(spacing: 14) {
                                ItemThumbnail(item: catalogue.item(summary.slug), size: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summary.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                        .multilineTextAlignment(.leading)
                                    Text("\(summary.sessionCount) sessions · \(summary.totalSets) sets")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer(minLength: 0)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(summary.best)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.ink)
                                    Text("best")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .cardStyle(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }
}

enum ExerciseProgress {
    /// The single number that best describes a set for this kind of dose.
    static func value(_ set: SetLog) -> Double {
        if let weight = set.weightKg, weight > 0 { return WeightUnit.current.value(kg: weight) }
        if let reps = set.reps { return Double(reps) }
        if let seconds = set.seconds { return Double(seconds) }
        if let distance = set.distanceM { return distance }
        return Double(set.contacts ?? 0)
    }

    static func unit(_ sets: [SetLog]) -> String {
        if sets.contains(where: { ($0.weightKg ?? 0) > 0 }) { return WeightUnit.current.rawValue }
        if sets.contains(where: { $0.reps != nil }) { return "reps" }
        if sets.contains(where: { $0.seconds != nil }) { return "s" }
        if sets.contains(where: { $0.distanceM != nil }) { return "m" }
        return "contacts"
    }

    static func bestLabel(_ sets: [SetLog]) -> String {
        let best = sets.map(value).max() ?? 0
        return "\(best.formatted(.number.precision(.fractionLength(0...1)))) \(unit(sets))"
    }
}

struct ExerciseProgressDetailView: View {
    let slug: String
    let name: String
    let sessions: [Session]
    let item: CatalogueItem?

    struct Point: Identifiable {
        let date: Date
        let value: Double
        let sets: Int
        var id: Date { date }
    }

    private var sets: [SetLog] {
        sessions.flatMap(\.sets).filter { $0.itemSlug == slug }
    }

    private var points: [Point] {
        sessions
            .filter { session in session.sets.contains { $0.itemSlug == slug } }
            .map { session in
                let mine = session.sets.filter { $0.itemSlug == slug }
                return Point(date: session.startedAt, value: mine.map(ExerciseProgress.value).max() ?? 0, sets: mine.count)
            }
            .sorted { $0.date < $1.date }
    }

    private var unit: String { ExerciseProgress.unit(sets) }

    private var change: Double? {
        guard let first = points.first?.value, let last = points.last?.value, points.count >= 2, first > 0 else { return nil }
        return last / first - 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(name, subtitle: "\(points.count) sessions · best \(ExerciseProgress.bestLabel(sets))")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text((points.last?.value ?? 0).formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(unit)
                            .font(.headline)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        if let change {
                            Tag("\(change >= 0 ? "+" : "")\(Int((change * 100).rounded()))% since first", color: change >= 0 ? AppTheme.green : AppTheme.secondaryText)
                        }
                    }
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Best", point.value))
                            .foregroundStyle(AppTheme.ink)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", point.date), y: .value("Best", point.value))
                            .foregroundStyle(AppTheme.brand)
                        AreaMark(x: .value("Date", point.date), y: .value("Best", point.value))
                            .foregroundStyle(AppTheme.brand.opacity(0.08).gradient)
                            .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 200)
                }
                .cardStyle()

                if let item {
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        HStack {
                            Label("How to do it", systemImage: "play.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .cardStyle(padding: 16)
                    }
                    .buttonStyle(.plain)
                }

                SectionTitle("History")
                ForEach(points.reversed()) { point in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.date.formatted(.dateTime.weekday(.abbreviated).month().day()))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.ink)
                            Text("\(point.sets) sets")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text("\(point.value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                    }
                    .cardStyle(padding: 14)
                }
            }
            .padding(20)
        }
        .appScreen()
    }
}

/// §15: "export for Pro" — here for everyone for now; the paywall milestone
/// gates it. Plain JSON of the athlete's own data, shared through the system
/// share sheet.
struct DataExportView: View {
    let athlete: Athlete
    let sessions: [Session]
    @Environment(\.dismiss) private var dismiss

    private var exportText: String {
        let iso = ISO8601DateFormatter()
        var checkIns: [[String: Any]] = []
        for checkIn in athlete.checkIns.sorted(by: { $0.date < $1.date }) {
            var row: [String: Any] = [:]
            row["date"] = iso.string(from: checkIn.date)
            row["sleep"] = checkIn.sleepQuality
            row["soreness"] = checkIn.soreness
            row["energy"] = checkIn.energy
            row["stress"] = checkIn.stress
            row["readiness"] = checkIn.readinessBand?.rawValue ?? ""
            checkIns.append(row)
        }
        var sessionRows: [[String: Any]] = []
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            var setRows: [[String: Any]] = []
            for set in session.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                var setRow: [String: Any] = ["item": set.itemSlug, "setIndex": set.setIndex]
                if let reps = set.reps { setRow["reps"] = reps }
                if let weight = set.weightKg { setRow["weightKg"] = weight }
                if let seconds = set.seconds { setRow["seconds"] = seconds }
                if let distance = set.distanceM { setRow["distanceM"] = distance }
                if let contacts = set.contacts { setRow["contacts"] = contacts }
                setRows.append(setRow)
            }
            var row: [String: Any] = ["startedAt": iso.string(from: session.startedAt), "minutes": session.minutes, "sets": setRows]
            if let rpe = session.sessionRPE { row["rpe"] = rpe }
            sessionRows.append(row)
        }
        var games: [[String: Any]] = []
        for game in athlete.competitions {
            games.append(["date": iso.string(from: game.date), "kind": game.kind.rawValue, "home": game.isHome])
        }
        let payload: [String: Any] = [
            "exportedAt": iso.string(from: .now),
            "sport": athlete.activeSport?.sportSlug ?? "",
            "checkIns": checkIns,
            "sessions": sessionRows,
            "games": games,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle("Export my data", subtitle: "Everything you've logged, in a file you own.")
                    HStack(spacing: 12) {
                        exportStat("\(sessions.count)", "sessions")
                        exportStat("\(sessions.reduce(0) { $0 + $1.sets.count })", "sets")
                        exportStat("\(athlete.checkIns.count)", "check-ins")
                    }
                    ShareLink(item: exportText, preview: SharePreview("Sportvisor export")) {
                        Label("Share export", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(AppTheme.inkInverse)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(AppTheme.ink, in: Capsule())
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }

    private func exportStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

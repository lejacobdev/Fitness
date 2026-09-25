import SwiftData
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum AppTab: Hashable {
    case today, plan, improve, campus, me
}

/// §15's five tabs. Owns the one generated week so Today and Plan can never
/// disagree about it, and regenerates it whenever something that feeds the
/// generator changes (a game added, the sport/season/equipment edited).
@MainActor
public struct MainTabView: View {
    let athlete: Athlete
    let apiClient: APIClient

    @Environment(\.modelContext) private var modelContext
    @State private var week: GeneratedWeek?
    @State private var selectedTab: AppTab = DemoData.initialTab
    @AppStorage("healthPermissionAsked") private var healthPermissionAsked = false
    @State private var showingHealthPermission = false
    @AppStorage("appTourSeen") private var appTourSeen = false
    @State private var showingTour = false
    @State private var workoutContext: WorkoutContext?

    public init(athlete: Athlete, apiClient: APIClient) {
        self.athlete = athlete
        self.apiClient = apiClient
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(athlete: athlete, apiClient: apiClient, week: week, selectedTab: $selectedTab, onPlanInputsChanged: regenerate)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.today)

            PlanView(athlete: athlete, week: week, onPlanInputsChanged: regenerate)
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(AppTab.plan)

            ImproveView(athlete: athlete, apiClient: apiClient, onPlanInputsChanged: regenerate)
                .tabItem { Label("Improve", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.improve)

            CampusView(athlete: athlete)
                .tabItem { Label("Campus", systemImage: "graduationcap.fill") }
                .tag(AppTab.campus)

            MeView(athlete: athlete, onPlanInputsChanged: regenerate)
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(AppTab.me)
        }
        .tint(AppTheme.accent)
        .environment(\.workoutContext, workoutContext)
        .sheet(isPresented: $showingHealthPermission) {
            HealthPermissionView()
        }
        .fullScreenCover(isPresented: $showingTour, onDismiss: askForHealthIfNeeded) {
            AppTourView {
                appTourSeen = true
                showingTour = false
            }
        }
        // Switching or adding a sport rebuilds the week for it.
        .onChange(of: athlete.activeSport?.id) { regenerate() }
        .onChange(of: athlete.sports.count) { regenerate() }
        .onChange(of: ProAccess.isPro) { regenerate() }
        .task {
            workoutContext = WorkoutContext(athlete: athlete, apiClient: apiClient)
            #if os(iOS) && !APP_EXTENSION
            ProStore.shared.start(athlete: athlete)
            #endif
            // First run: a short tour of the five tabs, then (once) the
            // HealthKit ask, reason first — never two prompts stacked.
            if !appTourSeen, !DemoData.isEnabled {
                showingTour = true
            } else {
                askForHealthIfNeeded()
            }
            regenerate()
            let sync = SyncQueue(apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext)
            await sync.drainPendingSessions()
            await sync.drainPendingCheckIns()
            // Keep the offline packs current: newer exercises, cues and
            // animations arrive without re-running setup.
            if !DemoData.isEnabled {
                for sport in athlete.sports {
                    await SportPackInstaller.install(slug: sport.sportSlug, context: modelContext)
                }
                regenerate()
            }
        }
    }

    private func askForHealthIfNeeded() {
        if !healthPermissionAsked, HealthKitManager.shared.isAvailable, !DemoData.isEnabled {
            showingHealthPermission = true
        }
    }

    private func regenerate() {
        week = WeeklyPlan.generate(for: athlete)
        WidgetSnapshotWriter.write(for: athlete, week: week)
        let settings = ReminderScheduler.settings
        if settings.checkInEnabled || settings.gameRemindersEnabled {
            let games = AthleteStats.upcomingCompetitions(athlete).map { (date: $0.date, kind: $0.kind.rawValue.capitalized) }
            Task { await ReminderScheduler.reschedule(games: games) }
        }
    }
}

/// Shared by the Today and Plan tabs so the two can never disagree about
/// what "this week" is.
enum WeeklyPlan {
    @MainActor
    static func generate(for athlete: Athlete) -> GeneratedWeek? {
        guard
            let athleteSport = athlete.activeSport,
            let sportInfo = allSportsBySlug[athleteSport.sportSlug]
        else { return nil }

        let calendar = Calendar.current
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        ) ?? .now

        let positionProfile = athleteSport.positionSlug.flatMap { slug in
            sportInfo.positions.first { $0.slug == slug }?.qualityProfile
        }

        let input = PlanGeneratorInput(
            sportProfile: sportInfo.qualityProfile, positionProfile: positionProfile,
            seasonStart: athleteSport.seasonStart, seasonEnd: athleteSport.seasonEnd,
            weekStart: weekStart, birthDate: athlete.birthDate,
            trainsUnderCoach: athlete.trainsUnderCoach,
            equipmentAvailable: Set(athlete.equipmentAvailable),
            catalogue: CatalogueLoader.load(from: AppConfig.packsDirectory()),
            seed: "\(athlete.id)-\(Int(weekStart.timeIntervalSince1970))",
            sportSlug: athleteSport.sportSlug, positionSlug: athleteSport.positionSlug, formatSlug: athleteSport.formatSlug
        )
        let generated = PlanGenerator.generate(input)
        // Every game counts, whatever sport it's for: the body that plays a
        // basketball game on Friday shouldn't squat heavy on Thursday.
        // Free tapers for the next game; Pro for every game in the week.
        let competitions = ProGate.competitionsForTaper(athlete.competitions.map(\.date), isPro: ProAccess.isPro)
        let tapered = TaperApplier.apply(to: generated, competitions: competitions, contactLevel: sportInfo.contactLevel)
        return alignToSchedule(tapered, practiceWeekdays: PracticeSchedule.weekdays, gameDays: athlete.competitions.map(\.date))
    }

    /// Gym days go on days without team practice (practice days get the short
    /// after-practice workout instead), spread across the week with a day
    /// between them where possible, and never on a game day.
    static func alignToSchedule(_ week: GeneratedWeek?, practiceWeekdays: Set<Int>, gameDays: [Date], calendar: Calendar = .current) -> GeneratedWeek? {
        guard let week, !practiceWeekdays.isEmpty, !week.sessions.isEmpty else { return week }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.weekStart) }
        let games = Set(gameDays.map { calendar.startOfDay(for: $0) })
        let free = days.filter { !practiceWeekdays.contains(calendar.component(.weekday, from: $0)) && !games.contains(calendar.startOfDay(for: $0)) }
        guard !free.isEmpty else { return week }
        // Pick as many free days as there are sessions, spaced evenly through the free days.
        let count = min(week.sessions.count, free.count)
        let chosen = (0..<count).map { free[($0 * free.count) / count] }
        let sessions = week.sessions.prefix(count).enumerated().map { index, session in
            GeneratedSession(date: chosen[index], title: session.title, focusQualities: session.focusQualities,
                             estimatedMinutes: session.estimatedMinutes, items: session.items)
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: Array(sessions))
    }
}

/// Small, pure helpers over the athlete's own data that more than one tab
/// shows.
@MainActor
enum AthleteStats {
    static func todaysCheckIn(_ athlete: Athlete) -> CheckIn? {
        athlete.checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    static func upcomingCompetitions(_ athlete: Athlete) -> [Competition] {
        let today = Calendar.current.startOfDay(for: .now)
        return athlete.competitions
            .filter { Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
    }

    static func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// Consecutive days, ending today (or yesterday, so the streak doesn't
    /// read zero before the morning check-in), with a check-in or a logged
    /// session — the daily-habit number Cal AI shows as its flame.
    static func streak(checkInDates: [Date], sessionDates: [Date], now: Date = .now) -> Int {
        let calendar = Calendar.current
        let active = Set((checkInDates + sessionDates).map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !active.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while active.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func sportName(_ athlete: Athlete) -> String {
        guard let slug = athlete.activeSport?.sportSlug else { return "" }
        return allSportsBySlug[slug]?.name ?? displayName(forSlug: slug)
    }

    static func phaseLabel(_ phase: SeasonPhase?) -> String {
        switch phase {
        case .offSeason: "Off-season"
        case .preSeason: "Pre-season"
        case .inSeason: "In-season"
        case .postSeason: "Post-season"
        case nil: "This week"
        }
    }
}

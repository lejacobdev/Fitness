import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var week: GeneratedWeek?
    @State private var selectedTab: AppTab = DemoData.initialTab
    @AppStorage("healthPermissionAsked") private var healthPermissionAsked = false
    @State private var showingHealthPermission = false
    @AppStorage("appTourSeen") private var appTourSeen = false
    @State private var showingTour = false
    @State private var workoutContext: WorkoutContext?
    @State private var backingUp = false

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
        // Back up when the athlete leaves the app, pick up other phones'
        // changes when they come back.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .active {
                Task { await backUp() }
            }
        }
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
            await backUp()
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

    /// Pushes queued workouts and check-ins, syncs the backed-up documents
    /// (sports, games, plans, meals, settings, Campus progress…) and pulls
    /// in recent workouts logged on another phone.
    private func backUp() async {
        guard !DemoData.isEnabled, !athlete.isDeleted, !backingUp else { return }
        backingUp = true
        defer { backingUp = false }
        #if os(iOS) && !APP_EXTENSION
        // Leaving the app: ask iOS for the few seconds the upload needs.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "backup")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }
        #endif
        let sync = SyncQueue(apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext)
        await sync.drainPendingSessions()
        await sync.drainPendingCheckIns()
        let reached = await CloudSync.sync(athlete: athlete, context: modelContext, apiClient: apiClient)
        if reached {
            await CloudSync.restoreRows(athlete: athlete, context: modelContext, apiClient: apiClient, full: false)
        }
        // Team and school calendars: new games, moved or cancelled practices, exams.
        if !athlete.isDeleted, scenePhase != .background {
            await CalendarSync.refresh(athlete: athlete, context: modelContext)
        }
        // Workouts from the coach, and this week's Campus XP for the leagues.
        await CoachAssignments.refresh(apiClient: apiClient)
        await LeagueSync.report(apiClient: apiClient)
        if !athlete.isDeleted, scenePhase != .background { regenerate() }
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
        if settings.anyEnabled {
            let games = AthleteStats.upcomingCompetitions(athlete).map { (date: $0.date, kind: $0.kind.rawValue.capitalized) }
            Task { await ReminderScheduler.reschedule(games: games) }
        }
    }
}

/// "Delete my plan and give me a new one": the weekly plan is built from the
/// athlete's inputs, so deleting it means building a different one — a new
/// variant changes the generator's seed (different exercises, same rules).
enum PlanVariant {
    static let key = "plans.variant"
    static var current: Int { UserDefaults.standard.integer(forKey: key) }
    static func buildNew() { UserDefaults.standard.set(current + 1, forKey: key) }
    static func backToOriginal() { UserDefaults.standard.removeObject(forKey: key) }
    static func seed(_ base: String) -> String { current == 0 ? base : "\(base)-v\(current)" }
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
            seed: PlanVariant.seed("\(athlete.id)-\(Int(weekStart.timeIntervalSince1970))"),
            sportSlug: athleteSport.sportSlug, positionSlug: athleteSport.positionSlug, formatSlug: athleteSport.formatSlug
        )
        let generated = PlanGenerator.generate(input)
        // Every game counts, whatever sport it's for: the body that plays a
        // basketball game on Friday shouldn't squat heavy on Thursday.
        // Free tapers for the next game; Pro for every game in the week.
        let competitions = ProGate.competitionsForTaper(athlete.competitions.map(\.date), isPro: ProAccess.isPro)
        let tapered = TaperApplier.apply(to: generated, competitions: competitions, contactLevel: sportInfo.contactLevel)
        // A practice cancelled today or later pulls a gym day onto that day.
        let startOfToday = calendar.startOfDay(for: .now)
        let cancelled = calendar.dateInterval(of: .weekOfYear, for: weekStart).map {
            ScheduleStore.imported.cancelledPracticeDays(in: $0, calendar: calendar).filter { $0 >= startOfToday }
        } ?? []
        let aligned = alignToSchedule(tapered, isPracticeDay: { PracticeSchedule.hasPractice(on: $0, calendar: calendar) },
                                      preferredDays: cancelled, gameDays: athlete.competitions.map(\.date), calendar: calendar)
        // Exam weeks: fewer, shorter sessions.
        guard let aligned, ScheduleStore.isExamWeek(weekStart, calendar: calendar) else { return aligned }
        return ExamWeek.lighten(aligned)
    }

    /// Gym days go on days without team practice (practice days get the short
    /// after-practice workout instead), spread across the week with a day
    /// between them where possible, and never on a game day.
    static func alignToSchedule(_ week: GeneratedWeek?, practiceWeekdays: Set<Int>, gameDays: [Date], calendar: Calendar = .current) -> GeneratedWeek? {
        alignToSchedule(week, isPracticeDay: { practiceWeekdays.contains(calendar.component(.weekday, from: $0)) },
                        preferredDays: [], gameDays: gameDays, calendar: calendar)
    }

    /// The same, for a schedule that changes week to week (a team calendar).
    /// `preferredDays` — days a practice was cancelled — get a gym session
    /// first: the gym day moves there.
    static func alignToSchedule(_ week: GeneratedWeek?, isPracticeDay: (Date) -> Bool, preferredDays: [Date],
                                gameDays: [Date], calendar: Calendar = .current) -> GeneratedWeek? {
        guard let week, !week.sessions.isEmpty else { return week }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.weekStart) }
        let preferred = Set(preferredDays.map { calendar.startOfDay(for: $0) })
        guard days.contains(where: isPracticeDay) || !preferred.isEmpty else { return week }
        let games = Set(gameDays.map { calendar.startOfDay(for: $0) })
        let free = days.filter { !isPracticeDay($0) && !games.contains(calendar.startOfDay(for: $0)) }
        guard !free.isEmpty else { return week }
        let count = min(week.sessions.count, free.count)
        let first = Array(free.filter { preferred.contains(calendar.startOfDay(for: $0)) }.prefix(count))
        let rest = free.filter { !preferred.contains(calendar.startOfDay(for: $0)) }
        let remaining = min(count - first.count, rest.count)
        // The rest spaced evenly through the remaining free days.
        let spread = remaining > 0 ? (0..<remaining).map { rest[($0 * rest.count) / remaining] } : []
        let chosen = (first + spread).sorted()
        let sessions = week.sessions.prefix(chosen.count).enumerated().map { index, session in
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

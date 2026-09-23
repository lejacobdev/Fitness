import SwiftData
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum AppTab: Hashable {
    case today, plan, improve, library, me
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
    @State private var selectedTab: AppTab = .today

    public init(athlete: Athlete, apiClient: APIClient) {
        self.athlete = athlete
        self.apiClient = apiClient
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(athlete: athlete, apiClient: apiClient, week: week, selectedTab: $selectedTab, onPlanInputsChanged: regenerate)
                .tabItem { Label("Today", systemImage: "house.fill") }
                .tag(AppTab.today)

            PlanView(athlete: athlete, week: week, onPlanInputsChanged: regenerate)
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(AppTab.plan)

            ImproveView(athlete: athlete)
                .tabItem { Label("Improve", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.improve)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)

            MeView(athlete: athlete, onPlanInputsChanged: regenerate)
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(AppTab.me)
        }
        .tint(AppTheme.ink)
        .task {
            regenerate()
            let sync = SyncQueue(apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext)
            await sync.drainPendingSessions()
            await sync.drainPendingCheckIns()
        }
    }

    private func regenerate() {
        week = WeeklyPlan.generate(for: athlete)
        WidgetSnapshotWriter.write(for: athlete, week: week)
    }
}

/// Shared by the Today and Plan tabs so the two can never disagree about
/// what "this week" is.
enum WeeklyPlan {
    @MainActor
    static func generate(for athlete: Athlete) -> GeneratedWeek? {
        guard
            let athleteSport = athlete.sports.first,
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
            seed: "\(athlete.id)-\(Int(weekStart.timeIntervalSince1970))"
        )
        let generated = PlanGenerator.generate(input)
        let competitions = athlete.competitions
            .filter { $0.sportSlug == athleteSport.sportSlug }
            .map(\.date)
        return TaperApplier.apply(to: generated, competitions: competitions, contactLevel: sportInfo.contactLevel)
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
        guard let slug = athlete.sports.first?.sportSlug else { return "" }
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

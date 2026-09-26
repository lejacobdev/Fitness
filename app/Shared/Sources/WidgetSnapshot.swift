import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The small, read-only picture of "today" the widget and the Watch
/// complication show (§16): written by the app into the shared App Group
/// container, never the full relational store.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public var day: Date
    public var sportName: String
    public var sessionTitle: String?
    public var sessionMinutes: Int?
    public var exerciseCount: Int
    public var isGameDay: Bool
    public var checkedIn: Bool
    public var readiness: String?
    public var nextGameDate: Date?
    public var streak: Int
    public var sessionsThisWeek: Int
    public var plannedThisWeek: Int

    public init(
        day: Date, sportName: String, sessionTitle: String?, sessionMinutes: Int?, exerciseCount: Int,
        isGameDay: Bool, checkedIn: Bool, readiness: String?, nextGameDate: Date?, streak: Int,
        sessionsThisWeek: Int, plannedThisWeek: Int
    ) {
        self.day = day
        self.sportName = sportName
        self.sessionTitle = sessionTitle
        self.sessionMinutes = sessionMinutes
        self.exerciseCount = exerciseCount
        self.isGameDay = isGameDay
        self.checkedIn = checkedIn
        self.readiness = readiness
        self.nextGameDate = nextGameDate
        self.streak = streak
        self.sessionsThisWeek = sessionsThisWeek
        self.plannedThisWeek = plannedThisWeek
    }

    public static let placeholder = WidgetSnapshot(
        day: .now, sportName: "Soccer", sessionTitle: "Speed session", sessionMinutes: 42, exerciseCount: 4,
        isGameDay: false, checkedIn: false, readiness: nil, nextGameDate: Calendar.current.date(byAdding: .day, value: 3, to: .now),
        streak: 5, sessionsThisWeek: 1, plannedThisWeek: 3
    )

    static var fileURL: URL? {
        AppIdentifiers.sharedContainer?.appending(path: "widget-snapshot.json")
    }

    /// The snapshot, or nil if none has been written (or the App Group is
    /// missing — §16's silent failure mode).
    public static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Whether this snapshot still describes today.
    public var isCurrent: Bool { Calendar.current.isDateInToday(day) }
}

@MainActor
enum WidgetSnapshotWriter {
    static func write(for athlete: Athlete, week: GeneratedWeek?) {
        let calendar = Calendar.current
        let today = Date.now
        let session = week?.sessions.first { calendar.isDateInToday($0.date) }
        let checkIn = AthleteStats.todaysCheckIn(athlete)
        var adjusted = session
        if let session, let band = DailyLoop.todayBand(athlete) {
            adjusted = ReadinessApplier.apply(to: session, band: band).session
        }
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)
        let sessionsThisWeek = athlete.sessions.filter { weekInterval?.contains($0.startedAt) ?? false }.count

        let snapshot = WidgetSnapshot(
            day: today,
            sportName: AthleteStats.sportName(athlete),
            sessionTitle: adjusted?.title,
            sessionMinutes: adjusted?.estimatedMinutes,
            exerciseCount: adjusted?.items.count ?? 0,
            isGameDay: athlete.competitions.contains { calendar.isDateInToday($0.date) },
            checkedIn: checkIn != nil,
            readiness: checkIn == nil ? nil : DailyLoop.today(athlete)?.level.band.rawValue,
            nextGameDate: AthleteStats.upcomingCompetitions(athlete).first?.date,
            streak: AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: athlete.sessions.map(\.startedAt)),
            sessionsThisWeek: sessionsThisWeek,
            plannedThisWeek: week?.sessions.count ?? 0
        )
        guard let url = WidgetSnapshot.fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        // Same moments the watch needs a fresh "today": a regenerated week,
        // a check-in, a finished session.
        #if os(iOS) && !APP_EXTENSION
        PhoneWatchBridge.shared.sendToday(athlete: athlete, week: week)
        #endif
    }
}

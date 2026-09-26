import Foundation

/// What kind of day it is for the athlete, set from the top-left of Home.
/// The plan and the reminders follow it, so the app never nags someone who
/// is ill, travelling or on holiday.
public enum DayStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    /// A normal day: school, practice, the plan as usual.
    case active
    case sick
    /// A possible head injury: every workout pauses until a doctor clears the
    /// athlete. Set from the Safety Center, never from the day menu.
    case concussion
    case travel
    case holiday

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .active: "Normal Day"
        case .sick: "Sick / Rest"
        case .concussion: "Training paused"
        case .travel: "Travel Day"
        case .holiday: "Holiday"
        }
    }

    public var systemImage: String {
        switch self {
        case .active: "sun.max.fill"
        case .sick: "bed.double.fill"
        case .concussion: "bandage.fill"
        case .travel: "airplane"
        case .holiday: "beach.umbrella.fill"
        }
    }

    /// What the app does differently, in one line — shown in the menu so it explains itself.
    public var explanation: String {
        switch self {
        case .active: "Your plan as usual."
        case .sick: "No training. Rest and recover."
        case .concussion: "Possible head injury: no training until a doctor clears you."
        case .travel: "An optional 15-minute workout, no equipment."
        case .holiday: "Plan paused. Optional light workouts."
        }
    }

    /// Whether workouts are planned and reminded as usual.
    public var trainsAsPlanned: Bool { self == .active }

    /// The day types an athlete picks from. A head injury isn't a kind of
    /// day — it's reported in the Safety Center, which pauses training.
    public static let menu: [DayStatus] = [.active, .sick, .travel, .holiday]
}

/// The athlete's current status and how long it lasts. Stored on this
/// device; an expired status falls back to `.active` on its own.
public enum DayStatusStore {
    private static let key = "dayStatus.v1"

    private struct Stored: Codable {
        var status: DayStatus
        /// Last day (inclusive) the status applies; nil = until changed.
        var until: Date?
        var from: Date
    }

    private static var stored: Stored? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(Stored.self, from: data)
        }
        set {
            UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
        }
    }

    public static func status(on date: Date = .now, calendar: Calendar = .current) -> DayStatus {
        guard let stored else { return .active }
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: stored.from) else { return .active }
        if let until = stored.until, day > calendar.startOfDay(for: until) { return .active }
        return stored.status
    }

    /// The last day the current status lasts, if it has an end.
    public static var until: Date? { stored?.until }

    /// Sets the status from today. `days` = how many days it lasts (1 = just
    /// today); nil keeps it until changed. `.active` clears it.
    public static func set(_ status: DayStatus, days: Int?, now: Date = .now, calendar: Calendar = .current) {
        guard status != .active else { stored = nil; return }
        let today = calendar.startOfDay(for: now)
        let until = days.flatMap { calendar.date(byAdding: .day, value: max(0, $0 - 1), to: today) }
        stored = Stored(status: status, until: until, from: today)
    }
}

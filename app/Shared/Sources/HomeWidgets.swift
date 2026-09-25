import Foundation

/// Home is a board of widgets, like the iPhone home screen: small squares
/// (two to a row), wide cards and the big "today" card. The athlete can
/// reorder, remove and add them back; widgets that only matter sometimes
/// (game day, the evening reflection, a coach's workout) appear on their
/// own when they're relevant.
public enum HomeWidget: String, CaseIterable, Codable, Sendable, Identifiable {
    case quote, checkIn, today, coach, gameDay, reflection
    case body, sport, knowledge, mindset, nextGame, food, streak, tests
    case mobility, schedule

    public var id: String { rawValue }

    public enum Size: Sendable { case small, medium, large }

    public var size: Size {
        switch self {
        case .today: .large
        case .body, .sport, .knowledge, .mindset, .nextGame, .food, .streak, .tests: .small
        default: .medium
        }
    }

    public var title: String {
        switch self {
        case .quote: "Quote of the day"
        case .checkIn: "Morning check-in"
        case .today: "Today's workout"
        case .coach: "From your coach"
        case .gameDay: "Game-day routines"
        case .reflection: "Evening reflection"
        case .body: "Body level"
        case .sport: "Sport level"
        case .knowledge: "Knowledge level"
        case .mindset: "Mindset level"
        case .nextGame: "Next game"
        case .food: "Food & water"
        case .streak: "Streak"
        case .tests: "Tests"
        case .mobility: "Daily mobility"
        case .schedule: "Set up your schedule"
        }
    }

    public var systemImage: String {
        switch self {
        case .quote: "quote.opening"
        case .checkIn: "sun.max.fill"
        case .today: "figure.strengthtraining.traditional"
        case .coach: "person.3.fill"
        case .gameDay: "sportscourt.fill"
        case .reflection: "moon.stars.fill"
        case .body: "figure.strengthtraining.traditional"
        case .sport: "sportscourt.fill"
        case .knowledge: "graduationcap.fill"
        case .mindset: "brain.head.profile"
        case .nextGame: "calendar"
        case .food: "fork.knife"
        case .streak: "flame.fill"
        case .tests: "stopwatch.fill"
        case .mobility: "figure.flexibility"
        case .schedule: "calendar.badge.clock"
        }
    }

    /// When a widget that only matters sometimes shows up.
    public var whenShown: String? {
        switch self {
        case .coach: "Shows up when your coach sends a workout for today."
        case .gameDay: "Shows up on game days."
        case .reflection: "Shows up in the evening until you've reflected."
        case .mobility: "Shows up on days you can train."
        case .schedule: "Shows up until your practice days are set."
        default: nil
        }
    }

    /// The layout a new athlete starts with: the day first, then the levels.
    public static let defaultOrder: [HomeWidget] = [
        .quote, .checkIn, .schedule, .today, .coach, .gameDay, .reflection,
        .body, .sport, .knowledge, .mindset, .nextGame, .food, .mobility, .streak, .tests,
    ]
}

/// The athlete's arrangement (backed up with their settings).
public struct HomeLayout: Codable, Sendable, Equatable {
    public var order: [HomeWidget]
    public var hidden: Set<HomeWidget>

    static let key = "home.layout"

    public static var standard: HomeLayout { HomeLayout(order: HomeWidget.defaultOrder, hidden: []) }

    public static func load(_ defaults: UserDefaults = .standard) -> HomeLayout {
        guard let data = defaults.data(forKey: key),
              var layout = try? JSONDecoder().decode(HomeLayout.self, from: data) else { return .standard }
        // Widgets added in an update go where the default puts them.
        for widget in HomeWidget.defaultOrder where !layout.order.contains(widget) {
            let before = HomeWidget.defaultOrder.prefix { $0 != widget }.last
            let index = before.flatMap { layout.order.firstIndex(of: $0) }.map { $0 + 1 } ?? layout.order.count
            layout.order.insert(widget, at: index)
        }
        return layout
    }

    public func save(_ defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    public var visible: [HomeWidget] { order.filter { !hidden.contains($0) } }

    /// Moves `widget` to where `target` is.
    public mutating func move(_ widget: HomeWidget, to target: HomeWidget) {
        guard widget != target, let from = order.firstIndex(of: widget) else { return }
        order.remove(at: from)
        let to = order.firstIndex(of: target) ?? order.count
        order.insert(widget, at: from <= to ? to + 1 : to)
    }

    /// Swaps two widgets' places (the up/down arrows while arranging).
    public mutating func swap(_ widget: HomeWidget, with other: HomeWidget) {
        guard let a = order.firstIndex(of: widget), let b = order.firstIndex(of: other) else { return }
        order.swapAt(a, b)
    }

    /// Rows of the board: two small widgets side by side, everything else
    /// full width, in the athlete's order.
    public static func rows(_ widgets: [HomeWidget]) -> [[HomeWidget]] {
        var rows: [[HomeWidget]] = []
        var waiting: HomeWidget?
        for widget in widgets {
            if widget.size == .small {
                if let first = waiting {
                    rows.append([first, widget])
                    waiting = nil
                } else {
                    waiting = widget
                }
            } else {
                if let first = waiting {
                    rows.append([first])
                    waiting = nil
                }
                rows.append([widget])
            }
        }
        if let first = waiting { rows.append([first]) }
        return rows
    }
}

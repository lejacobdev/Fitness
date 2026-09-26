import Foundation

/// Extra Home widgets, added in Edit Home. Home itself is the day (check-in,
/// readiness, TODAY, the evening); widgets are optional small tiles below
/// it — none by default. Two to a row; the athlete adds, removes and
/// reorders them.
public enum HomeWidget: String, CaseIterable, Codable, Sendable, Identifiable {
    case body, sport, knowledge, mindset, nextGame, food, streak, tests

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .body: "Body level"
        case .sport: "Sport level"
        case .knowledge: "Knowledge level"
        case .mindset: "Mindset level"
        case .nextGame: "Next game"
        case .food: "Food & water"
        case .streak: "Streak"
        case .tests: "Tests"
        }
    }

    public var systemImage: String {
        switch self {
        case .body: "figure.strengthtraining.traditional"
        case .sport: "sportscourt.fill"
        case .knowledge: "graduationcap.fill"
        case .mindset: "brain.head.profile"
        case .nextGame: "calendar"
        case .food: "fork.knife"
        case .streak: "flame.fill"
        case .tests: "stopwatch.fill"
        }
    }

    /// One line on what it shows, in the "Add widgets" list.
    public var detail: String {
        switch self {
        case .body: "Workouts done this week"
        case .sport: "Your skill plans"
        case .knowledge: "Campus lessons learned"
        case .mindset: "Reflections, goals, routines this week"
        case .nextGame: "Days until your next game"
        case .food: "What to eat and drink today"
        case .streak: "Days in a row you checked in or trained"
        case .tests: "When your next tests are due"
        }
    }
}

/// The widgets the athlete added, in their order (backed up with their
/// settings). Empty until they add one in Edit Home.
public struct HomeLayout: Codable, Sendable, Equatable {
    public var widgets: [HomeWidget]

    /// A new key for V3: the widgets start empty for everyone.
    static let key = "home.widgets"

    public init(widgets: [HomeWidget] = []) {
        self.widgets = widgets
    }

    public static func load(_ defaults: UserDefaults = .standard) -> HomeLayout {
        guard let data = defaults.data(forKey: key),
              let layout = try? JSONDecoder().decode(HomeLayout.self, from: data) else { return HomeLayout() }
        // Unknown or repeated entries (an older or newer app) are dropped.
        var seen = Set<HomeWidget>()
        return HomeLayout(widgets: layout.widgets.filter { seen.insert($0).inserted })
    }

    public func save(_ defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    /// Widgets that can still be added.
    public var available: [HomeWidget] { HomeWidget.allCases.filter { !widgets.contains($0) } }

    public mutating func add(_ widget: HomeWidget) {
        guard !widgets.contains(widget) else { return }
        widgets.append(widget)
    }

    public mutating func remove(_ widget: HomeWidget) {
        widgets.removeAll { $0 == widget }
    }

    /// Moves `widget` to where `target` is.
    public mutating func move(_ widget: HomeWidget, to target: HomeWidget) {
        guard widget != target, let from = widgets.firstIndex(of: widget), widgets.contains(target) else { return }
        widgets.remove(at: from)
        let to = widgets.firstIndex(of: target) ?? widgets.count
        widgets.insert(widget, at: from <= to ? to + 1 : to)
    }
}

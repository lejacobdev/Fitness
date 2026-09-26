import Foundation

/// The athlete's own say over their training, on top of what the app builds:
///
/// - the shape of the week: how many gym days, on which weekdays, how long;
/// - their own version of any workout — a gym day ("day 1"), the after-
///   practice workout, mobility, travel — with exercises swapped, added,
///   removed, re-ordered and re-dosed;
/// - workouts they build from scratch or get from someone else's code.
///
/// Everything lives under `plans.` and is backed up with their settings.

/// One exercise in a workout the athlete edited or built.
public struct CustomItem: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var itemSlug: String
    public var dose: Dose
    public var restSec: Int

    public init(id: UUID = UUID(), itemSlug: String, dose: Dose, restSec: Int) {
        self.id = id
        self.itemSlug = itemSlug
        self.dose = dose
        self.restSec = restSec
    }

    /// Straight from the library, with the item's own starting dose.
    public init(item: CatalogueItem) {
        self.init(itemSlug: item.slug, dose: item.defaultDose, restSec: item.restSeconds)
    }
}

/// A workout the athlete owns: their version of a planned one, one they
/// built, or one they got from a code.
public struct CustomWorkout: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var items: [CustomItem]
    public var updatedAt: Date
    /// The code it's shared under, once shared.
    public var shareCode: String?

    public init(id: UUID = UUID(), title: String, items: [CustomItem], updatedAt: Date = .now, shareCode: String? = nil) {
        self.id = id
        self.title = title
        self.items = items
        self.updatedAt = updatedAt
        self.shareCode = shareCode
    }

    /// The athlete's editable copy of a planned workout.
    public init(session: GeneratedSession) {
        self.init(title: session.title, items: session.items.sorted { $0.order < $1.order }.map {
            CustomItem(itemSlug: $0.itemSlug, dose: $0.dose, restSec: $0.restSec)
        })
    }

    public var estimatedMinutes: Int {
        max(1, items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) })
    }

    /// As a session the app can show, start and log.
    public func session(date: Date, catalogue: Catalogue? = nil, slot: Int? = nil,
                        rationale: String = "You chose this one.") -> GeneratedSession {
        let items = items.enumerated().map { index, item in
            GeneratedPlannedItem(
                itemSlug: item.itemSlug, order: index, dose: item.dose, restSec: item.restSec,
                rationale: rationale,
                // The quality the exercise trains most, so game-week tapering still knows what it is.
                quality: catalogue?.item(item.itemSlug)?.qualities.max { $0.value < $1.value }?.key ?? ""
            )
        }
        let focus = Array(Set(items.map(\.quality).filter { !$0.isEmpty })).sorted()
        return GeneratedSession(date: date, title: title, focusQualities: focus,
                                estimatedMinutes: estimatedMinutes, items: items, slot: slot)
    }
}

/// The week's shape, as the athlete set it. Nil / empty means "the app decides".
public struct PlanSettings: Codable, Sendable, Equatable {
    /// Gym days on these weekdays (Calendar numbering: 1 = Sunday … 7 = Saturday).
    public var weekdays: [Int]
    /// How many gym days, when the app picks the days.
    public var sessionsPerWeek: Int?
    /// Minutes per gym session.
    public var minutesPerSession: Int?

    public init(weekdays: [Int] = [], sessionsPerWeek: Int? = nil, minutesPerSession: Int? = nil) {
        self.weekdays = weekdays
        self.sessionsPerWeek = sessionsPerWeek
        self.minutesPerSession = minutesPerSession
    }

    public var isDefault: Bool { weekdays.isEmpty && sessionsPerWeek == nil && minutesPerSession == nil }

    /// Gym days in the week: the chosen weekdays decide it when there are any.
    public var effectiveSessionsPerWeek: Int? { weekdays.isEmpty ? sessionsPerWeek : weekdays.count }

    public static let minuteChoices = [20, 30, 45, 60, 75, 90]
}

/// Which workout an edit replaces.
public enum PlanSlot: Hashable, Sendable {
    /// The week's nth gym day (0 = the first).
    case gym(Int)
    /// After practice, mobility, travel.
    case mode(WorkoutMode)

    public var key: String {
        switch self {
        case .gym(let index): "gym-\(index)"
        case .mode(let mode): "mode-\(mode.rawValue)"
        }
    }
}

public struct PlanCustomization: Codable, Sendable, Equatable {
    public var settings: PlanSettings
    /// Slot key → the athlete's version of that workout.
    public var sessions: [String: CustomWorkout]

    public init(settings: PlanSettings = PlanSettings(), sessions: [String: CustomWorkout] = [:]) {
        self.settings = settings
        self.sessions = sessions
    }

    public func workout(for slot: PlanSlot) -> CustomWorkout? { sessions[slot.key] }

    public var isEmpty: Bool { settings.isDefault && sessions.isEmpty }
}

public enum PlanCustomizationStore {
    static let key = "plans.custom"

    public static func load(_ defaults: UserDefaults = .standard) -> PlanCustomization {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PlanCustomization.self, from: $0) } ?? PlanCustomization()
    }

    public static func save(_ value: PlanCustomization, _ defaults: UserDefaults = .standard) {
        if value.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(try? JSONEncoder().encode(value), forKey: key)
        }
    }

    public static func setWorkout(_ workout: CustomWorkout?, for slot: PlanSlot, _ defaults: UserDefaults = .standard) {
        var value = load(defaults)
        value.sessions[slot.key] = workout
        save(value, defaults)
    }

    public static func setSettings(_ settings: PlanSettings, _ defaults: UserDefaults = .standard) {
        var value = load(defaults)
        value.settings = settings
        save(value, defaults)
    }
}

/// Applies the athlete's edits to the week the generator built.
public enum PlanCustomizer {
    /// Their version of a gym day replaces that day's workout (keeping the date).
    public static func apply(_ custom: PlanCustomization, to week: GeneratedWeek, catalogue: Catalogue? = nil) -> GeneratedWeek {
        guard !custom.sessions.isEmpty else { return week }
        let sessions = week.sessions.map { session -> GeneratedSession in
            guard let slot = session.slot, let mine = custom.workout(for: .gym(slot)) else { return session }
            return mine.session(date: session.date, catalogue: catalogue, slot: slot)
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: sessions)
    }

    /// Gym days moved onto the weekdays the athlete picked (in week order).
    public static func place(_ week: GeneratedWeek, weekdays: [Int], calendar: Calendar = .current) -> GeneratedWeek {
        guard !weekdays.isEmpty, !week.sessions.isEmpty else { return week }
        let wanted = Set(weekdays)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.weekStart) }
            .filter { wanted.contains(calendar.component(.weekday, from: $0)) }
        let sessions = zip(week.sessions, days).map { session, day in
            GeneratedSession(date: day, title: session.title, focusQualities: session.focusQualities,
                             estimatedMinutes: session.estimatedMinutes, items: session.items, slot: session.slot)
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: sessions)
    }
}

/// Workouts the athlete built, or got from a code.
public enum MyWorkoutsStore {
    static let key = "plans.myWorkouts"
    /// Plenty for anyone; keeps the backup small.
    public static let limit = 50

    public static func load(_ defaults: UserDefaults = .standard) -> [CustomWorkout] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([CustomWorkout].self, from: $0) } ?? []
    }

    public static func save(_ workouts: [CustomWorkout], _ defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(Array(workouts.prefix(limit))), forKey: key)
    }

    /// Adds it, or replaces the one with the same id; the newest first.
    public static func upsert(_ workout: CustomWorkout, _ defaults: UserDefaults = .standard) {
        var all = load(defaults).filter { $0.id != workout.id }
        var updated = workout
        updated.updatedAt = .now
        all.insert(updated, at: 0)
        save(all, defaults)
    }

    public static func delete(_ id: UUID, _ defaults: UserDefaults = .standard) {
        save(load(defaults).filter { $0.id != id }, defaults)
    }
}

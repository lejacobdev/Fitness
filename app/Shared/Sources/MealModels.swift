import Foundation
import SwiftData

/// §13's meal log — plate portions and timing, never grams or calories.
/// Counted in simple portions (a palm of protein, a fist of carbs, a fist of
/// colour), 0–3 each per meal, which is the portion model §13 prescribes.
public enum MealSlot: String, Codable, CaseIterable, Sendable {
    case breakfast = "BREAKFAST"
    case lunch = "LUNCH"
    case dinner = "DINNER"
    case snack = "SNACK"
    case preTraining = "PRE_TRAINING"
    case postTraining = "POST_TRAINING"
    /// The day's running water count — one row per day, updated in place.
    case water = "WATER"

    public var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        case .preTraining: "Before training"
        case .postTraining: "After training"
        case .water: "Water"
        }
    }

    public var systemImage: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        case .preTraining: "bolt.fill"
        case .postTraining: "arrow.clockwise.heart.fill"
        case .water: "drop.fill"
        }
    }

    /// The slots an athlete picks from when logging food.
    public static let mealSlots: [MealSlot] = [.breakfast, .lunch, .dinner, .snack, .preTraining, .postTraining]
}

@Model
public final class MealLog {
    @Attribute(.unique) public var id: String
    public var date: Date
    public var slot: MealSlot
    public var proteinPortions: Int
    public var carbPortions: Int
    public var colourPortions: Int
    public var hydrationGlasses: Int
    public var note: String?
    /// The idempotency key for a future sync, same rule as every other
    /// athlete-written row (§14).
    public var clientId: String
    public var athlete: Athlete?

    public init(
        id: String = UUID().uuidString, date: Date = .now, slot: MealSlot, proteinPortions: Int = 0,
        carbPortions: Int = 0, colourPortions: Int = 0, hydrationGlasses: Int = 0, note: String? = nil,
        clientId: String = UUID().uuidString, athlete: Athlete? = nil
    ) {
        self.id = id
        self.date = date
        self.slot = slot
        self.proteinPortions = MealLog.clamp(proteinPortions)
        self.carbPortions = MealLog.clamp(carbPortions)
        self.colourPortions = MealLog.clamp(colourPortions)
        self.hydrationGlasses = max(0, hydrationGlasses)
        self.note = note
        self.clientId = clientId
        self.athlete = athlete
    }

    static func clamp(_ portions: Int) -> Int {
        min(3, max(0, portions))
    }
}

/// Thin ModelContext wrapper, same shape as SessionLogger/CheckInStore.
@MainActor
public struct MealStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func logMeal(
        athlete: Athlete, slot: MealSlot, protein: Int, carbs: Int, colour: Int, note: String? = nil, date: Date = .now
    ) throws -> MealLog {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meal = MealLog(
            date: date, slot: slot, proteinPortions: protein, carbPortions: carbs, colourPortions: colour,
            note: (trimmed?.isEmpty ?? true) ? nil : trimmed, athlete: athlete
        )
        modelContext.insert(meal)
        try modelContext.save()
        return meal
    }

    /// Adds (or with a negative delta, removes) glasses on the day's single
    /// water row, never going below zero.
    @discardableResult
    public func addWater(athlete: Athlete, glasses delta: Int, now: Date = .now, calendar: Calendar = .current) throws -> Int {
        if let existing = athlete.mealLogs.first(where: { $0.slot == MealSlot.water && calendar.isDate($0.date, inSameDayAs: now) }) {
            existing.hydrationGlasses = max(0, existing.hydrationGlasses + delta)
            try modelContext.save()
            return existing.hydrationGlasses
        }
        let row = MealLog(date: now, slot: .water, hydrationGlasses: max(0, delta), athlete: athlete)
        modelContext.insert(row)
        try modelContext.save()
        return row.hydrationGlasses
    }

    public func delete(_ meal: MealLog) throws {
        modelContext.delete(meal)
        try modelContext.save()
    }

    public static func meals(of athlete: Athlete, on day: Date, calendar: Calendar = .current) -> [MealLog] {
        athlete.mealLogs
            .filter { $0.slot != MealSlot.water && calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    public static func glasses(of athlete: Athlete, on day: Date, calendar: Calendar = .current) -> Int {
        athlete.mealLogs
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.hydrationGlasses }
    }
}

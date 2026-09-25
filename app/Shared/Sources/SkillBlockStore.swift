import Foundation
import SwiftData

/// §14: `SkillBlock` deliberately stores only enough to REPRODUCE a §8
/// block (sport, skill, target date, seed) rather than materialising every
/// generated item — "kept so it can be revisited," the same determinism
/// guarantee `PlanGenerator` already relies on, not a second copy of the
/// generated content to keep in sync.
@MainActor
public struct SkillBlockStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func save(athlete: Athlete, sportSlug: String, skillSlug: String, targetDate: Date, seed: String) throws -> SkillBlock {
        let block = SkillBlock(sportSlug: sportSlug, skillSlug: skillSlug, targetDate: targetDate, seed: seed, athlete: athlete)
        modelContext.insert(block)
        try modelContext.save()
        return block
    }

    /// Deletes a saved skill plan. Its creation date is remembered so the
    /// free plan's "three a month" still counts it (deleting and re-saving
    /// doesn't make new ones free).
    public func delete(_ block: SkillBlock) throws {
        Self.rememberDeleted(block.generatedAt)
        modelContext.delete(block)
        try modelContext.save()
    }

    static let deletedDatesKey = "plans.deletedSkillPlanDates"

    /// When every skill plan saved this month was made, deleted ones included.
    public static func quotaDates(for athlete: Athlete, now: Date = .now, calendar: Calendar = .current) -> [Date] {
        let deleted = (UserDefaults.standard.array(forKey: deletedDatesKey) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
        return athlete.skillBlocks.map(\.generatedAt) + deleted.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }
    }

    private static func rememberDeleted(_ date: Date, now: Date = .now, calendar: Calendar = .current) {
        let kept = (UserDefaults.standard.array(forKey: deletedDatesKey) as? [Double] ?? [])
            .filter { calendar.isDate(Date(timeIntervalSince1970: $0), equalTo: now, toGranularity: .month) }
        UserDefaults.standard.set(kept + [date.timeIntervalSince1970], forKey: deletedDatesKey)
    }
}

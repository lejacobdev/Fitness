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
}

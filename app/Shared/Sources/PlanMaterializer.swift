import Foundation
import SwiftData

/// Turns a pure `GeneratedWeek` (PlanGenerator.swift) into real SwiftData
/// rows and inserts them. Kept separate from the generator itself so the
/// generator's exact-output tests (§21: "seeded, so assert exact output")
/// never need a `ModelContext` at all.
@MainActor
public struct PlanMaterializer {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func materialize(_ week: GeneratedWeek, athlete: Athlete, seed: String) throws -> Plan {
        let plan = Plan(weekStart: week.weekStart, phase: week.phase.rawValue, seed: seed, athlete: athlete)
        modelContext.insert(plan)

        for generatedSession in week.sessions {
            let plannedSession = PlannedSession(
                date: generatedSession.date, title: generatedSession.title,
                focusQualities: generatedSession.focusQualities,
                estimatedMinutes: generatedSession.estimatedMinutes, plan: plan
            )
            modelContext.insert(plannedSession)

            for generatedItem in generatedSession.items {
                let plannedItem = PlannedItem(
                    itemSlug: generatedItem.itemSlug, order: generatedItem.order,
                    dose: generatedItem.dose, restSec: generatedItem.restSec,
                    rationale: generatedItem.rationale, plannedSession: plannedSession
                )
                modelContext.insert(plannedItem)
            }
        }

        try modelContext.save()
        return plan
    }
}

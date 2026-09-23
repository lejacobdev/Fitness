import Foundation
import SwiftData

/// §14: `CheckIn` is unique per athlete per day, so a second check-in the
/// same day EDITS the first rather than inserting a new row — corrupting
/// that would corrupt every rolling baseline in §11. Mirrors
/// `SessionLogger`'s shape: a thin `ModelContext` wrapper, pure local
/// writes, fully offline by construction.
@MainActor
public struct CheckInStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func submit(
        athlete: Athlete, sleepQuality: Int, sleepHours: Double? = nil, soreness: Int,
        sorenessAreas: [String] = [], energy: Int, stress: Int,
        now: Date = .now, calendar: Calendar = .current
    ) throws -> CheckIn {
        let today = calendar.startOfDay(for: now)
        let history = athlete.checkIns
            .filter { $0.date < today }
            .map {
                CheckInAnswers(
                    date: $0.date, sleepQuality: $0.sleepQuality, soreness: $0.soreness,
                    energy: $0.energy, stress: $0.stress
                )
            }
        let todayAnswers = CheckInAnswers(date: today, sleepQuality: sleepQuality, soreness: soreness, energy: energy, stress: stress)
        let scored = ReadinessEngine.score(today: todayAnswers, history: history, now: now, calendar: calendar)

        if let existing = athlete.checkIns.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            existing.sleepQuality = sleepQuality
            existing.sleepHours = sleepHours
            existing.soreness = soreness
            existing.sorenessAreas = sorenessAreas
            existing.energy = energy
            existing.stress = stress
            existing.readinessBand = scored?.band
            existing.readinessZ = scored?.z
            try modelContext.save()
            return existing
        }

        let checkIn = CheckIn(
            date: today, sleepQuality: sleepQuality, sleepHours: sleepHours, soreness: soreness,
            sorenessAreas: sorenessAreas, energy: energy, stress: stress,
            readinessBand: scored?.band, readinessZ: scored?.z, athlete: athlete
        )
        modelContext.insert(checkIn)
        try modelContext.save()
        return checkIn
    }
}

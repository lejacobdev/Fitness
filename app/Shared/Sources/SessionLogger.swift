import Foundation
import SwiftData

/// M5: starting, logging and finishing a session is pure local SwiftData
/// writes — instant and fully offline by construction (§3: "the UI never
/// blocks on the network... an athlete who is offline for a fortnight loses
/// nothing"). Syncing (`SyncQueue`) is a separate, later step, never a
/// precondition for any of this to work.
@MainActor
public struct SessionLogger {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func startSession(
        athlete: Athlete, source: SessionSource = .phone, plannedSession: PlannedSession? = nil
    ) throws -> Session {
        let session = Session(startedAt: .now, source: source, athlete: athlete, plannedSession: plannedSession)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    @discardableResult
    public func logSet(
        session: Session, itemSlug: String, setIndex: Int, reps: Int? = nil, weightKg: Double? = nil,
        seconds: Int? = nil, distanceM: Double? = nil, contacts: Int? = nil, side: String? = nil
    ) throws -> SetLog {
        let set = SetLog(
            itemSlug: itemSlug, setIndex: setIndex, reps: reps, weightKg: weightKg, seconds: seconds,
            distanceM: distanceM, contacts: contacts, side: side, session: session
        )
        modelContext.insert(set)
        try modelContext.save()
        return set
    }

    /// §15: "It ends with the single RPE question and nothing else."
    /// `minutes` is derived from the actual elapsed wall-clock time rather
    /// than asked for, since the athlete already told the app when they
    /// started.
    public func finishSession(_ session: Session, sessionRPE: Int) throws {
        let endedAt = Date.now
        session.endedAt = endedAt
        session.sessionRPE = sessionRPE
        session.minutes = max(0, Int(endedAt.timeIntervalSince(session.startedAt) / 60))
        try modelContext.save()
    }
}

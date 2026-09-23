import Foundation
import SwiftData

/// §3: "Writes are queued, never lost... the drain is idempotent on
/// clientId." Sessions are always logged locally first (`SessionLogger`) and
/// are fully usable before this ever runs; this is what pushes them to the
/// backend when connectivity allows. Safe to call as often as convenient —
/// app foreground, reconnect, a manual retry — since every push is
/// idempotent by `clientId` on the server (§14, §21's sync idempotency test).
@MainActor
public struct SyncQueue {
    private let apiClient: APIClient
    private let tokenStore: any TokenStore
    private let modelContext: ModelContext

    public init(apiClient: APIClient, tokenStore: any TokenStore, modelContext: ModelContext) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.modelContext = modelContext
    }

    /// Pushes every locally-logged session not yet marked synced. A session
    /// that fails to push (offline, server error, not signed in yet) is left
    /// untouched — `syncedAt` stays nil, so the very next drain retries it —
    /// and one session's failure never affects any other already-synced or
    /// still-pending session.
    @discardableResult
    public func drainPendingSessions() async -> (succeeded: Int, failed: Int) {
        // Swift 5 flattens `try?` against an already-Optional return type, so
        // this single `guard let` covers both "not signed in yet" (nil) and
        // "Keychain read failed" (throw) the same way.
        guard let token = try? tokenStore.read() else { return (0, 0) }

        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.syncedAt == nil })
        guard let pending = try? modelContext.fetch(descriptor) else { return (0, 0) }

        var succeeded = 0
        var failed = 0
        for session in pending {
            let request = APIClient.SyncSessionRequest(
                session: .init(
                    clientId: session.clientId, startedAt: session.startedAt, endedAt: session.endedAt,
                    sessionRPE: session.sessionRPE, minutes: session.minutes,
                    source: session.source.rawValue, plannedSessionId: session.plannedSession?.id,
                    healthKitWorkoutId: session.healthKitWorkoutId
                ),
                sets: session.sets.map { set in
                    .init(
                        clientId: set.clientId, itemSlug: set.itemSlug, setIndex: set.setIndex,
                        reps: set.reps, weightKg: set.weightKg, seconds: set.seconds,
                        distanceM: set.distanceM, contacts: set.contacts, side: set.side
                    )
                }
            )

            do {
                try await apiClient.syncSession(request, sessionToken: token)
                session.syncedAt = .now
                succeeded += 1
            } catch {
                failed += 1
            }
        }

        try? modelContext.save()
        return (succeeded, failed)
    }

    /// Pushes every check-in created or edited since its last push. The
    /// server upserts per athlete per day (§14), so a retry or an edit never
    /// creates a second row for the same morning.
    @discardableResult
    public func drainPendingCheckIns() async -> (succeeded: Int, failed: Int) {
        guard let token = try? tokenStore.read() else { return (0, 0) }
        let descriptor = FetchDescriptor<CheckIn>(predicate: #Predicate { $0.syncedAt == nil })
        guard let pending = try? modelContext.fetch(descriptor) else { return (0, 0) }

        var succeeded = 0
        var failed = 0
        for checkIn in pending {
            let payload = APIClient.CheckInPayload(
                clientId: checkIn.clientId, date: checkIn.date, sleepQuality: checkIn.sleepQuality,
                sleepHours: checkIn.sleepHours, soreness: checkIn.soreness, sorenessAreas: checkIn.sorenessAreas,
                energy: checkIn.energy, stress: checkIn.stress,
                readinessBand: checkIn.readinessBand?.rawValue, readinessZ: checkIn.readinessZ
            )
            do {
                try await apiClient.syncCheckIn(payload, sessionToken: token)
                checkIn.syncedAt = .now
                succeeded += 1
            } catch {
                failed += 1
            }
        }
        try? modelContext.save()
        return (succeeded, failed)
    }
}

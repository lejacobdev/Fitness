#if canImport(WatchConnectivity) && !APP_EXTENSION
import Foundation
import WatchConnectivity

/// §16's phone → Watch hand-off. The phone pushes today's plan, the
/// athlete's identity and the session token as application context (the
/// latest value always wins, delivered whenever the Watch next wakes); the
/// Watch keeps it on its own disk so a session works with the phone off.
/// Logged data never flows back this way — the Watch syncs straight to the
/// backend with the same clientId idempotency as the phone.
public final class PhoneWatchBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    public static let shared = PhoneWatchBridge()
    public static let payloadDidChange = Notification.Name("PhoneWatchBridge.payloadDidChange")

    public func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if os(watchOS)
        if !session.receivedApplicationContext.isEmpty {
            receive(session.receivedApplicationContext)
        }
        #endif
    }

    #if os(iOS)
    /// Call whenever today's plan could have changed (week regenerated,
    /// check-in saved, game added).
    @MainActor
    public func sendToday(athlete: Athlete, week: GeneratedWeek?) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(WatchTodayPayload.make(athlete: athlete, week: week)) else { return }
        try? session.updateApplicationContext(["today": data])
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // Switching paired watches: re-activate for the new one.
        session.activate()
    }
    #endif

    #if os(watchOS)
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    private func receive(_ context: [String: Any]) {
        guard let data = context["today"] as? Data,
              let payload = try? JSONDecoder().decode(WatchTodayPayload.self, from: data)
        else { return }
        payload.saveOnDevice()
        NotificationCenter.default.post(name: Self.payloadDidChange, object: nil)
    }
    #endif
}
#endif

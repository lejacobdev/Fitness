#if canImport(WatchConnectivity) && !APP_EXTENSION
import Foundation
import WatchConnectivity

/// §16's phone → Watch hand-off. The phone pushes today's plan, the
/// athlete's identity and the session token as application context (the
/// latest value always wins, delivered whenever the Watch next wakes); the
/// Watch keeps it on its own disk so a session works with the phone off.
/// Logged sessions never flow back this way — the Watch syncs straight to
/// the backend with the same clientId idempotency as the phone. Two small
/// things do: the evening reflection and "I have pain" from the Watch's
/// two-tap check-ins (queued with transferUserInfo, so they arrive even when
/// the phone is asleep).
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

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let day = userInfo["day"] as? String else { return }
        let hardness = userInfo["hardness"] as? Int
        let body = userInfo["body"] as? Int
        let pain = userInfo["pain"] as? Bool ?? false
        Task { @MainActor in
            Self.apply(day: day, hardness: hardness, body: body, pain: pain)
        }
    }

    /// The Watch's answers on the phone: a reflection only when there isn't
    /// one for that day yet; pain only when none is reported.
    @MainActor
    static func apply(day: String, hardness: Int?, body: Int?, pain: Bool, calendar: Calendar = .current) {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return }
        if hardness != nil || body != nil, MindsetStore.reflection(on: date, calendar: calendar) == nil {
            MindsetStore.saveEvening(hardness: hardness, body: body, practice: nil, wentWell: [], needsWork: [], learned: nil, on: date, calendar: calendar)
        }
        if pain, PainStore.report(on: date, calendar: calendar) == nil {
            PainStore.set(PainReport(day: day, areas: [.other], level: .some), on: date, calendar: calendar)
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // Switching paired watches: re-activate for the new one.
        session.activate()
    }
    #endif

    #if os(watchOS)
    /// Sends the Watch's evening reflection or a pain flag to the phone.
    public func sendToPhone(day: String, hardness: Int? = nil, body: Int? = nil, pain: Bool = false) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        var info: [String: Any] = ["day": day, "pain": pain]
        if let hardness { info["hardness"] = hardness }
        if let body { info["body"] = body }
        WCSession.default.transferUserInfo(info)
    }

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

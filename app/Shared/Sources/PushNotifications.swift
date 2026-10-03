import Foundation
import Observation
import SwiftUI
import UserNotifications
#if os(iOS) && !APP_EXTENSION
import UIKit
#endif

/// What the server can ping this phone about (backend/src/lib/notifier.js).
enum PushKind: String, CaseIterable, Sendable {
    case assignment, announcement, shoutout, health, rtp

    /// Coach and trainer updates an athlete gets.
    static let teamUpdates: [PushKind] = [.assignment, .announcement, .shoutout, .rtp]
}

/// Push notifications for team events: a coach's new workout or note, a
/// return-to-play step, and — for coaches and athletic trainers — a new pain
/// report on the health board. The token and the switches live on this phone
/// and are mirrored to the server (`PUT /push/device`).
@MainActor
enum PushSettings {
    private static let tokenKey = "push.deviceToken"
    private static let mutedKey = "push.muted"
    private static let staffKey = "push.isStaff"
    private static let teamKey = "push.hasTeam"
    private static let syncedKey = "push.syncedSignature"

    static var token: String? { UserDefaults.standard.string(forKey: tokenKey) }

    private static var muted: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: mutedKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: mutedKey) }
    }

    /// In a team, or running one: the switches only matter then.
    static var hasTeam: Bool { UserDefaults.standard.bool(forKey: teamKey) }
    /// Coach or athletic trainer: pain reports are theirs to hear about.
    static var isStaff: Bool { UserDefaults.standard.bool(forKey: staffKey) }

    static var teamUpdatesOn: Bool {
        get { PushKind.teamUpdates.contains { !muted.contains($0.rawValue) } }
        set { set(PushKind.teamUpdates, on: newValue) }
    }

    static var healthNotesOn: Bool {
        get { !muted.contains(PushKind.health.rawValue) }
        set { set([.health], on: newValue) }
    }

    private static func set(_ kinds: [PushKind], on: Bool) {
        var current = muted
        for kind in kinds {
            if on { current.remove(kind.rawValue) } else { current.insert(kind.rawValue) }
        }
        muted = current
    }

    /// Remembers what the teams screens just learned.
    static func noteTeams(_ teams: APIClient.Teams) {
        let staff = !teams.coaching.isEmpty || !(teams.trainer ?? []).isEmpty
        UserDefaults.standard.set(staff, forKey: staffKey)
        UserDefaults.standard.set(staff || !teams.member.isEmpty, forKey: teamKey)
    }

    /// Asks to show notifications (once), registers with Apple and tells the server.
    static func enable() async {
        guard !DemoData.isEnabled else { return }
        guard await ReminderScheduler.requestAuthorization() else { return }
        #if os(iOS) && !APP_EXTENSION
        UIApplication.shared.registerForRemoteNotifications()
        #endif
        await syncIfNeeded()
    }

    /// At launch: if notifications are already allowed, refresh the token.
    static func registerIfAllowed() async {
        guard !DemoData.isEnabled else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        #if os(iOS) && !APP_EXTENSION
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    static func didRegister(token: String) async {
        UserDefaults.standard.set(token, forKey: tokenKey)
        await syncIfNeeded()
    }

    /// Tells the server this phone's token and switches, when either changed
    /// or someone else signed in.
    static func syncIfNeeded(apiClient: APIClient = APIClient(baseURL: AppConfig.backendBaseURL)) async {
        guard !DemoData.isEnabled, let token, let session = try? KeychainTokenStore().read() else { return }
        let signature = [token, muted.sorted().joined(separator: ","), String(session.suffix(16))].joined(separator: "|")
        guard signature != UserDefaults.standard.string(forKey: syncedKey) else { return }
        do {
            try await apiClient.registerPushDevice(token: token, muted: muted.sorted(), sessionToken: session)
            UserDefaults.standard.set(signature, forKey: syncedKey)
        } catch {
            // Offline: the next launch or backup tries again.
        }
    }

    /// Signing out or deleting the account: this phone stops getting pushes.
    static func forget(tokenStore: any TokenStore) {
        guard let token, let session = try? tokenStore.read() else { return }
        Task.detached {
            try? await APIClient(baseURL: AppConfig.backendBaseURL).removePushDevice(token: token, sessionToken: session)
        }
    }
}

/// Where a tapped notification should land. Held until the screens exist
/// (a cold start from a notification builds them after the tap arrives).
@MainActor
@Observable
final class PushRoute {
    static let shared = PushRoute()

    var tab: AppTab?
    /// A `MeView.MeSheet` raw value.
    var meSheet: String?

    private init() {}

    func open(kind: String?) {
        switch PushKind(rawValue: kind ?? "") {
        case .rtp?:
            tab = .me
            meSheet = "team"
        case .health?:
            tab = .me
            meSheet = "coach"
        case .assignment?, .announcement?, .shoutout?:
            tab = .today
        case nil:
            break
        }
    }
}

/// The app notices changes as they happen: a push, coming back to the app,
/// and a quiet check every 45 seconds while it is open. Screens that show
/// team data reload when `tick` moves.
@MainActor
@Observable
final class LiveUpdates {
    static let shared = LiveUpdates()

    private(set) var tick = 0
    /// How many team screens are open right now.
    @ObservationIgnored var watchers = 0

    private init() {}

    func poke() { tick &+= 1 }

    /// Pulls the coach's workouts and notes. Open team screens reload either
    /// way (the readiness board and health notes aren't cached), and Home
    /// when something it shows changed.
    func refresh(apiClient: APIClient = APIClient(baseURL: AppConfig.backendBaseURL)) async {
        guard !DemoData.isEnabled else { return }
        let before = snapshot()
        await CoachAssignments.refresh(apiClient: apiClient)
        await TeamAnnouncements.refresh(apiClient: apiClient)
        if snapshot() != before || watchers > 0 { poke() }
    }

    /// A push arrived (or was tapped): fetch what it is about right away.
    func pushReceived() async {
        await refresh()
        poke()
    }

    private func snapshot() -> [Data?] {
        [CoachAssignments.cacheKey, TeamAnnouncements.cacheKey].map { UserDefaults.standard.data(forKey: $0) }
    }
}

/// Runs `action` when the screen appears and again whenever something new
/// arrives, so a team screen that is already open stays current.
private struct LiveReload: ViewModifier {
    let action: @MainActor () async -> Void
    @State private var live = LiveUpdates.shared

    func body(content: Content) -> some View {
        content
            .task(id: live.tick) { await action() }
            .onAppear { live.watchers += 1 }
            .onDisappear { live.watchers = max(0, live.watchers - 1) }
    }
}

extension View {
    func liveReload(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(LiveReload(action: action))
    }
}

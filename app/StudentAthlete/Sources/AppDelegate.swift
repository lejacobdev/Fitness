import UIKit
import UserNotifications

/// Push notifications: Apple hands the app its device token here, and a
/// notification arriving or being tapped refreshes and routes the app.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        Task { @MainActor in await PushSettings.registerIfAllowed() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in await PushSettings.didRegister(token: token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Simulator, no network, or notifications off: nothing to do — reminders still work locally.
    }

    /// A push woke the app in the background: fetch what changed before the athlete opens it.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let finish = FetchCompletion(completionHandler)
        Task { @MainActor in
            await LiveUpdates.shared.pushReceived()
            finish.call(.newData)
        }
    }
}

private final class FetchCompletion: @unchecked Sendable {
    private let handler: (UIBackgroundFetchResult) -> Void
    init(_ handler: @escaping (UIBackgroundFetchResult) -> Void) { self.handler = handler }
    func call(_ result: UIBackgroundFetchResult) { handler(result) }
}

/// Shows team notifications as banners while the app is open, and opens the
/// right screen when one is tapped.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.userInfo["kind"] != nil {
            Task { @MainActor in await LiveUpdates.shared.pushReceived() }
        }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let kind = response.notification.request.content.userInfo["kind"] as? String
        if kind != nil {
            Task { @MainActor in
                PushRoute.shared.open(kind: kind)
                await LiveUpdates.shared.pushReceived()
            }
        }
        completionHandler()
    }
}

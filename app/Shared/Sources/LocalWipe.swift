import Foundation
import SwiftData
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Removes every trace of the athlete from this device: all SwiftData rows,
/// every setting and bit of progress in UserDefaults, the session token in
/// the Keychain, scheduled reminders and the widget's snapshot. Used by
/// "Log out" (after a final backup) and "Delete account" (after the server
/// confirmed the deletion). Downloaded exercise packs stay — they're the
/// same for everyone and hold nothing personal.
@MainActor
public enum LocalWipe {
    /// Posted first, so the root view swaps the signed-in screens out
    /// before their rows disappear underneath them.
    public static let willWipe = Notification.Name("LocalWipe.willWipe")
    /// Posted after a wipe so views holding onboarding state can reset.
    public static let didWipe = Notification.Name("LocalWipe.didWipe")

    public static func wipe(context: ModelContext, tokenStore: any TokenStore = KeychainTokenStore()) async {
        NotificationCenter.default.post(name: willWipe, object: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)

        wipeData(context: context, tokenStore: tokenStore, defaults: .standard)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        if let url = WidgetSnapshot.fileURL { try? FileManager.default.removeItem(at: url) }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        #if os(iOS) && !APP_EXTENSION
        ProStore.shared.signedOut()
        #endif

        NotificationCenter.default.post(name: didWipe, object: nil)
    }

    /// The store, the token and the settings — everything that's data.
    static func wipeData(context: ModelContext, tokenStore: any TokenStore, defaults: UserDefaults) {
        // Children before parents, so no cascade ever touches a row that's
        // already gone.
        deleteAll(SetLog.self, context)
        deleteAll(Session.self, context)
        deleteAll(PlannedItem.self, context)
        deleteAll(PlannedSession.self, context)
        deleteAll(Plan.self, context)
        deleteAll(CheckIn.self, context)
        deleteAll(MealLog.self, context)
        deleteAll(SkillBlock.self, context)
        deleteAll(CoachReport.self, context)
        deleteAll(Competition.self, context)
        deleteAll(AthleteSport.self, context)
        deleteAll(DownloadedPack.self, context)
        deleteAll(Athlete.self, context)
        try? context.save()

        try? tokenStore.delete()

        if defaults === UserDefaults.standard, let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        } else {
            for key in defaults.dictionaryRepresentation().keys { defaults.removeObject(forKey: key) }
        }
    }

    /// Row by row rather than a store-level batch delete, so the context
    /// knows every object is gone.
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) {
        for row in (try? context.fetch(FetchDescriptor<T>())) ?? [] where !row.isDeleted {
            context.delete(row)
        }
    }
}

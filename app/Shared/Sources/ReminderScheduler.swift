import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Local notifications only — no push server, no third party (§0). A daily
/// morning check-in nudge (§11: "a check-in nobody completes is worse than
/// none") and a heads-up the evening before each game.
public enum ReminderScheduler {
    static let checkInIdentifier = "reminder.check-in"
    static let gamePrefix = "reminder.game."

    public struct Settings: Codable, Equatable, Sendable {
        public var checkInEnabled: Bool
        public var checkInHour: Int
        public var checkInMinute: Int
        public var gameRemindersEnabled: Bool

        public static let `default` = Settings(checkInEnabled: false, checkInHour: 7, checkInMinute: 15, gameRemindersEnabled: false)
    }

    private static let settingsKey = "reminderSettings"

    public static var settings: Settings {
        get {
            guard let data = UserDefaults.standard.data(forKey: settingsKey),
                  let decoded = try? JSONDecoder().decode(Settings.self, from: data) else { return .default }
            return decoded
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: settingsKey)
        }
    }

    /// The evening-before reminder time for a game: 20:00 the day before,
    /// or nil if that moment has already passed.
    public static func gameReminderDate(for game: Date, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: game)),
              let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: dayBefore),
              evening > now else { return nil }
        return evening
    }

    #if canImport(UserNotifications)
    /// Asks once; returns whether notifications may be shown.
    public static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces every reminder this app owns with ones matching `settings`
    /// and the given upcoming games. Safe to call as often as convenient.
    public static func reschedule(games: [(date: Date, kind: String)]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(checkInIdentifier) || $0.hasPrefix(gamePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let current = settings
        if current.checkInEnabled {
            // One reminder per day for the next two weeks rather than a
            // repeating one, so sick, travel and holiday days (Home's day
            // status) stay quiet. Rescheduled every time the app opens.
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            for offset in 0..<14 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      DayStatusStore.status(on: day).trainsAsPlanned else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = current.checkInHour
                components.minute = current.checkInMinute
                guard let when = calendar.date(from: components), when > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Morning check-in"
                content.body = "Four taps: how did you sleep? Your plan adjusts to how you feel."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let id = "\(checkInIdentifier).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }

        if current.gameRemindersEnabled {
            for game in games.prefix(20) {
                guard let when = gameReminderDate(for: game.date) else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(game.kind) tomorrow"
                content.body = "Primer day today — keep it light, eat a good dinner and get to bed early."
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                let id = gamePrefix + String(Int(game.date.timeIntervalSince1970))
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
    #endif
}

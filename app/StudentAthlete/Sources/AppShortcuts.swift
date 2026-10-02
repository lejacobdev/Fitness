import AppIntents
import Foundation

/// Siri and Shortcuts: "Start my workout in AthleteOS", "Check in with
/// AthleteOS", "Log practice in AthleteOS", "Evening reflection in
/// AthleteOS", and "What's my plan today in AthleteOS?" — answered from the
/// same snapshot the widget shows, without opening the app.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start today's workout"
    static let description = IntentDescription("Opens AthleteOS on today's workout.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRoute.set(.workout)
        return .result()
    }
}

struct CheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Morning check-in"
    static let description = IntentDescription("Opens the 30-second morning check-in.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRoute.set(.checkIn)
        return .result()
    }
}

struct ReflectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Evening reflection"
    static let description = IntentDescription("Opens the one-minute evening reflection.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRoute.set(.reflection)
        return .result()
    }
}

struct LogPracticeIntent: AppIntent {
    static let title: LocalizedStringResource = "Log practice"
    static let description = IntentDescription("Opens the practice log for today.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRoute.set(.logPractice)
        return .result()
    }
}

struct TodaysPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "What's my plan today"
    static let description = IntentDescription("Says today's training without opening the app.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = WidgetSnapshot.load(), snapshot.isCurrent else {
            return .result(dialog: "Open AthleteOS once today and I'll know your plan.")
        }
        if snapshot.isGameDay { return .result(dialog: "It's game day. No workout — save your energy.") }
        if let title = snapshot.sessionTitle, let minutes = snapshot.sessionMinutes {
            let check = snapshot.checkedIn ? "" : " You haven't checked in yet."
            return .result(dialog: "\(title), about \(minutes) minutes, \(snapshot.exerciseCount) exercises.\(check)")
        }
        return .result(dialog: "No workout planned today. Rest is part of the plan.")
    }
}

struct AthleteOSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWorkoutIntent(), phrases: ["Start my workout in \(.applicationName)", "Start training with \(.applicationName)"],
                    shortTitle: "Start workout", systemImageName: "play.fill")
        AppShortcut(intent: CheckInIntent(), phrases: ["Check in with \(.applicationName)", "Morning check-in in \(.applicationName)"],
                    shortTitle: "Check in", systemImageName: "sun.max.fill")
        AppShortcut(intent: LogPracticeIntent(), phrases: ["Log practice in \(.applicationName)", "Log my practice with \(.applicationName)"],
                    shortTitle: "Log practice", systemImageName: "square.and.pencil")
        AppShortcut(intent: ReflectionIntent(), phrases: ["Evening reflection in \(.applicationName)", "Reflect on my day with \(.applicationName)"],
                    shortTitle: "Reflect", systemImageName: "moon.stars.fill")
        AppShortcut(intent: TodaysPlanIntent(), phrases: ["What's my plan today in \(.applicationName)", "What's my training today in \(.applicationName)"],
                    shortTitle: "Today's plan", systemImageName: "calendar")
    }
}

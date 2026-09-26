#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// The running workout on the Lock Screen and in the Dynamic Island: the
/// exercise, the set, and the rest countdown. Local only (no push updates).
public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var exercise: String
        public var detail: String
        /// When rest ends; nil while working.
        public var restEndsAt: Date?
        public var setsDone: Int
        public var setsTotal: Int

        public init(exercise: String, detail: String, restEndsAt: Date?, setsDone: Int, setsTotal: Int) {
            self.exercise = exercise
            self.detail = detail
            self.restEndsAt = restEndsAt
            self.setsDone = setsDone
            self.setsTotal = setsTotal
        }

        public var progress: Double { setsTotal == 0 ? 0 : min(1, Double(setsDone) / Double(setsTotal)) }
    }

    public var title: String

    public init(title: String) {
        self.title = title
    }
}

#if !APP_EXTENSION
@MainActor
enum WorkoutActivity {
    private static var current: Activity<WorkoutActivityAttributes>?

    static func show(title: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        if let current {
            Task { await current.update(content) }
        } else {
            current = try? Activity.request(attributes: WorkoutActivityAttributes(title: title), content: content, pushType: nil)
        }
    }

    static func end() {
        guard let activity = current else { return }
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
#endif
#endif

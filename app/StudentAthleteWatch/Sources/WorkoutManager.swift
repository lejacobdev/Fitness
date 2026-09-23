import Foundation
import HealthKit
import Observation

/// §16: "Start an HKWorkoutSession with an HKLiveWorkoutBuilder when the
/// session begins... That is what keeps the app foregrounded between sets,
/// and it gives heart rate and active energy free. Ending it writes one
/// HKWorkout — store its UUID on Session.healthKitWorkoutId so the phone
/// never writes a duplicate." Everything degrades gracefully when Health
/// access is denied: the session still logs, it just isn't kept alive or
/// written to Health.
@MainActor
@Observable
final class WorkoutManager: NSObject {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var heartRate: Double = 0
    private(set) var activeEnergy: Double = 0
    private(set) var isRunning = false

    static func activityType(forSport slug: String, hasSportDrills: Bool) -> HKWorkoutActivityType {
        guard hasSportDrills else { return .traditionalStrengthTraining }
        let map: [String: HKWorkoutActivityType] = [
            "soccer": .soccer, "football": .americanFootball, "flag-football": .americanFootball,
            "basketball": .basketball, "unified-basketball": .basketball, "wheelchair-basketball": .basketball,
            "baseball": .baseball, "softball": .softball, "volleyball": .volleyball, "boys-volleyball": .volleyball,
            "sand-volleyball": .volleyball, "tennis": .tennis, "ice-hockey": .hockey, "inline-hockey": .hockey,
            "field-hockey": .hockey, "lacrosse": .lacrosse, "lacrosse-box": .lacrosse, "rugby": .rugby,
            "wrestling": .wrestling, "golf": .golf, "rowing": .rowing, "cycling": .cycling, "gymnastics": .gymnastics,
            "fencing": .fencing, "badminton": .badminton, "table-tennis": .tableTennis, "squash": .squash,
            "team-handball": .handball, "climbing": .climbing, "track-and-field": .trackAndField,
            "cross-country": .running, "water-polo": .waterPolo, "martial-arts": .martialArts, "judo": .martialArts,
            "bowling": .bowling, "archery": .archery, "skiing": .downhillSkiing, "surfing": .surfingSports,
            "racquetball": .racquetball, "pickleball": .pickleball, "disc-golf": .discSports, "ultimate": .discSports,
        ]
        return map[slug] ?? .traditionalStrengthTraining
    }

    func start(activity: HKWorkoutActivityType) {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        store.requestAuthorization(toShare: share, read: read) { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor in self?.begin(activity) }
        }
    }

    private func begin(_ activity: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = .unknown
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let startDate = Date()
            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { _, _ in }
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// Ends the workout and hands back the saved HKWorkout's UUID (nil if
    /// Health access wasn't granted or nothing was running).
    func end(completion: @escaping @MainActor (String?) -> Void) {
        guard let session, let builder else {
            completion(nil)
            return
        }
        session.end()
        isRunning = false
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.finishWorkout { workout, _ in
                let id = workout?.uuid.uuidString
                Task { @MainActor in completion(id) }
            }
        }
        self.session = nil
        self.builder = nil
    }

    fileprivate func update(heartRate: Double?, energy: Double?) {
        if let heartRate { self.heartRate = heartRate }
        if let energy { self.activeEnergy = energy }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let bpm = workoutBuilder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?.doubleValue(for: bpmUnit)
        let kcal = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        Task { @MainActor in self.update(heartRate: bpm, energy: kcal) }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

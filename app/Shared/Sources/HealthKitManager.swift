import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// §17. The app must work fully for someone who refuses every permission,
/// so every call here degrades to "nil / false" rather than throwing at the
/// caller. Nonisolated and Sendable: HealthKit's store is thread-safe, and
/// keeping the async work off the main actor avoids moving non-Sendable
/// HealthKit objects across isolation boundaries.
public final class HealthKitManager: @unchecked Sendable {
    public static let shared = HealthKitManager()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    public init() {}

    public var isAvailable: Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    /// Shows the system sheet (only ever after the app's own reason-first
    /// screen, HealthPermissionView). Returns whether the request completed;
    /// HealthKit deliberately never reveals whether READ access was granted.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard isAvailable else { return false }
        let read: Set<HKObjectType> = [HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    /// Hours actually asleep in the night ending on `morning` (18:00 the day
    /// before until noon), summing only asleep stages — never `inBed` — and
    /// merging overlapping iPhone/Watch samples. nil when there is no data
    /// or no permission.
    public func sleepHours(forNightEnding morning: Date = .now, calendar: Calendar = .current) async -> Double? {
        #if canImport(HealthKit)
        guard isAvailable else { return nil }
        let day = calendar.startOfDay(for: morning)
        guard
            let start = calendar.date(byAdding: .hour, value: -6, to: day),
            let end = calendar.date(byAdding: .hour, value: 12, to: day)
        else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let intervals: [SleepInterval] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis), predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let asleep = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .map { SleepInterval(start: $0.startDate, end: $0.endDate) }
                continuation.resume(returning: asleep)
            }
            store.execute(query)
        }
        guard !intervals.isEmpty else { return nil }
        let hours = SleepMath.asleepHours(intervals.map { ($0.start, $0.end) })
        return hours > 0 ? hours : nil
        #else
        return nil
        #endif
    }

    /// Writes ONE workout for a finished session and returns its UUID, which
    /// the caller stores on `Session.healthKitWorkoutId` so it is never
    /// written twice (§16/§17). Returns the existing id untouched if one is
    /// already recorded.
    public func saveWorkout(start: Date, end: Date, sportSlug: String?, existingId: String?) async -> String? {
        if let existingId { return existingId }
        #if canImport(HealthKit)
        guard isAvailable, end > start else { return nil }
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return nil }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = Self.activityType(for: sportSlug)
        configuration.locationType = .unknown
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            return workout?.uuid.uuidString
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(HealthKit)
    /// §16: "the workout type mapped from the sport (.hockey, .soccer,
    /// .traditionalStrengthTraining for gym work)".
    static func activityType(for sportSlug: String?) -> HKWorkoutActivityType {
        switch sportSlug {
        case "soccer": .soccer
        case "football", "flag-football": .americanFootball
        case "basketball", "unified-basketball", "wheelchair-basketball": .basketball
        case "baseball", "beep-baseball": .baseball
        case "softball": .softball
        case "volleyball", "boys-volleyball", "sand-volleyball", "sitting-volleyball": .volleyball
        case "ice-hockey", "inline-hockey", "adapted-floor-hockey", "field-hockey", "field-hockey-goalkeeping": .hockey
        case "lacrosse", "lacrosse-box": .lacrosse
        case "tennis": .tennis
        case "golf", "disc-golf": .golf
        case "swimming-diving", "adapted-swimming", "water-polo": .swimming
        case "cross-country", "track-and-field", "indoor-track-and-field", "unified-track", "para-track", "orienteering": .running
        case "wrestling": .wrestling
        case "gymnastics": .gymnastics
        case "rowing": .rowing
        case "skiing": .downhillSkiing
        case "snowboarding": .snowboarding
        case "fencing": .fencing
        case "badminton": .badminton
        case "table-tennis": .tableTennis
        case "squash": .squash
        case "racquetball": .racquetball
        case "pickleball": .pickleball
        case "team-handball": .handball
        case "rugby": .rugby
        case "archery": .archery
        case "cycling", "mountain-biking", "bmx": .cycling
        case "sailing": .sailing
        case "surfing": .surfingSports
        case "judo": .martialArts
        case "climbing": .climbing
        case "equestrian": .equestrianSports
        case "bowling": .bowling
        case "competitive-dance", "step-team": .socialDance
        case "triathlon", "triathlon-duathlon": .mixedCardio
        default: .traditionalStrengthTraining
        }
    }
    #endif
}

/// A Sendable pair of dates, so samples can leave HealthKit's callback
/// queue without carrying HealthKit objects across isolation boundaries.
struct SleepInterval: Sendable {
    let start: Date
    let end: Date
}

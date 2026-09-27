import Foundation

/// Workouts from a watch or band, used by the plan: a hard run earlier
/// today (or late yesterday) makes today's gym work lighter, and a workout
/// at practice time counts as practice done — no logging by hand.
public enum WearableLoad {
    /// Effort on the 1–10 scale from heart rate against the age-predicted
    /// maximum (208 − 0.7 × age); from duration alone without heart rate.
    public static func effort(averageHeartRate: Double?, minutes: Int, age: Int) -> Int {
        guard let heartRate = averageHeartRate, heartRate > 0 else { return minutes >= 60 ? 6 : 4 }
        let share = heartRate / (208 - 0.7 * Double(age))
        switch share {
        case ..<0.6: return 3
        case ..<0.7: return 5
        case ..<0.8: return 6
        case ..<0.87: return 7
        case ..<0.93: return 8
        default: return 9
        }
    }

    public static func isHard(_ workout: ExternalWorkout, age: Int) -> Bool {
        let effort = effort(averageHeartRate: workout.averageHeartRate, minutes: workout.minutes, age: age)
        return (effort >= 7 && workout.minutes >= 30) || workout.minutes >= 75
    }

    /// Why today is lighter, when a hard workout happened today or after
    /// 6 pm yesterday. Workouts during practice are practice, not extra.
    public static func reason(_ workouts: [ExternalWorkout], now: Date, age: Int, practiceToday: PracticeTime?,
                              calendar: Calendar = .current) -> String? {
        let today = calendar.startOfDay(for: now)
        let lateYesterday = today.addingTimeInterval(-6 * 3600)
        let hard = workouts.filter { workout in
            workout.start >= lateYesterday && workout.start <= now && isHard(workout, age: age)
                && !(practiceToday.map { overlaps(workout, practice: $0, day: today, calendar: calendar) } ?? false)
        }
        guard let latest = hard.max(by: { $0.start < $1.start }) else { return nil }
        let when = latest.start >= today ? "earlier today" : "last night"
        return "Your watch saw a hard \(latest.activity.lowercased()) \(when), so the gym work is lighter."
    }

    /// Whether a workout falls in the practice window (30 minutes either side).
    public static func overlaps(_ workout: ExternalWorkout, practice: PracticeTime, day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let start = dayStart.addingTimeInterval(Double(practice.start - 30) * 60)
        let end = dayStart.addingTimeInterval(Double(practice.end + 30) * 60)
        return workout.start < end && workout.end > start
    }

    /// The practice log a watch workout stands for (nil when none fits).
    public static func practiceLog(from workouts: [ExternalWorkout], practice: PracticeTime, day: Date, sportSlug: String,
                                   age: Int, calendar: Calendar = .current) -> PracticeLog? {
        guard let workout = workouts.first(where: { overlaps($0, practice: practice, day: day, calendar: calendar) && $0.minutes >= 20 })
        else { return nil }
        let effort = effort(averageHeartRate: workout.averageHeartRate, minutes: workout.minutes, age: age)
        let hard = min(5, max(1, (effort + 1) / 2))
        return PracticeLog(day: DayKey.of(day, calendar: calendar), sportSlug: sportSlug, types: [], hard: hard, went: 3, mood: 3,
                           minutes: workout.minutes, note: "From your watch")
    }
}

/// The last few days of outside workouts, kept on this phone (Health data
/// is never backed up to the server).
public enum ExternalWorkoutStore {
    static let key = "health.externalWorkouts"

    public static var recent: [ExternalWorkout] {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([ExternalWorkout].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    /// Reads the last three days from Health, and logs today's and
    /// yesterday's practice from a watch workout when it isn't logged yet.
    @MainActor
    public static func refresh(sportSlug: String?, birthDate: Date, now: Date = .now, calendar: Calendar = .current) async {
        guard HealthKitManager.shared.isAvailable,
              let since = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: now)) else { return }
        let workouts = await HealthKitManager.shared.externalWorkouts(since: since)
        recent = workouts
        guard let sportSlug else { return }
        let age = PlanGenerator.ageInYears(birthDate: birthDate, now: now)
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  PracticeSchedule.hasPractice(on: day, calendar: calendar),
                  let practice = PracticeSchedule.time(on: day, calendar: calendar),
                  PracticeLogStore.log(on: DayKey.of(day, calendar: calendar), sportSlug: sportSlug) == nil,
                  let log = WearableLoad.practiceLog(from: workouts, practice: practice, day: day, sportSlug: sportSlug, age: age, calendar: calendar)
            else { continue }
            // Only once practice is over.
            if offset == 0, calendar.startOfDay(for: now).addingTimeInterval(Double(practice.end) * 60) > now { continue }
            PracticeLogStore.save(log)
        }
    }
}

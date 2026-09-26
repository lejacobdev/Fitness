import Foundation

/// The morning check-in, filled in from Apple Health where it can be, so it
/// takes two taps: sleep from the hours actually slept, energy from resting
/// heart rate against the athlete's own normal. Soreness and stress can't
/// be measured — those stay the athlete's two taps. Pre-filled answers are
/// always shown as such and can be changed.
public enum CheckInPrefill {
    /// Teenagers need about 8–10 hours.
    public static func sleepRating(hours: Double) -> Int {
        switch hours {
        case 8.5...: 5
        case 7.5..<8.5: 4
        case 6.5..<7.5: 3
        case 5.5..<6.5: 2
        default: 1
        }
    }

    /// A resting heart rate a few beats above normal is a common sign of
    /// fatigue, a coming cold or poor recovery. Never guesses the extremes
    /// (1 or 5), and says nothing without a normal to compare with.
    public static func energyRating(restingHeartRate today: Double, usual: Double?) -> Int? {
        guard let usual else { return nil }
        let above = today - usual
        switch above {
        case ...2: return 4
        case ...5: return 3
        default: return 2
        }
    }
}

/// The morning check-in from a watch or band (Apple Watch, WHOOP, Oura,
/// Garmin… — anything that writes to Apple Health): sleep from the night's
/// hours, energy from recovery signals against the athlete's own normal.
/// Never the extremes on energy, and nothing without a normal to compare with.
public enum WearablePrefill {
    /// Sleep quality (1 poor, 3 okay, 4 good, 5 great) from hours asleep.
    public static func sleepQuality(hours: Double) -> Int {
        switch CheckInPrefill.sleepRating(hours: hours) {
        case 5: 5
        case 4: 4
        case 3: 3
        default: 1
        }
    }

    /// Energy (1 low, 3 okay, 4 good) from this morning's resting heart rate
    /// and heart-rate variability against the usual: a resting heart rate a
    /// few beats higher, or variability well below normal, often goes with
    /// being tired or getting ill.
    public static func energy(restingHeartRate: (today: Double, usual: Double?)?, hrv: (today: Double, usual: Double?)?) -> Int? {
        var level: Int?
        if let rhr = restingHeartRate, let usual = rhr.usual {
            let above = rhr.today - usual
            level = above > 5 ? 1 : (above > 2 ? 3 : 4)
        }
        if let hrv, let usual = hrv.usual, usual > 0 {
            let drop = (usual - hrv.today) / usual
            let fromHRV = drop > 0.25 ? 1 : (drop > 0.1 ? 3 : 4)
            level = min(level ?? fromHRV, fromHRV)
        }
        return level
    }
}

public enum RestingHeartRate {
    /// Today's value (the latest sample today) and the median of the daily
    /// values over the weeks before — needs 7 days to call it "usual".
    public static func summarize(_ samples: [(date: Date, bpm: Double)], today: Date, calendar: Calendar = .current)
        -> (today: Double, usual: Double?)? {
        let todays = samples.filter { calendar.isDate($0.date, inSameDayAs: today) }
        guard let latest = todays.max(by: { $0.date < $1.date }) else { return nil }
        var perDay: [Date: [Double]] = [:]
        for sample in samples where calendar.startOfDay(for: sample.date) < calendar.startOfDay(for: today) {
            perDay[calendar.startOfDay(for: sample.date), default: []].append(sample.bpm)
        }
        let daily = perDay.values.map { values in values.reduce(0, +) / Double(values.count) }.sorted()
        guard daily.count >= 7 else { return (latest.bpm, nil) }
        let middle = daily.count / 2
        let median = daily.count % 2 == 0 ? (daily[middle - 1] + daily[middle]) / 2 : daily[middle]
        return (latest.bpm, median)
    }
}

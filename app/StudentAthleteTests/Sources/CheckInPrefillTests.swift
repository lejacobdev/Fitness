import XCTest

/// The two-tap check-in: sleep and energy filled in from Apple Health.
final class CheckInPrefillTests: XCTestCase {
    func testSleepHoursBecomeARating() {
        XCTAssertEqual(CheckInPrefill.sleepRating(hours: 9), 5)
        XCTAssertEqual(CheckInPrefill.sleepRating(hours: 7.9), 4)
        XCTAssertEqual(CheckInPrefill.sleepRating(hours: 6.8), 3)
        XCTAssertEqual(CheckInPrefill.sleepRating(hours: 5), 1)
    }

    func testRestingHeartRateAboveNormalLowersEnergyButNeverGuessesExtremes() {
        XCTAssertEqual(CheckInPrefill.energyRating(restingHeartRate: 57, usual: 56), 4)
        XCTAssertEqual(CheckInPrefill.energyRating(restingHeartRate: 60, usual: 56), 3)
        XCTAssertEqual(CheckInPrefill.energyRating(restingHeartRate: 70, usual: 56), 2)
        XCTAssertNil(CheckInPrefill.energyRating(restingHeartRate: 70, usual: nil), "no normal to compare with yet")
    }

    func testUsualRestingHeartRateIsTheMedianOfEarlierDays() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25))!
        var samples: [(date: Date, bpm: Double)] = (1...10).map {
            (calendar.date(byAdding: .day, value: -$0, to: today)!.addingTimeInterval(6 * 3600), Double(50 + $0))
        }
        samples.append((today.addingTimeInterval(7 * 3600), 62))
        let summary = RestingHeartRate.summarize(samples, today: today, calendar: calendar)
        XCTAssertEqual(summary?.today, 62)
        XCTAssertEqual(summary?.usual, 55.5)
        XCTAssertNil(RestingHeartRate.summarize(Array(samples.prefix(3)) + [samples[10]], today: today, calendar: calendar)?.usual,
                     "a week of data before there's a normal")
    }

    func testAWatchOrBandFillsInEnergyAgainstTheAthletesNormal() {
        XCTAssertEqual(WearablePrefill.energy(restingHeartRate: (52, 53), hrv: (70, 72)), 4, "normal night: good")
        XCTAssertEqual(WearablePrefill.energy(restingHeartRate: (57, 53), hrv: nil), 3, "a few beats up: okay")
        XCTAssertEqual(WearablePrefill.energy(restingHeartRate: (52, 53), hrv: (50, 72)), 1, "variability well below normal wins: low")
        XCTAssertEqual(WearablePrefill.energy(restingHeartRate: nil, hrv: (65, 72)), 4)
        XCTAssertNil(WearablePrefill.energy(restingHeartRate: (60, nil), hrv: (40, nil)), "no normal yet, no guess")
        XCTAssertNil(WearablePrefill.energy(restingHeartRate: nil, hrv: nil))
    }

    func testSleepQualityFromHours() {
        XCTAssertEqual(WearablePrefill.sleepQuality(hours: 9), 5)
        XCTAssertEqual(WearablePrefill.sleepQuality(hours: 7.8), 4)
        XCTAssertEqual(WearablePrefill.sleepQuality(hours: 7), 3)
        XCTAssertEqual(WearablePrefill.sleepQuality(hours: 5.5), 1)
    }
}

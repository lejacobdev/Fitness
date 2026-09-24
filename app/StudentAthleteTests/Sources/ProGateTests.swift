import XCTest

final class ProGateTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    func testProComesFromTheServersProUntilOrALiveSubscription() {
        XCTAssertFalse(ProGate.isPro(proUntil: nil, now: now))
        XCTAssertFalse(ProGate.isPro(proUntil: day(-1), now: now), "an expired proUntil is not Pro")
        XCTAssertTrue(ProGate.isPro(proUntil: day(30), now: now))
        XCTAssertTrue(ProGate.isPro(proUntil: nil, hasActiveSubscription: true, now: now), "an Ask to Buy approval unlocks before the server hears")
    }

    /// §4: "The check-in, the plan, logging and the Watch are free forever"
    /// and §20: account deletion is never behind the paywall.
    func testTheDailyHabitAndAccountDeletionAreNeverGated() {
        for feature in [ProFeature.checkIn, .weeklyPlan, .logging, .watch, .fuelling, .accountDeletion, .coachWeeklyReport] {
            XCTAssertTrue(feature.isFreeForever, "\(feature)")
            XCTAssertTrue(ProGate.isAvailable(feature, isPro: false), "\(feature) must be free")
        }
    }

    func testProFeaturesAreGatedOnFreeAndOpenOnPro() {
        for feature in ProFeature.allCases where !feature.isFreeForever {
            XCTAssertFalse(ProGate.isAvailable(feature, isPro: false), "\(feature)")
            XCTAssertTrue(ProGate.isAvailable(feature, isPro: true), "\(feature)")
            XCTAssertFalse(feature.proDescription.isEmpty, "\(feature) needs paywall copy")
        }
    }

    func testFreeGetsThreeSkillBlocksPerCalendarMonth() {
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        XCTAssertEqual(ProGate.remainingSkillBlocks(isPro: false, savedBlockDates: [], now: now, calendar: calendar), 3)
        XCTAssertEqual(ProGate.remainingSkillBlocks(isPro: false, savedBlockDates: [now, lastMonth], now: now, calendar: calendar), 2,
                       "last month's blocks don't count")
        XCTAssertFalse(ProGate.canSaveSkillBlock(isPro: false, savedBlockDates: [now, now, now], now: now, calendar: calendar))
        XCTAssertNil(ProGate.remainingSkillBlocks(isPro: true, savedBlockDates: [now, now, now, now], now: now, calendar: calendar))
        XCTAssertTrue(ProGate.canSaveSkillBlock(isPro: true, savedBlockDates: Array(repeating: now, count: 20), now: now, calendar: calendar))
    }

    func testFreeHistoryIsTheLastThirtyDays() {
        let cutoff = ProGate.historyCutoff(isPro: false, now: now, calendar: calendar)
        XCTAssertEqual(cutoff, calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)))
        XCTAssertNil(ProGate.historyCutoff(isPro: true, now: now, calendar: calendar))
    }

    func testAFreeAthleteAlwaysKeepsOneSport() {
        XCTAssertTrue(ProGate.canDownloadAnotherSport(isPro: false, downloadedSportCount: 0))
        XCTAssertFalse(ProGate.canDownloadAnotherSport(isPro: false, downloadedSportCount: 1))
        XCTAssertTrue(ProGate.canDownloadAnotherSport(isPro: true, downloadedSportCount: 9))
    }

    func testFreeTapersForTheNextGameOnlyWhileProSeesTheWholeCalendar() {
        let games = [day(-2), day(3), day(6), day(20)]
        XCTAssertEqual(ProGate.competitionsForTaper(games, isPro: false, now: now, calendar: calendar), [day(-2), day(3)])
        XCTAssertEqual(ProGate.competitionsForTaper(games, isPro: true, now: now, calendar: calendar), games)
    }

    func testFreeHasOneSportAndProHasMany() {
        XCTAssertTrue(ProGate.canAddSport(isPro: false, currentSportCount: 0))
        XCTAssertFalse(ProGate.canAddSport(isPro: false, currentSportCount: 1))
        XCTAssertTrue(ProGate.canAddSport(isPro: true, currentSportCount: 4))
    }

    func testFreeGetsOneMuscleWorkoutPerWeek() {
        let lastWeek = calendar.date(byAdding: .day, value: -8, to: now)!
        XCTAssertEqual(ProGate.remainingMuscleWorkouts(isPro: false, startDates: [lastWeek], now: now, calendar: calendar), 1)
        XCTAssertEqual(ProGate.remainingMuscleWorkouts(isPro: false, startDates: [now], now: now, calendar: calendar), 0)
        XCTAssertNil(ProGate.remainingMuscleWorkouts(isPro: true, startDates: [now, now], now: now, calendar: calendar))
    }

    func testFreeAthletesCanChangeSportThreeTimesAMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let thisMonth = [calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))!, calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!]
        let lastMonth = [calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!]
        XCTAssertEqual(ProGate.remainingSportSwitches(isPro: false, switchDates: [], now: now, calendar: calendar), 3)
        XCTAssertEqual(ProGate.remainingSportSwitches(isPro: false, switchDates: thisMonth + lastMonth, now: now, calendar: calendar), 1)
        XCTAssertEqual(ProGate.remainingSportSwitches(isPro: false, switchDates: thisMonth + thisMonth, now: now, calendar: calendar), 0)
        XCTAssertNil(ProGate.remainingSportSwitches(isPro: true, switchDates: thisMonth, now: now, calendar: calendar))
    }
}

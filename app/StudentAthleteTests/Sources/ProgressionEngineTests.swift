import XCTest

/// Progressive overload and planned deload weeks.
final class ProgressionEngineTests: XCTestCase {
    private let squat = Dose(kind: "reps", sets: 3, reps: 8)

    func testEveryRepAtAnEasyEnoughEffortAddsOneStep() {
        let sets = Array(repeating: LoggedSet(reps: 8, weightKg: 40), count: 3)
        let once = ProgressionEngine.next(last: sets, dose: squat, sessionRPE: 7, isYouth: true, stepKg: 2.5)
        XCTAssertEqual(once?.weightKg, 40, "one steady session consolidates")
        XCTAssertEqual(once?.state, .introduce)
        let target = ProgressionEngine.next(last: sets, dose: squat, sessionRPE: 7, isYouth: true, stepKg: 2.5, previous: sets, previousRPE: 7)
        XCTAssertEqual(target?.weightKg, 42.5, "two steady sessions in a row: one step")
        XCTAssertEqual(target?.reps, 8)
        XCTAssertEqual(target?.state, .progress)
        let pain = ProgressionEngine.next(last: sets, dose: squat, sessionRPE: 7, isYouth: true, stepKg: 2.5, previous: sets, previousRPE: 7, painInArea: true)
        XCTAssertEqual(pain?.weightKg, 40, "pain pauses progression")
        XCTAssertEqual(pain?.state, .pauseForReview)
    }

    func testMissedRepsOrAMaximalSessionKeepTheWeight() {
        let missed = [LoggedSet(reps: 8, weightKg: 40), LoggedSet(reps: 8, weightKg: 40), LoggedSet(reps: 6, weightKg: 40)]
        XCTAssertEqual(ProgressionEngine.next(last: missed, dose: squat, sessionRPE: 7, isYouth: true, stepKg: 2.5)?.weightKg, 40)
        let all = Array(repeating: LoggedSet(reps: 8, weightKg: 40), count: 3)
        XCTAssertEqual(ProgressionEngine.next(last: all, dose: squat, sessionRPE: 9, isYouth: true, stepKg: 2.5)?.weightKg, 40,
                       "RPE 9 means it was hard enough")
    }

    func testBodyweightAddsARepUpToTheYouthCapAndHoldsAddFiveSeconds() {
        let pushUps = Array(repeating: LoggedSet(reps: 10), count: 3)
        XCTAssertEqual(ProgressionEngine.next(last: pushUps, dose: Dose(kind: "reps", sets: 3, reps: 10), sessionRPE: nil, isYouth: true, stepKg: 2.5, previous: pushUps)?.reps, 11)
        let capped = Array(repeating: LoggedSet(reps: 15), count: 3)
        XCTAssertEqual(ProgressionEngine.next(last: capped, dose: Dose(kind: "reps", sets: 3, reps: 12), sessionRPE: nil, isYouth: true, stepKg: 2.5, previous: capped)?.reps, 15)
        let plank = Array(repeating: LoggedSet(seconds: 30), count: 2)
        XCTAssertEqual(ProgressionEngine.next(last: plank, dose: Dose(kind: "time", sets: 2, seconds: 30), sessionRPE: 6, isYouth: true, stepKg: 2.5, previous: plank, previousRPE: 6)?.seconds, 35)
    }

    func testADeloadWeekGoesLighter() {
        let sets = Array(repeating: LoggedSet(reps: 8, weightKg: 40), count: 3)
        XCTAssertEqual(ProgressionEngine.next(last: sets, dose: squat, sessionRPE: 6, isYouth: true, stepKg: 2.5, deload: true)?.weightKg, 35)
        XCTAssertNil(ProgressionEngine.next(last: [], dose: squat, sessionRPE: nil, isYouth: true, stepKg: 2.5))
    }

    func testEveryFifthBuildingWeekIsADeload() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! // a Monday
        func week(_ n: Int) -> Date { calendar.date(byAdding: .day, value: 7 * n, to: anchor)! }
        let deloads = (0..<15).filter { Deload.isDeloadWeek(weekStart: week($0), anchor: anchor, phase: .offSeason, calendar: calendar) }
        XCTAssertEqual(deloads, [4, 9, 14])
        XCTAssertFalse(Deload.isDeloadWeek(weekStart: week(4), anchor: anchor, phase: .inSeason, calendar: calendar), "in season is already light")
    }

    func testADeloadWeekTakesASetOffAndCutsJumps() {
        let items = [
            GeneratedPlannedItem(itemSlug: "squat", order: 0, dose: Dose(kind: "reps", sets: 3, reps: 8), restSec: 90, rationale: "", quality: "lower-body-strength"),
            GeneratedPlannedItem(itemSlug: "hop", order: 1, dose: Dose(kind: plyometricDoseKind, sets: 1, contacts: 20), restSec: 60, rationale: "", quality: "reactive-strength"),
        ]
        let week = GeneratedWeek(phase: .offSeason, weekStart: .now, sessions: [
            GeneratedSession(date: .now, title: "S", focusQualities: [], estimatedMinutes: 20, items: items, slot: 0),
        ])
        let lighter = Deload.apply(to: week).sessions[0]
        XCTAssertEqual(lighter.items[0].dose.sets, 2)
        XCTAssertEqual(lighter.items[1].dose.sets, 1)
        XCTAssertEqual(lighter.items[1].dose.contacts, 12)
        XCTAssertEqual(lighter.slot, 0)
        XCTAssertLessThan(lighter.estimatedMinutes, 20)
    }
}

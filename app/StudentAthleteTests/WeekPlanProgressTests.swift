import XCTest
@testable import StudentAthlete

final class WeekPlanProgressTests: XCTestCase {
    func testCountsDoneAgainstPlanned() {
        let plan = WeekPlanProgress(workoutsPlanned: 3, workoutsDone: 1, practicesPlanned: 2, practicesDone: 2)
        XCTAssertEqual(plan.plannedTotal, 5)
        XCTAssertEqual(plan.doneTotal, 3)
        XCTAssertEqual(plan.remaining, 2)
        XCTAssertFalse(plan.isComplete)
        XCTAssertEqual(plan.segments.filter(\.done).count, 3)
    }

    func testExtraSessionsNeverOverflowTheBar() {
        let plan = WeekPlanProgress(workoutsPlanned: 2, workoutsDone: 4, practicesPlanned: 0, practicesDone: 0)
        XCTAssertEqual(plan.doneTotal, 2)
        XCTAssertEqual(plan.extraTotal, 2)
        XCTAssertTrue(plan.isComplete)
        XCTAssertEqual(plan.segments.count, 2)
        XCTAssertEqual(plan.statusLine, "Week complete, plus 2 extra")
    }

    func testNothingPlannedIsHidden() {
        XCTAssertFalse(WeekPlanProgress(workoutsPlanned: 0, workoutsDone: 2, practicesPlanned: 0, practicesDone: 0).isVisible)
    }

    func testStatusLineIsCalm() {
        XCTAssertEqual(WeekPlanProgress(workoutsPlanned: 2, workoutsDone: 1, practicesPlanned: 0, practicesDone: 0).statusLine, "1 still ahead")
    }
}

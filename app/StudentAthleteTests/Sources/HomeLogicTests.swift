import XCTest

/// Home's rules: the day status, workouts built around practice days, and
/// the after-practice / mobility / travel workouts.
final class HomeLogicTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    override func tearDown() {
        DayStatusStore.set(.active, days: nil)
        super.tearDown()
    }

    private func item(_ slug: String, _ qualities: [String: Double], dose: Dose = Dose(kind: "reps", sets: 4, reps: 10)) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug, kind: "exercise", qualities: qualities, muscles: [:],
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: dose, restSeconds: 90, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    // MARK: - Day status

    func testAStatusLastsItsDaysThenFallsBackToActive() {
        let today = Date.now
        DayStatusStore.set(.holiday, days: 3, now: today)
        XCTAssertEqual(DayStatusStore.status(on: today), .holiday)
        XCTAssertEqual(DayStatusStore.status(on: calendar.date(byAdding: .day, value: 2, to: today)!), .holiday)
        XCTAssertEqual(DayStatusStore.status(on: calendar.date(byAdding: .day, value: 3, to: today)!), .active)
        XCTAssertFalse(DayStatus.holiday.trainsAsPlanned)
    }

    func testUntilChangedAndBackToActive() {
        DayStatusStore.set(.sick, days: nil)
        XCTAssertEqual(DayStatusStore.status(on: calendar.date(byAdding: .day, value: 30, to: .now)!), .sick)
        DayStatusStore.set(.active, days: nil)
        XCTAssertEqual(DayStatusStore.status(), .active)
    }

    // MARK: - Gym days around practice

    func testGymDaysMoveOffPracticeAndGameDays() {
        let weekStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))! // a Monday
        let sessions = (0..<3).map { offset in
            GeneratedSession(date: calendar.date(byAdding: .day, value: offset * 2, to: weekStart)!, title: "S\(offset)",
                             focusQualities: [], estimatedMinutes: 45, items: [])
        }
        let week = GeneratedWeek(phase: .inSeason, weekStart: weekStart, sessions: sessions)
        let practice: Set<Int> = [2, 4, 6] // Mon, Wed, Fri
        let game = calendar.date(byAdding: .day, value: 5, to: weekStart)! // Saturday
        let aligned = WeeklyPlan.alignToSchedule(week, practiceWeekdays: practice, gameDays: [game], calendar: calendar)!
        XCTAssertFalse(aligned.sessions.isEmpty)
        for session in aligned.sessions {
            XCTAssertFalse(practice.contains(calendar.component(.weekday, from: session.date)), "gym day on a practice day")
            XCTAssertFalse(calendar.isDate(session.date, inSameDayAs: game), "gym day on a game day")
        }
    }

    func testNoPracticeDaysLeavesThePlanAlone() {
        let week = GeneratedWeek(phase: .offSeason, weekStart: .now, sessions: [GeneratedSession(date: .now, title: "S", focusQualities: [], estimatedMinutes: 40, items: [])])
        XCTAssertEqual(WeeklyPlan.alignToSchedule(week, practiceWeekdays: [], gameDays: []), week)
    }

    // MARK: - Workout modes

    private var catalogue: Catalogue {
        let items = [
            item("split-squat", ["lower-body-strength": 1]), item("reverse-lunge", ["lower-body-strength": 1]),
            item("inverted-row", ["upper-body-pull": 1]), item("push-up", ["upper-body-push": 1]),
            item("nordic-hamstring-curl", ["deceleration": 1]), item("copenhagen-plank", ["trunk-anti-rotation": 1], dose: Dose(kind: "time", sets: 3, seconds: 20)),
            item("standing-calf-raise", ["ankle-stiffness": 1]), item("dead-bug", ["trunk-anti-rotation": 1]),
            item("pogo-hop", ["reactive-strength": 1], dose: Dose(kind: "contacts", sets: 3, contacts: 20)),
            item("worlds-greatest-stretch", ["hip-mobility": 1]), item("90-90-hip-switch", ["hip-mobility": 1]),
            item("thoracic-open-book", ["shoulder-stability": 1]), item("ankle-knee-to-wall", ["ankle-stiffness": 1]),
            item("hamstring-floss", ["hip-mobility": 1]), item("breathing-90-90", ["trunk-anti-rotation": 1]),
            item("bodyweight-squat", ["lower-body-strength": 1]), item("single-leg-glute-bridge", ["single-leg-stability": 1]),
            item("side-plank", ["trunk-anti-rotation": 1], dose: Dose(kind: "time", sets: 3, seconds: 30)),
        ]
        return Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
    }

    private func context(_ sport: String = "soccer") -> WorkoutModeContext {
        WorkoutModeContext(catalogue: catalogue, sport: allSportsBySlug[sport], positionSlug: nil, formatSlug: nil,
                           equipment: [], trainsUnderCoach: false, age: 16)
    }

    func testAfterPracticeIsShortStrengthAndPreventionWithNoJumping() throws {
        let session = try XCTUnwrap(WorkoutModeBuilder.build(.afterPractice, context()))
        XCTAssertGreaterThanOrEqual(session.items.count, 4)
        XCTAssertTrue(session.items.allSatisfy { $0.dose.sets <= 2 }, "after practice stays low-volume")
        XCTAssertFalse(session.items.contains { $0.dose.kind == "contacts" }, "no plyometrics on tired legs")
        XCTAssertTrue(session.items.contains { $0.itemSlug == "nordic-hamstring-curl" }, "soccer loads the hamstrings")
        XCTAssertLessThanOrEqual(session.estimatedMinutes, 35)
    }

    func testMobilityEndsWithBreathingAndTravelNeedsNothing() throws {
        let mobility = try XCTUnwrap(WorkoutModeBuilder.build(.mobility, context()))
        XCTAssertEqual(mobility.items.last?.itemSlug, "breathing-90-90")
        let travel = try XCTUnwrap(WorkoutModeBuilder.build(.travel, context()))
        XCTAssertGreaterThanOrEqual(travel.items.count, 5)
        XCTAssertNil(WorkoutModeBuilder.build(.gymDay, context()), "gym days use the weekly plan")
    }

    func testTheDailyQuoteIsStableForADay() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 7))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 22))!
        XCTAssertEqual(DailyQuotes.quote(for: morning), DailyQuotes.quote(for: evening))
    }
}

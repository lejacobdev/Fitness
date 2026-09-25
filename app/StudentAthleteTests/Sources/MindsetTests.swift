import XCTest

/// The Mindset level: reflections, season goals and their weekly focus,
/// and the pre-game routines.
final class MindsetTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let keys = ["mindset.reflections", "mindset.goals", "mindset.focusDone", "mindset.routines", "mindset.cueWord"]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    private var evening: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 21))! }

    func testOneReflectionPerDayAndAStreak() {
        MindsetStore.saveReflection(win: "Stayed calm", lesson: "Call for the ball earlier", feeling: 4, on: evening, calendar: calendar)
        MindsetStore.saveReflection(win: "Good serve", lesson: "Sleep earlier", feeling: nil, on: evening.addingTimeInterval(-86_400), calendar: calendar)
        MindsetStore.saveReflection(win: "Stayed calm again", lesson: "Talk more", feeling: 5, on: evening, calendar: calendar)
        XCTAssertEqual(MindsetStore.reflections.count, 2, "a second one the same evening replaces the first")
        XCTAssertEqual(MindsetStore.reflection(on: evening, calendar: calendar)?.win, "Stayed calm again")
        XCTAssertEqual(MindsetStore.reflectionStreak(now: evening, calendar: calendar), 2)
    }

    func testGoalsGiveAWeeklyFocusThatChanges() {
        MindsetStore.goals = [
            SeasonGoal(text: "Start every game", area: .performance),
            SeasonGoal(text: "Stay calm", area: .confidence),
            SeasonGoal(text: "Bounce back", area: .confidence),
            SeasonGoal(text: "One too many", area: .team),
        ]
        XCTAssertEqual(MindsetStore.goals.count, MindsetEngine.maxGoals)
        let thisWeek = MindsetEngine.weeklyFocus(goals: MindsetStore.goals, weekStart: evening, calendar: calendar)
        let nextWeek = MindsetEngine.weeklyFocus(goals: MindsetStore.goals, weekStart: evening.addingTimeInterval(7 * 86_400), calendar: calendar)
        XCTAssertEqual(thisWeek.count, 3)
        XCTAssertNotEqual(thisWeek[1].text, thisWeek[2].text, "two goals in the same area get different focus points")
        XCTAssertNotEqual(thisWeek[0].text, nextWeek[0].text, "a new focus every week")
    }

    func testTheWeeksMindsetLevelCountsEverything() {
        MindsetStore.goals = [SeasonGoal(text: "Stay calm", area: .confidence)]
        MindsetStore.saveReflection(win: "w", lesson: "l", feeling: nil, on: evening, calendar: calendar)
        let goal = MindsetStore.goals[0]
        MindsetStore.setFocusDone(goal.id, true, week: evening, calendar: calendar)
        MindsetStore.logRoutine(.breathing, on: evening, calendar: calendar)
        let progress = MindsetStore.weekProgress(now: evening, calendar: calendar)
        XCTAssertEqual(progress.target, 5 + 1 + 1)
        XCTAssertEqual(progress.done, 3)
    }

    func testBreathingPhasesAndVisualizationLength() {
        XCTAssertEqual(BreathingPattern.calm.phase(at: 2).label, "Breathe in")
        XCTAssertEqual(BreathingPattern.calm.phase(at: 5).label, "Breathe out slowly")
        XCTAssertEqual(BreathingPattern.calm.phase(at: 10.5).label, "Breathe in", "the cycle repeats")
        XCTAssertEqual(BreathingPattern.focus.cycleSeconds, 16)
        let steps = GameDayVisualization.steps(sportName: "Soccer", cueWord: "Reset")
        XCTAssertLessThanOrEqual(steps.reduce(0) { $0 + $1.seconds }, 330, "about five minutes")
        XCTAssertTrue(steps.contains { $0.text.contains("\"Reset\"") }, "the athlete's own reset word is used")
    }
}

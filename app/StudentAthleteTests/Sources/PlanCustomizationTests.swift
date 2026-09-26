import XCTest

/// The athlete's own say over the plan: the week's shape, their version of
/// any workout, and their own workouts.
final class PlanCustomizationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PlanCustomizationTests")
        defaults.removePersistentDomain(forName: "PlanCustomizationTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "PlanCustomizationTests")
        super.tearDown()
    }

    /// Monday 2026-06-01.
    private var monday: Date { calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))! }
    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: monday)! }

    private func item(_ slug: String, sets: Int = 3) -> GeneratedPlannedItem {
        GeneratedPlannedItem(itemSlug: slug, order: 0, dose: Dose(kind: "reps", sets: sets, reps: 8), restSec: 60, rationale: "", quality: "")
    }

    private func week() -> GeneratedWeek {
        GeneratedWeek(phase: .offSeason, weekStart: monday, sessions: [
            GeneratedSession(date: day(0), title: "Speed session", focusQualities: [], estimatedMinutes: 30, items: [item("a-skip")], slot: 0),
            GeneratedSession(date: day(2), title: "Strength session", focusQualities: [], estimatedMinutes: 30, items: [item("split-squat")], slot: 1),
            GeneratedSession(date: day(4), title: "Power session", focusQualities: [], estimatedMinutes: 30, items: [item("box-jump")], slot: 2),
        ])
    }

    private var legDay: CustomWorkout {
        CustomWorkout(title: "My leg day", items: [
            CustomItem(itemSlug: "nordic-hamstring-curl", dose: Dose(kind: "reps", sets: 3, reps: 5), restSec: 90),
            CustomItem(itemSlug: "copenhagen-plank", dose: Dose(kind: "time", sets: 2, seconds: 20, perSide: true), restSec: 45),
        ])
    }

    func testMyVersionReplacesThatGymDayEveryWeekAndKeepsItsDay() {
        let custom = PlanCustomization(sessions: [PlanSlot.gym(1).key: legDay])
        let result = PlanCustomizer.apply(custom, to: week())
        XCTAssertEqual(result.sessions.map(\.title), ["Speed session", "My leg day", "Power session"])
        XCTAssertEqual(result.sessions[1].date, day(2), "same day as the one it replaces")
        XCTAssertEqual(result.sessions[1].slot, 1, "still day 2, so the next week's edit lands here too")
        XCTAssertEqual(result.sessions[1].items.map(\.itemSlug), ["nordic-hamstring-curl", "copenhagen-plank"])
        XCTAssertEqual(result.sessions[1].items.map(\.order), [0, 1])
    }

    func testChosenWeekdaysPlaceTheGymDays() {
        // Tuesday, Thursday and Saturday (Calendar weekdays 3, 5, 7).
        let placed = PlanCustomizer.place(week(), weekdays: [7, 3, 5], calendar: calendar)
        XCTAssertEqual(placed.sessions.map(\.date), [day(1), day(3), day(5)])
        XCTAssertEqual(placed.sessions.map(\.slot), [0, 1, 2])
    }

    func testFewerChosenDaysThanSessionsDropsTheRest() {
        let placed = PlanCustomizer.place(week(), weekdays: [2], calendar: calendar)
        XCTAssertEqual(placed.sessions.count, 1)
        XCTAssertEqual(placed.sessions[0].date, day(0))
    }

    func testChosenDaysSetHowManyGymDaysThereAre() {
        XCTAssertEqual(PlanSettings(weekdays: [2, 4, 6, 7]).effectiveSessionsPerWeek, 4)
        XCTAssertEqual(PlanSettings(sessionsPerWeek: 2).effectiveSessionsPerWeek, 2)
        XCTAssertNil(PlanSettings().effectiveSessionsPerWeek, "nil: what the season calls for")
    }

    func testTheGeneratorBuildsTheNumberOfGymDaysAsked() {
        let item = CatalogueItem(
            slug: "split-squat", name: "Split squat", kind: "exercise", qualities: ["lower-body-strength": 1], muscles: [:],
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF", setup: [], execution: [], cues: [],
            mistakes: [], progressions: [], regressions: [], substitutes: [], defaultDose: Dose(kind: "reps", sets: 3, reps: 8),
            restSeconds: 60, startPose: "lunge", endPose: "lunge", unilateralEligible: nil, tempoEligible: nil, prop: nil,
            variant: nil, baseSlug: nil, constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil,
            unilateralStabilityQuality: nil, itemSportSlug: nil
        )
        func input(_ count: Int?) -> PlanGeneratorInput {
            PlanGeneratorInput(
                sportProfile: ["lower-body-strength": 1], seasonStart: day(90), seasonEnd: day(180), weekStart: monday,
                birthDate: Date(timeIntervalSince1970: 0), catalogue: Catalogue(itemsBySlug: [item.slug: item]),
                seed: "s", now: monday, sessionsPerWeek: count
            )
        }
        XCTAssertEqual(PlanGenerator.generate(input(nil)).sessions.count, 3, "off-season default")
        let five = PlanGenerator.generate(input(5))
        XCTAssertEqual(five.sessions.map(\.slot), [0, 1, 2, 3, 4])
        XCTAssertEqual(Set(five.sessions.map(\.date)).count, 5, "five different days")
        XCTAssertEqual(PlanGenerator.generate(input(9)).sessions.count, 6, "never more than six")
    }

    func testEditsAreSavedAndUndone() {
        PlanCustomizationStore.setWorkout(legDay, for: .gym(0), defaults)
        PlanCustomizationStore.setWorkout(legDay, for: .mode(.mobility), defaults)
        XCTAssertEqual(PlanCustomizationStore.load(defaults).workout(for: .gym(0))?.title, "My leg day")
        XCTAssertNotNil(PlanCustomizationStore.load(defaults).workout(for: .mode(.mobility)))

        PlanCustomizationStore.setWorkout(nil, for: .gym(0), defaults)
        PlanCustomizationStore.setWorkout(nil, for: .mode(.mobility), defaults)
        XCTAssertTrue(PlanCustomizationStore.load(defaults).isEmpty)
        XCTAssertNil(defaults.object(forKey: "plans.custom"), "nothing left to back up")
    }

    func testTheWeekShapeIsSaved() {
        PlanCustomizationStore.setSettings(PlanSettings(weekdays: [2, 4], minutesPerSession: 45), defaults)
        let loaded = PlanCustomizationStore.load(defaults).settings
        XCTAssertEqual(loaded.weekdays, [2, 4])
        XCTAssertEqual(loaded.minutesPerSession, 45)
    }

    func testAPlannedWorkoutBecomesAnEditableCopyAndBack() {
        let session = week().sessions[1]
        let copy = CustomWorkout(session: session)
        XCTAssertEqual(copy.title, "Strength session")
        XCTAssertEqual(copy.items.map(\.itemSlug), ["split-squat"])
        let back = copy.session(date: day(3))
        XCTAssertEqual(back.date, day(3))
        XCTAssertEqual(back.items.first?.dose, session.items.first?.dose)
        XCTAssertGreaterThan(back.estimatedMinutes, 0)
    }

    func testMyWorkoutsNewestFirstAndDeletable() {
        let first = legDay
        var second = legDay
        second.id = UUID()
        second.title = "Upper body"
        MyWorkoutsStore.upsert(first, defaults)
        MyWorkoutsStore.upsert(second, defaults)
        XCTAssertEqual(MyWorkoutsStore.load(defaults).map(\.title), ["Upper body", "My leg day"])

        var renamed = first
        renamed.title = "Leg day 2"
        MyWorkoutsStore.upsert(renamed, defaults)
        XCTAssertEqual(MyWorkoutsStore.load(defaults).map(\.title), ["Leg day 2", "Upper body"], "an edit replaces, not duplicates")

        MyWorkoutsStore.delete(second.id, defaults)
        XCTAssertEqual(MyWorkoutsStore.load(defaults).map(\.title), ["Leg day 2"])
    }

    func testSharingWorkoutsIsPro() {
        XCTAssertFalse(ProFeature.shareWorkouts.isFreeForever)
        XCTAssertFalse(ProGate.isAvailable(.shareWorkouts, isPro: false))
        XCTAssertTrue(ProGate.isAvailable(.shareWorkouts, isPro: true))
    }
}

/// Codes as links: web links, direct app links and pasted links.
final class DeepLinkTests: XCTestCase {
    func testWebLinks() {
        XCTAssertEqual(DeepLink(url: URL(string: "https://api.lejacob.dev/fitness/team/ABC234")!), .team("ABC234"))
        XCTAssertEqual(DeepLink(url: URL(string: "https://api.lejacob.dev/fitness/workout/abc234")!), .workout("ABC234"))
        XCTAssertEqual(DeepLink(url: URL(string: "https://api.lejacob.dev/fitness/c/ABC234")!), .code("ABC234"))
        XCTAssertNil(DeepLink(url: URL(string: "https://example.com/fitness/team/ABC234")!), "only our domain")
        XCTAssertNil(DeepLink(url: URL(string: "https://api.lejacob.dev/other/team/ABC234")!))
    }

    func testDirectAppLinks() {
        XCTAssertEqual(DeepLink(url: URL(string: "aos://ABC234")!), .code("ABC234"))
        XCTAssertEqual(DeepLink(url: URL(string: "aos://team/ABC234")!), .team("ABC234"))
        XCTAssertEqual(DeepLink(url: URL(string: "athleteos://league/ABC234")!), .league("ABC234"))
        XCTAssertNil(DeepLink(url: URL(string: "aos://team/ABC0O1")!), "look-alike characters are never codes")
    }

    func testEveryLinkRoundTrips() {
        for link in [DeepLink.team("ABC234"), .league("ABC234"), .workout("ABC234"), .code("ABC234")] {
            XCTAssertEqual(DeepLink(url: link.webURL), link)
            XCTAssertEqual(DeepLink(url: link.appURL), link)
        }
        XCTAssertEqual(DeepLink.workout("ABC234").webURL.absoluteString, "https://api.lejacob.dev/fitness/workout/ABC234")
        XCTAssertEqual(DeepLink.code("ABC234").appURL.absoluteString, "aos://ABC234")
    }

    func testCodeFieldsTakeCodesAndPastedLinks() {
        XCTAssertEqual(DeepLink.code(fromInput: " abc-234 "), "ABC234")
        XCTAssertEqual(DeepLink.code(fromInput: "https://api.lejacob.dev/fitness/league/ABC234"), "ABC234")
        XCTAssertEqual(DeepLink.code(fromInput: "aos://workout/ABC234"), "ABC234")
        XCTAssertNil(DeepLink.code(fromInput: "hello"))
    }

    func testABareCodeResolvesToItsKind() {
        XCTAssertEqual(DeepLink.resolved(code: "ABC234", kind: "team"), .team("ABC234"))
        XCTAssertEqual(DeepLink.resolved(code: "ABC234", kind: "workout"), .workout("ABC234"))
        XCTAssertNil(DeepLink.resolved(code: "ABC234", kind: "something-new"))
    }
}

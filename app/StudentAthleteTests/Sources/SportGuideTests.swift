import XCTest

/// The sport knowledge library embedded from content/src/guides.
final class SportGuideTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SportGuideTests")
        defaults.removePersistentDomain(forName: "SportGuideTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SportGuideTests")
        super.tearDown()
    }

    func testEveryFeaturedSportHasAGuideThatDecodes() {
        let featured = allSports.filter { $0.featured == true }.map(\.slug)
        XCTAssertEqual(featured.count, 29)
        XCTAssertEqual(sportGuides.count, featured.count, "the embedded JSON must decode completely")
        for slug in featured {
            XCTAssertNotNil(SportGuide.forSport(slug), "\(slug) has no guide")
        }
    }

    func testGuidesAreComplete() {
        for guide in sportGuides {
            XCTAssertFalse(guide.headline.isEmpty, guide.slug)
            XCTAssertGreaterThanOrEqual(guide.demands.count, 3, guide.slug)
            XCTAssertGreaterThanOrEqual(guide.succeed.count, 3, guide.slug)
            XCTAssertGreaterThanOrEqual(guide.gym.exercises.count, 4, guide.slug)
            XCTAssertGreaterThanOrEqual(guide.injuries.count, 2, guide.slug)
            XCTAssertFalse(guide.sources.isEmpty, guide.slug)
            XCTAssertTrue(guide.sources.allSatisfy { $0.url.hasPrefix("https://") }, guide.slug)
        }
    }

    func testPositionTipsOnlyForTheSportsOwnPositions() {
        for guide in sportGuides {
            let positions = Set(allSportsBySlug[guide.slug]?.positions.map(\.slug) ?? [])
            XCTAssertEqual(Set(guide.positions.keys), positions, "\(guide.slug): one tip per position, no strangers")
        }
    }

    func testEveryQuizQuestionPlaysInCampus() {
        for guide in sportGuides {
            XCTAssertGreaterThanOrEqual(guide.quiz.count, 4, guide.slug)
            XCTAssertEqual(guide.quiz.compactMap(\.campusQuestion).count, guide.quiz.count, guide.slug)
        }
    }

    func testQuizAlternatesTeachingAndQuestions() throws {
        let guide = try XCTUnwrap(SportGuide.forSport("soccer"))
        let steps = guide.quizSteps
        XCTAssertEqual(steps.count, guide.succeed.count + guide.quiz.count)
        guard case .teach = steps[0], case .question = steps[1] else {
            return XCTFail("a teaching card first, then a question")
        }
    }

    func testSeasonAdviceFollowsThePhase() throws {
        let guide = try XCTUnwrap(SportGuide.forSport("football"))
        XCTAssertEqual(guide.seasonAdvice(for: .inSeason), guide.season.inSeason)
        XCTAssertEqual(guide.seasonAdvice(for: .preSeason), guide.season.pre)
        XCTAssertEqual(guide.seasonAdvice(for: .postSeason), guide.season.off, "after the season is the off-season")
    }

    func testPassingAQuizIsRememberedOnceAndEarnsTheBadge() {
        XCTAssertTrue(SportGuideProgress.markPassed("soccer", defaults: defaults))
        XCTAssertFalse(SportGuideProgress.markPassed("soccer", defaults: defaults), "the second pass isn't new")
        XCTAssertEqual(SportGuideProgress.passed(defaults), ["soccer"])
        XCTAssertEqual(CampusProgress.stats(defaults).guidesPassed, 1)
        XCTAssertTrue(CampusBadges.deserved(CampusProgress.stats(defaults)).contains("sport-guide"))
    }
}

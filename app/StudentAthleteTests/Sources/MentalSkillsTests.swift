import XCTest

/// Mental skills are optional (§17–20): "no thanks" hides one for two weeks
/// without penalty; a skill that keeps not helping is set aside.
final class MentalSkillsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "mindset.skillFeedback")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "mindset.skillFeedback")
        super.tearDown()
    }

    func testNoThanksHidesForTwoWeeks() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        MentalSkillFeedback.decline(.pressureLadder, now: now)
        XCTAssertTrue(MentalSkillFeedback.isDeclined(.pressureLadder, now: now.addingTimeInterval(86_400 * 3)))
        XCTAssertFalse(MentalSkillFeedback.isDeclined(.pressureLadder, now: now.addingTimeInterval(86_400 * 15)))
        XCTAssertFalse(MentalSkillFeedback.isDeclined(.selfTalk, now: now))
    }

    func testASkillThatKeepsNotHelpingIsSetAside() {
        MentalSkillFeedback.record(.focusCue, helped: false)
        XCTAssertFalse(MentalSkillFeedback.isRetired(.focusCue), "once isn't a pattern")
        MentalSkillFeedback.record(.focusCue, helped: false)
        XCTAssertTrue(MentalSkillFeedback.isRetired(.focusCue))
        MentalSkillFeedback.clear(.focusCue)
        XCTAssertFalse(MentalSkillFeedback.isRetired(.focusCue), "another try is always possible")
    }

    func testEveryScriptIsShortAndCitesKnownSources() {
        for skill in MentalSkill.allCases {
            XCTAssertLessThanOrEqual(skill.steps.count, 5, "\(skill.title) stays brief")
            for id in skill.basis { XCTAssertNotNil(EvidenceRegistry.source(id), "\(skill.title) cites \(id)") }
            XCTAssertFalse(skill.steps.joined().lowercased().contains("guarantee"))
        }
    }
}

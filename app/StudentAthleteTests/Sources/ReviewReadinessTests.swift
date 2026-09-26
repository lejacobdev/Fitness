import XCTest

/// Things App Review looks for: using the app without an account, and
/// blocking people in leagues (guidelines 5.1.1(v) and 1.2).
final class ReviewReadinessTests: XCTestCase {
    func testGuestsAreRecognisedAndSignedInAthletesAreNot() {
        let guest = Athlete(appleUserId: Athlete.guestPrefix + UUID().uuidString, birthDate: Date(timeIntervalSince1970: 1_100_000_000))
        let member = Athlete(appleUserId: "001234.abcdef.5678", birthDate: Date(timeIntervalSince1970: 1_100_000_000))
        XCTAssertTrue(guest.isGuest)
        XCTAssertFalse(member.isGuest)
    }

    func testBlockingHidesThatPlayerInThatLeagueOnly() {
        var raw = ""
        raw = LeagueBlocks.adding(league: "l1", nickname: "Mia", to: raw)
        raw = LeagueBlocks.adding(league: "l1", nickname: "Mia", to: raw)
        XCTAssertEqual(raw, "l1:Mia", "blocking twice keeps one entry")
        XCTAssertTrue(LeagueBlocks.isBlocked(league: "l1", nickname: "Mia", raw: raw))
        XCTAssertFalse(LeagueBlocks.isBlocked(league: "l2", nickname: "Mia", raw: raw), "only in the league it happened in")
        XCTAssertFalse(LeagueBlocks.isBlocked(league: "l1", nickname: "Jo", raw: raw))
    }
}

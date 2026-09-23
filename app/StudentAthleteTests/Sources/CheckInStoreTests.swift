import SwiftData
import XCTest

/// `CheckInStore` is `@MainActor` — see SessionLoggerTests' own doc comment
/// for why the whole case needs the same isolation, not just the async tests.
@MainActor
final class CheckInStoreTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    func testFirstCheckInOfTheDayInsertsANewRow() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-1", birthDate: .now)
        context.insert(athlete)

        let checkIn = try CheckInStore(modelContext: context).submit(
            athlete: athlete, sleepQuality: 4, soreness: 2, energy: 4, stress: 2
        )

        XCTAssertEqual(athlete.checkIns.count, 1)
        XCTAssertEqual(checkIn.sleepQuality, 4)
        // Fewer than 7 days of history exist yet, so §11 says: no band.
        XCTAssertNil(checkIn.readinessBand)
    }

    /// §14: "`CheckIn` is unique per athlete per day, so a second check-in
    /// edits the first rather than creating a duplicate day that would
    /// corrupt every rolling baseline."
    func testASecondCheckInTheSameDayEditsTheFirstInsteadOfDuplicating() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-2", birthDate: .now)
        context.insert(athlete)
        let store = CheckInStore(modelContext: context)

        let first = try store.submit(athlete: athlete, sleepQuality: 3, soreness: 3, energy: 3, stress: 3)
        let second = try store.submit(athlete: athlete, sleepQuality: 5, soreness: 1, energy: 5, stress: 1)

        XCTAssertEqual(athlete.checkIns.count, 1, "same day must edit, never duplicate")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(athlete.checkIns.first?.sleepQuality, 5)
    }

    func testCheckInsOnDifferentDaysAreSeparateRows() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-3", birthDate: .now)
        context.insert(athlete)
        let store = CheckInStore(modelContext: context)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!

        try store.submit(athlete: athlete, sleepQuality: 3, soreness: 3, energy: 3, stress: 3, now: yesterday)
        try store.submit(athlete: athlete, sleepQuality: 4, soreness: 2, energy: 4, stress: 2, now: .now)

        XCTAssertEqual(athlete.checkIns.count, 2)
    }

    func testASeventhConsecutiveDayProducesAReadinessBand() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-4", birthDate: .now)
        context.insert(athlete)
        let store = CheckInStore(modelContext: context)
        let calendar = Calendar.current

        for daysAgo in stride(from: 7, through: 1, by: -1) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
            try store.submit(athlete: athlete, sleepQuality: 4, soreness: 2, energy: 4, stress: 2, now: date)
        }
        XCTAssertEqual(athlete.checkIns.count, 7)

        let today = try store.submit(athlete: athlete, sleepQuality: 4, soreness: 2, energy: 4, stress: 2)
        XCTAssertEqual(today.readinessBand, .green, "matches the 7-day baseline exactly")
    }
}

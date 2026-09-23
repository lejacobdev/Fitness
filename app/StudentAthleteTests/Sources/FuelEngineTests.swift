import SwiftData
import XCTest

final class FuelEngineTests: XCTestCase {
    private let calendar = Calendar.current
    private let reference = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference)!
    }

    // MARK: - §13's hard rules, as a lint over every string

    func testNoFuelGuidanceUsesDietOrBodyLanguage() {
        for sentence in FuelEngine.allGuidanceStrings {
            let lower = sentence.lowercased()
            for banned in FuelEngine.bannedWords {
                XCTAssertFalse(lower.contains(banned), "\"\(sentence)\" contains \"\(banned)\"")
            }
            for word in ["fat", "skinny", "thin", "lose", "cut"] {
                let words = Set(lower.components(separatedBy: CharacterSet.letters.inverted))
                XCTAssertFalse(words.contains(word), "\"\(sentence)\" contains \"\(word)\"")
            }
        }
    }

    func testTheStandingDietitianLineIsAlwaysPresent() {
        XCTAssertTrue(FuelEngine.standingNote.contains("dietitian"))
        XCTAssertTrue(FuelEngine.allGuidanceStrings.contains(FuelEngine.standingNote))
    }

    // MARK: - Hydration and plate

    func testHydrationRisesWithTrainingAndIsCapped() {
        XCTAssertEqual(FuelEngine.hydrationTarget(trainingMinutes: 0), FuelEngine.baseGlasses)
        XCTAssertEqual(FuelEngine.hydrationTarget(trainingMinutes: 60), FuelEngine.baseGlasses + 2)
        XCTAssertEqual(FuelEngine.hydrationTarget(trainingMinutes: 45), FuelEngine.baseGlasses + 2, "partial half-hours round up")
        XCTAssertEqual(FuelEngine.hydrationTarget(trainingMinutes: 60, isHot: true), FuelEngine.baseGlasses + 4)
        XCTAssertEqual(FuelEngine.hydrationTarget(trainingMinutes: 600, isHot: true), FuelEngine.maxGlasses)
    }

    func testPlateTargetsNeverDropBelowARestDayAndGrowWithTraining() {
        let rest = FuelEngine.plateTargets(trainingMinutes: 0, isGameDay: false)
        let training = FuelEngine.plateTargets(trainingMinutes: 45, isGameDay: false)
        let game = FuelEngine.plateTargets(trainingMinutes: 0, isGameDay: true)
        XCTAssertLessThan(rest.carbs, training.carbs)
        XCTAssertLessThan(training.carbs, game.carbs)
        XCTAssertEqual(rest.protein, training.protein)
    }

    // MARK: - Timing

    func testAnAfternoonSessionGetsAMealTwoToThreeHoursBeforeAndRecoveryAfter() {
        let start = at(16)
        let tips = FuelEngine.sessionTimeline(start: start, minutes: 60)
        let meal = tips.first { $0.id == "pre-meal" }
        XCTAssertNotNil(meal)
        let lead = start.timeIntervalSince(meal!.time!) / 3600
        XCTAssertTrue((2.0...3.0).contains(lead))
        let recovery = tips.first { $0.id == "post-recovery" }!
        XCTAssertGreaterThan(recovery.time!, start.addingTimeInterval(60 * 60))
    }

    func testAnEarlyMorningSessionGetsALightSnackNotAFullMeal() {
        let tips = FuelEngine.sessionTimeline(start: at(6, 30), minutes: 45)
        XCTAssertTrue(tips.contains { $0.id == "pre-early" })
        XCTAssertFalse(tips.contains { $0.id == "pre-meal" })
    }

    func testLongSessionsAddCarbsDuring() {
        let long = FuelEngine.sessionTimeline(start: at(16), minutes: 90).first { $0.id == "during-water" }!
        let short = FuelEngine.sessionTimeline(start: at(16), minutes: 40).first { $0.id == "during-water" }!
        XCTAssertTrue(long.detail.contains("carb"))
        XCTAssertFalse(short.detail.contains("carb"))
    }

    func testNoTrainingMeansNoSessionTimeline() {
        XCTAssertTrue(FuelEngine.sessionTimeline(start: at(16), minutes: 0).isEmpty)
    }

    /// §13: "what to eat 3 hours out, 1 hour out, and between games in a tournament."
    func testGameDayHasThreeHourAndOneHourMarksAndTournamentsAddBetweenGames() {
        let kickoff = at(17)
        let game = FuelEngine.gameDayTimeline(gameStart: kickoff, isTournament: false)
        XCTAssertEqual(game.first { $0.id == "game-3h" }?.time, kickoff.addingTimeInterval(-3 * 3600))
        XCTAssertEqual(game.first { $0.id == "game-1h" }?.time, kickoff.addingTimeInterval(-3600))
        XCTAssertFalse(game.contains { $0.id == "game-between" })
        XCTAssertTrue(FuelEngine.gameDayTimeline(gameStart: kickoff, isTournament: true).contains { $0.id == "game-between" })
    }

    // MARK: - Sleep (§17: sum asleep stages, merge overlapping sources)

    func testOverlappingPhoneAndWatchSamplesAreNotDoubleCounted() {
        let intervals: [(start: Date, end: Date)] = [
            (at(22), at(23, 30)),
            (at(23), at(23, 59)),      // overlaps the first
            (at(23, 59), at(23, 59)),  // zero-length, ignored
        ]
        XCTAssertEqual(SleepMath.asleepHours(intervals), 2 - 1.0 / 60, accuracy: 0.001)
    }

    func testSeparateBlocksAddUp() {
        let intervals: [(start: Date, end: Date)] = [(at(1), at(3)), (at(4), at(7))]
        XCTAssertEqual(SleepMath.asleepHours(intervals), 5, accuracy: 0.001)
        XCTAssertEqual(SleepMath.label(7 + 40.0 / 60), "7h 40m")
    }
}

@MainActor
final class MealStoreTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    func testMealsAreStoredWithPortionsClampedToThree() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-meal", birthDate: .now)
        context.insert(athlete)
        let meal = try MealStore(modelContext: context).logMeal(athlete: athlete, slot: .lunch, protein: 5, carbs: 2, colour: -1, note: "  ")
        XCTAssertEqual(meal.proteinPortions, 3)
        XCTAssertEqual(meal.colourPortions, 0)
        XCTAssertNil(meal.note, "blank notes are not stored")
        XCTAssertEqual(MealStore.meals(of: athlete, on: .now).count, 1)
    }

    func testWaterIsOneRowPerDayAndNeverNegative() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-water", birthDate: .now)
        context.insert(athlete)
        let store = MealStore(modelContext: context)
        try store.addWater(athlete: athlete, glasses: 1)
        try store.addWater(athlete: athlete, glasses: 1)
        XCTAssertEqual(try store.addWater(athlete: athlete, glasses: -5), 0)
        XCTAssertEqual(athlete.mealLogs.filter { $0.slot == MealSlot.water }.count, 1)
        XCTAssertTrue(MealStore.meals(of: athlete, on: .now).isEmpty, "water isn't a meal")
    }

    func testDeletingTheAthleteCascadesToMeals() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-cascade", birthDate: .now)
        context.insert(athlete)
        try MealStore(modelContext: context).logMeal(athlete: athlete, slot: .dinner, protein: 1, carbs: 1, colour: 1)
        context.delete(athlete)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealLog>()), 0)
    }
}

import XCTest
#if canImport(Engine)
@testable import Engine
#endif

/// The V6 workout engine against the real content packs (docs/VERSION-6.md
/// §4–§9, §24): the rules a coach would check, written as assertions.
final class WorkoutEngineTests: XCTestCase {
    private static let catalogue: Catalogue = {
        let dist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "content/dist")
        // Local runs from a linked copy of this file: the repo checkout.
        let fallback = URL(fileURLWithPath: ProcessInfo.processInfo.environment["AOS_CONTENT_DIST"] ?? "/root/fitness/content/dist")
        return CatalogueLoader.load(from: FileManager.default.fileExists(atPath: dist.path) ? dist : fallback)
    }()

    private let fullGym: Set<String> = ["dumbbell", "barbell", "rack", "bench", "pull-up-bar", "band", "box", "med-ball", "wall", "cones",
                                        "kettlebell", "weight-plate", "trap-bar", "low-bar", "step", "mini-band", "slider", "cable-machine",
                                        "lat-pulldown", "foam-roller", "jump-rope", "bumper-plates", "landmine", "hurdle", "ball", "stick", "partner"]
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func day(_ sport: String, position: String? = nil, phase: SeasonPhase, age: Int = 16, experience: TrainingExperience = .intermediate,
                     practice: PracticeIntensity? = nil, nextGame: Int? = nil, lastGame: Int? = nil, readiness: ReadinessLevel = .normal,
                     gymDay: Bool = true, recent: RecentLoad = RecentLoad(), goals: [Capacity] = []) -> TrainingDay {
        TrainingDay(date: date, phase: phase, age: age, experience: experience,
                    demands: SportDemandsTable.demands(sport: Self.catalogue.sportsBySlug[sport], position: position),
                    goals: goals, practice: practice, daysToNextGame: nextGame, daysSinceLastGame: lastGame, readiness: readiness,
                    recent: recent, plannedGymDay: gymDay)
    }

    private func build(_ day: TrainingDay, sport: String, position: String? = nil, requested: SessionType? = nil,
                       equipment: Set<String>? = nil) -> (SessionDecision, GeneratedSession) {
        let decision = SessionPlanner.decide(day, requested: requested)
        let kit = AthleteKit(catalogue: Self.catalogue, sport: Self.catalogue.sportsBySlug[sport], positionSlug: position,
                             equipment: equipment ?? fullGym, seed: "test")
        return (decision, SessionBuilder.build(decision, day: day, kit: kit))
    }

    private func profile(_ item: GeneratedPlannedItem) -> ExerciseProfile? { Self.catalogue.item(item.itemSlug)?.planProfile }

    private func mainWork(_ session: GeneratedSession) -> [GeneratedPlannedItem] {
        session.items.filter { ![.prep, .mobility, .cooldown].contains($0.block) }
    }

    func testThePacksCarryExerciseProfiles() {
        XCTAssertGreaterThan(Self.catalogue.itemsBySlug.count, 500)
        XCTAssertTrue(Self.catalogue.itemsBySlug.values.allSatisfy { $0.profile != nil }, "every item ships a V6 profile")
    }

    // §6 + §8: after practice — short, upper body and trunk, nothing that tires the legs again.
    func testAfterPracticeInAFieldSportAddsNoLegFatigueOrConditioning() {
        let (decision, session) = build(day("soccer", position: "midfielder", phase: .inSeason, practice: .normal, nextGame: 3), sport: "soccer", position: "midfielder")
        XCTAssertEqual(decision.sessionType, .afterPractice)
        XCTAssertTrue((15...35).contains(decision.durationTarget))
        XCTAssertTrue(decision.avoidToday.contains(.hardConditioning))
        XCTAssertNil(decision.conditioning)
        for item in mainWork(session) {
            XCTAssertLessThan(profile(item)?.legLoad ?? 0, 2, "\(item.itemSlug) loads tired legs")
        }
        XCTAssertTrue(decision.primaryTargets.contains(.upperStrength))
        XCTAssertLessThanOrEqual(mainWork(session).count, 7, "quality over exercise count (§7)")
    }

    // §8's example: hard practice today, game tomorrow, tired legs → upper body + trunk.
    func testHardPracticeBeforeAGameMeansNoHeavyLowerBody() {
        let (decision, session) = build(day("basketball", phase: .inSeason, practice: .hard, nextGame: 1), sport: "basketball")
        XCTAssertEqual(decision.legBudget, 0)
        XCTAssertTrue(decision.avoidToday.contains(.heavyLowerBody))
        XCTAssertTrue(decision.reasons.contains(.hardTeamPractice))
        XCTAssertTrue(decision.reasons.contains(.gameTomorrow))
        XCTAssertFalse(session.items.contains { ($0.block == .primaryStrength || $0.block == .secondaryStrength) && (profile($0)?.isLower ?? false) })
    }

    // §6: a development day is a real session — 45–75 minutes, built in blocks.
    func testAnOffSeasonDevelopmentDayHasRealStructureAndLength() {
        let (decision, session) = build(day("basketball", position: "guard", phase: .offSeason), sport: "basketball", position: "guard")
        XCTAssertEqual(decision.sessionType, .gymDevelopment)
        XCTAssertTrue((45...75).contains(decision.durationTarget))
        XCTAssertGreaterThanOrEqual(session.estimatedMinutes, decision.durationTarget - 15)
        XCTAssertLessThanOrEqual(session.estimatedMinutes, decision.durationTarget + 8)
        let blocks = session.items.compactMap(\.block)
        XCTAssertEqual(blocks.first, .prep)
        XCTAssertTrue(blocks.contains(.primaryStrength))
        // Fast and explosive work before strength, conditioning last (§10 ordering).
        if let power = blocks.lastIndex(of: .power), let strength = blocks.firstIndex(of: .primaryStrength) { XCTAssertLessThan(power, strength) }
        if let conditioning = blocks.firstIndex(of: .conditioning), let strength = blocks.lastIndex(of: .primaryStrength) { XCTAssertGreaterThan(conditioning, strength) }
        let main = session.items.filter { $0.block == .primaryStrength }.compactMap(profile)
        XCTAssertTrue(main.contains { $0.isLower }, "a lower-body main lift")
        XCTAssertTrue(main.contains { $0.isUpper && !$0.isLower }, "an upper-body main lift")
        XCTAssertLessThanOrEqual(mainWork(session).count, 10)
    }

    // §5: cardio is programmed from what the sport already gives.
    func testCrossCountryGetsNoExtraRunning() {
        let recent = RecentLoad(days: (1...5).map { DayLoad(daysAgo: $0, practice: .normal) })
        let rest = SessionPlanner.decide(day("cross-country", phase: .inSeason, gymDay: false, recent: recent))
        XCTAssertEqual(rest.sessionType, .rest)
        let gym = SessionPlanner.decide(day("cross-country", phase: .inSeason, recent: recent))
        XCTAssertEqual(gym.conditioningMinutes, 0)
        XCTAssertNil(gym.conditioning)
    }

    func testGolfGetsProgrammedAerobicWork() {
        let decision = SessionPlanner.decide(day("golf", phase: .offSeason, gymDay: false))
        XCTAssertEqual(decision.sessionType, .conditioning)
        XCTAssertEqual(decision.conditioning, .aerobicBase)
        XCTAssertGreaterThanOrEqual(decision.conditioningMinutes, 20)
    }

    func testTheDayBeforeAGameIsAShortPrimer() {
        let (decision, session) = build(day("lacrosse", position: "midfield", phase: .inSeason, nextGame: 1), sport: "lacrosse", position: "midfield")
        XCTAssertEqual(decision.sessionType, .primer)
        XCTAssertLessThanOrEqual(decision.durationTarget, 30)
        XCTAssertNil(decision.conditioning)
        XCTAssertFalse(session.items.contains { (profile($0)?.isLower ?? false) && (profile($0)?.fatigue ?? 0) >= 4 })
    }

    func testTheDayAfterAGameIsRecovery() {
        XCTAssertEqual(SessionPlanner.decide(day("basketball", phase: .inSeason, lastGame: 1)).sessionType, .recovery)
    }

    func testALowCheckInTurnsAGymDayIntoRecovery() {
        let decision = SessionPlanner.decide(day("tennis", phase: .offSeason, readiness: .low))
        XCTAssertEqual(decision.sessionType, .recovery)
        XCTAssertTrue(decision.reasons.contains(.lowReadiness))
    }

    // Lower-body patterns alternate through the week.
    func testMainLowerPatternAlternates() {
        let afterSquat = RecentLoad(days: [DayLoad(daysAgo: 2, lowerPattern: "squat", upperPattern: "push", sessionType: .gymDevelopment)])
        let decision = SessionPlanner.decide(day("soccer", phase: .offSeason, recent: afterSquat))
        XCTAssertEqual(decision.lowerPattern, "hinge")
        XCTAssertEqual(decision.upperPattern, "pull")
    }

    // §2 youth envelope: under-18s never get more than 3 sets of a rep exercise.
    func testYouthEnvelopeHolds() {
        for experience in TrainingExperience.allCases {
            let (_, session) = build(day("football", position: "lineman", phase: .offSeason, age: 16, experience: experience), sport: "football", position: "lineman")
            for item in session.items where item.dose.kind == "reps" {
                XCTAssertLessThanOrEqual(item.dose.sets, 3, "\(item.itemSlug) for a 16-year-old (\(experience))")
            }
        }
    }

    func testTheSameDayAlwaysGivesTheSameSession() {
        let a = build(day("volleyball", phase: .preSeason), sport: "volleyball").1
        let b = build(day("volleyball", phase: .preSeason), sport: "volleyball").1
        XCTAssertEqual(a.items.map(\.itemSlug), b.items.map(\.itemSlug))
    }

    // §22: calm, precise copy — never advertising language.
    func testExplanationsSoundLikeACoach() {
        let banned = ["unlock", "crush", "unstoppable", "push past", "beast", "no excuses"]
        let days = [day("soccer", phase: .inSeason, practice: .hard, nextGame: 1), day("golf", phase: .offSeason, gymDay: false),
                    day("basketball", phase: .offSeason), day("tennis", phase: .offSeason, readiness: .low)]
        for d in days {
            let session = build(d, sport: "soccer").1
            let text = ([session.explanation?.summary ?? ""] + (session.explanation?.parts.map(\.answer) ?? [])).joined(separator: " ").lowercased()
            XCTAssertFalse(session.explanation?.summary.isEmpty ?? true)
            for phrase in banned { XCTAssertFalse(text.contains(phrase), "“\(phrase)” in: \(text)") }
        }
    }

    // §21: rest is correct execution, not a missed day.
    func testRestIsAPlanNotAFailure() {
        let decision = SessionPlanner.decide(day("cross-country", phase: .inSeason, gymDay: false,
                                                 recent: RecentLoad(days: (1...5).map { DayLoad(daysAgo: $0, practice: .normal) })))
        XCTAssertEqual(decision.sessionType, .rest)
        XCTAssertEqual(decision.durationTarget, 0)
        let text = PlanExplanation.make(decision: decision, day: day("cross-country", phase: .inSeason, gymDay: false), items: [],
                                        catalogue: Self.catalogue, conditioning: nil).summary
        XCTAssertTrue(text.contains("part of the plan"))
    }

    // §23: a conditioning goal adds programmed work, but never to a sport that is itself the conditioning.
    func testAnAerobicGoalAddsConditioning() {
        let practices = RecentLoad(days: (1...4).map { DayLoad(daysAgo: $0, practice: .normal) })
        let without = SessionPlanner.conditioningRemaining(day("basketball", phase: .inSeason, recent: practices))
        let with = SessionPlanner.conditioningRemaining(day("basketball", phase: .inSeason, recent: practices, goals: [.aerobic]))
        XCTAssertGreaterThan(with, without)
        XCTAssertEqual(SessionPlanner.conditioningRemaining(day("cross-country", phase: .inSeason, recent: practices, goals: [.aerobic])), 0)
    }

    func testWeekPlannerKeepsGymDaysOffGameEves() {
        // Mon practice, Tue free, Wed practice, Thu free, Fri game eve, Sat game, Sun free.
        let week: [(practice: Bool, game: Bool)] = [(true, false), (false, false), (true, false), (false, false), (false, false), (false, true), (false, false)]
        let days = WeekPlanner.gymDays(days: week, count: 2)
        XCTAssertEqual(days.count, 2)
        XCTAssertFalse(days.contains(4), "never the day before a game")
        XCTAssertFalse(days.contains(5), "never on a game day")
    }
}

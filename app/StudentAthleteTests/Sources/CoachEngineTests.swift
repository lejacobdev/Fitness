import XCTest

final class CoachEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: now)!
    }

    private func item(_ slug: String, muscles: [String: Double], qualities: [String: Double] = ["lower-body-strength": 1.0]) -> CatalogueItem {
        CatalogueItem(
            slug: slug, name: slug.capitalized, kind: "exercise", qualities: qualities, muscles: muscles,
            equipment: [], surface: "anywhere", minAge: 13, supervisionLevel: "SELF",
            setup: [], execution: [], cues: [], mistakes: [], progressions: [], regressions: [], substitutes: [],
            defaultDose: Dose(kind: "reps", sets: 3, reps: 8), restSeconds: 60, startPose: "hinge", endPose: "hinge",
            unilateralEligible: nil, tempoEligible: nil, prop: nil, variant: nil, baseSlug: nil,
            constraintAxes: nil, equipmentChain: nil, unilateralPosePattern: nil, unilateralStabilityQuality: nil,
            itemSportSlug: nil
        )
    }

    private var catalogue: Catalogue {
        let items = [
            item("curl", muscles: ["biceps-brachii": 1.0, "brachialis": 0.5], qualities: ["upper-body-pull": 1.0]),
            item("squat", muscles: ["rectus-femoris": 1.0]),
        ]
        return Catalogue(itemsBySlug: Dictionary(uniqueKeysWithValues: items.map { ($0.slug, $0) }))
    }

    private func input(sessions: [CoachSession], checkIns: [CheckInAnswers] = [], previous: [String: Int] = [:]) -> CoachInput {
        CoachInput(
            athleteId: "athlete-1", now: now, positionName: "Forward",
            sportQualityProfile: ["lower-body-strength": 0.9], sessions: sessions, checkIns: checkIns,
            plannedSessionsLastWeek: 0, catalogue: catalogue, previousTemplateIndexes: previous
        )
    }

    // MARK: - The template bank (§12: completeness; §11/§13: the language lint)

    func testEveryFindingPoolHasFourToSixSentences() {
        for (code, tiers) in CoachTemplates.bank {
            XCTAssertFalse(tiers.isEmpty, code)
            for (tier, pool) in tiers.enumerated() {
                XCTAssertTrue((4...6).contains(pool.count), "\(code) tier \(tier) has \(pool.count) sentences")
            }
        }
        for (mood, pool) in CoachTemplates.encouragement {
            XCTAssertTrue((4...6).contains(pool.count), "encouragement \(mood) has \(pool.count)")
        }
    }

    /// §11: "no template may contain the words injury, risk, damage or
    /// safe/unsafe" — and §13: nothing about weight loss, body shape or
    /// appearance. Checked as whole words so "nothing" doesn't trip "thin".
    func testNoTemplateUsesForbiddenLanguage() {
        let all = CoachTemplates.bank.values.flatMap { $0.flatMap { $0 } } + CoachTemplates.encouragement.values.flatMap { $0 }
        for sentence in all {
            let lower = sentence.lowercased()
            let words = Set(lower.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
            for banned in CoachTemplates.bannedWords {
                if banned.contains(" ") || banned.contains("-") {
                    XCTAssertFalse(lower.contains(banned), "\"\(sentence)\" contains \"\(banned)\"")
                } else if banned == "diagnos" {
                    XCTAssertFalse(words.contains { $0.hasPrefix("diagnos") }, "\"\(sentence)\" diagnoses")
                } else {
                    XCTAssertFalse(words.contains(banned), "\"\(sentence)\" contains \"\(banned)\"")
                }
            }
        }
    }

    func testEveryTemplateRendersWithNoUnfilledSlots() {
        let slots = ["dominant": "arms", "neglected": "legs", "weeks": "3", "quality": "acceleration", "position": "forward",
                     "percent": "40", "done": "2", "planned": "3", "exercise": "Squat", "weight": "60 kg", "days": "5"]
        for (code, tiers) in CoachTemplates.bank {
            for pool in tiers {
                for template in pool {
                    let rendered = CoachTemplates.render(template, slots: slots)
                    XCTAssertFalse(rendered.contains("{"), "\(code): \(rendered)")
                    XCTAssertEqual(rendered.first.map { String($0) }, rendered.first.map { String($0).uppercased() }, "\(code) must start capitalised")
                }
            }
        }
    }

    // MARK: - Findings

    func testWithNoDataTheCoachSaysHowToGetStarted() {
        let report = CoachEngine.report(input(sessions: []))
        XCTAssertEqual(report.headlineCode, "getting-started")
        XCTAssertFalse(report.headline.isEmpty)
    }

    /// The original app idea, verbatim: "you've only trained arms lately —
    /// try core or legs."
    func testArmsOnlyTrainingProducesANeglectedRegionHeadlineWithLegRecommendations() {
        let armSessions = (1...4).map { offset in
            CoachSession(date: day(-offset), minutes: 30, rpe: 6, sets: Array(repeating: CoachSet(itemSlug: "curl", reps: 10, weightKg: 12), count: 4))
        }
        let report = CoachEngine.report(input(sessions: armSessions))

        XCTAssertEqual(report.muscleBalance[.arm] ?? 0, 1, accuracy: 0.0001, "all logged volume was arms")
        let allLines = ([report.headline] + report.observations).joined(separator: " ")
        XCTAssertTrue(allLines.contains("arm"), allLines)
        XCTAssertTrue(report.recommendations.contains { $0.itemSlug == "squat" }, "should point at something that trains the skipped legs")
        XCTAssertFalse(report.recommendations.contains { $0.itemSlug == "curl" })
    }

    func testAPersonalBestIsCelebrated() {
        let sessions = [
            CoachSession(date: day(-20), minutes: 40, rpe: 7, sets: [CoachSet(itemSlug: "squat", reps: 5, weightKg: 60)]),
            CoachSession(date: day(-2), minutes: 40, rpe: 7, sets: [CoachSet(itemSlug: "squat", reps: 5, weightKg: 70)]),
        ]
        let report = CoachEngine.report(input(sessions: sessions))
        let allLines = ([report.headline] + report.observations).joined(separator: " ")
        XCTAssertTrue(allLines.contains("70 kg"), allLines)
    }

    func testLowSleepAllWeekIsRaised() {
        let checkIns = (1...5).map { CheckInAnswers(date: day(-$0), sleepQuality: 1, soreness: 3, energy: 3, stress: 3) }
        let sessions = [CoachSession(date: day(-1), minutes: 30, rpe: 5, sets: [CoachSet(itemSlug: "squat", reps: 8)])]
        let report = CoachEngine.report(input(sessions: sessions, checkIns: checkIns))
        let codesMentionSleep = ([report.headline] + report.observations).contains { $0.lowercased().contains("sleep") }
        XCTAssertTrue(codesMentionSleep)
    }

    // MARK: - Reproducibility (§12)

    func testTheSameWeekProducesTheSameReport() {
        let sessions = [CoachSession(date: day(-1), minutes: 30, rpe: 5, sets: [CoachSet(itemSlug: "curl", reps: 8)])]
        XCTAssertEqual(CoachEngine.report(input(sessions: sessions)), CoachEngine.report(input(sessions: sessions)))
    }

    func testLastWeeksTemplateIndexIsNeverRepeated() {
        for seed in ["a", "b", "c", "d", "e", "f"] {
            let fresh = CoachEngine.templateIndex(poolSize: 4, seed: seed, avoiding: nil)
            let avoiding = CoachEngine.templateIndex(poolSize: 4, seed: seed, avoiding: fresh)
            XCTAssertNotEqual(fresh, avoiding)
        }
    }
}

final class LoadCalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: now)!
    }

    func testLoadIsRPETimesMinutesAndAMissingRPECountsAsFive() {
        XCTAssertEqual(LoadSample(date: now, minutes: 40, rpe: 7).load, 280)
        XCTAssertEqual(LoadSample(date: now, minutes: 40, rpe: nil).load, 200)
    }

    func testNoComparisonUntilThreeWeeksOfHistory() {
        let samples = (0..<10).map { LoadSample(date: day(-$0), minutes: 30, rpe: 5) }
        let summary = LoadCalculator.summarize(samples, now: now)
        XCTAssertNil(summary.change)
        XCTAssertNil(summary.message)
    }

    func testASteadyMonthIsInLineAndNotFlagged() {
        let samples = stride(from: 0, to: 28, by: 2).map { LoadSample(date: day(-$0), minutes: 40, rpe: 6) }
        let summary = LoadCalculator.summarize(samples, now: now)
        XCTAssertNotNil(summary.change)
        XCTAssertFalse(summary.isSharpJump)
    }

    func testABigWeekOnAQuietMonthIsFlaggedWithLoadLanguageNeverInjuryLanguage() {
        var samples = stride(from: 8, to: 28, by: 3).map { LoadSample(date: day(-$0), minutes: 30, rpe: 4) }
        samples += (0..<6).map { LoadSample(date: day(-$0), minutes: 90, rpe: 8) }
        let summary = LoadCalculator.summarize(samples, now: now)
        XCTAssertTrue(summary.isSharpJump)
        let message = summary.message?.lowercased() ?? ""
        XCTAssertTrue(message.contains("training load is up"))
        XCTAssertFalse(message.contains("injur"))
        XCTAssertFalse(message.contains("risk"))
    }

    func testDailySeriesCoversTheWholeWindowOldestFirst() {
        let summary = LoadCalculator.summarize([LoadSample(date: now, minutes: 10, rpe: 10)], now: now)
        XCTAssertEqual(summary.daily.count, 28)
        XCTAssertEqual(summary.daily.last?.load, 100)
        XCTAssertEqual(summary.acute, 100)
    }
}

@MainActor
final class AthleteStatsTests: XCTestCase {
    func testStreakCountsConsecutiveDaysAndSurvivesTodayNotYetDone() {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let days = (1...4).map { calendar.date(byAdding: .day, value: -$0, to: now)! }
        XCTAssertEqual(AthleteStats.streak(checkInDates: days, sessionDates: [], now: now), 4)
        XCTAssertEqual(AthleteStats.streak(checkInDates: [now] + days, sessionDates: [], now: now), 5)
        XCTAssertEqual(AthleteStats.streak(checkInDates: [calendar.date(byAdding: .day, value: -3, to: now)!], sessionDates: [], now: now), 0)
    }
}

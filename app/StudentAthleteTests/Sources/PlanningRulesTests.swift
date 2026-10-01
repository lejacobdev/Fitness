import XCTest

/// The Backend Knowledge System's required scenarios (§30) that the
/// on-phone rules can answer, plus the kill switch and the decision record.
final class PlanningRulesTests: XCTestCase {
    private func context(_ change: (inout PlanningContext) -> Void) -> PlanningContext {
        var context = PlanningContext()
        context.checkedInToday = true
        change(&context)
        return context
    }

    func testAHeadInjuryHoldsEverythingAndCantBeSwitchedOff() {
        // Feels fine, checked in, would like to train: the safety route persists.
        let paused = context { $0.trainingPausedAfterHeadInjury = true }
        XCTAssertEqual(PlanningRules.evaluate(paused).decision, .holdForProfessionalReview)
        XCTAssertEqual(PlanningRules.evaluate(paused, disabled: ["SAFE-CONCUSSION-01"]).decision, .holdForProfessionalReview,
                       "the server can never switch a safety rule off")
        XCTAssertFalse(PlanningRules.evaluate(paused).decision.allowsAddedTraining)
    }

    func testHardPracticeAndAGameTomorrowMeansNoAddedWorkout() {
        // Case A: 90 minutes of practice at high effort, game tomorrow.
        let caseA = context { $0.practiceToday = true; $0.practiceEffort = 5; $0.practiceMinutes = 90; $0.competitionTomorrow = true }
        let result = PlanningRules.evaluate(caseA)
        XCTAssertEqual(result.decision, .noExtraTraining)
        XCTAssertTrue(result.reasonCodes.contains("RECENT_DEMANDING_PRACTICE_COMPETITION_NEAR"))
        XCTAssertFalse(result.explanation?.lowercased().contains("will get injured") == true, "a schedule decision, not an injury prediction")
        // The kill switch can switch this heuristic off.
        XCTAssertEqual(PlanningRules.evaluate(caseA, disabled: ["SCHED-CONGESTION-05"]).decision, .planAsReviewed)
        // An easy logged practice with a game tomorrow doesn't trigger it.
        let easy = context { $0.practiceToday = true; $0.practiceEffort = 2; $0.practiceMinutes = 45; $0.competitionTomorrow = true }
        XCTAssertEqual(PlanningRules.evaluate(easy).decision, .planAsReviewed)
    }

    func testIllnessYesStopsAddedTrainingAndNotSureAsksFirst() {
        XCTAssertEqual(PlanningRules.evaluate(context { $0.illness = .yes }).decision, .noExtraTraining)
        XCTAssertEqual(PlanningRules.evaluate(context { $0.illness = .unsure }).decision, .needsClarification)
        XCTAssertEqual(PlanningRules.evaluate(context { $0.illness = .no }).decision, .planAsReviewed)
    }

    func testPainLeadsToReviewWithoutADiagnosis() {
        let lot = PainReport(day: "2026-10-01", areas: [.knee], level: .lot)
        let little = PainReport(day: "2026-10-01", areas: [.ankle], level: .little)
        XCTAssertEqual(PlanningRules.evaluate(context { $0.painToday = lot }).decision, .holdForProfessionalReview)
        XCTAssertEqual(PlanningRules.evaluate(context { $0.painToday = little }).decision, .modifyOptionalWork)
        XCTAssertEqual(PlanningRules.evaluate(context { $0.painFollowUp = little }).decision, .modifyOptionalWork)
        for rule in PlanningRules.all {
            let text = rule.explanation.lowercased()
            XCTAssertFalse(text.contains("tear") || text.contains("sprain") || text.contains("tendinitis"), "\(rule.id) never diagnoses")
        }
    }

    func testSevenTrainingDaysInARowMeansNoAddedWorkout() {
        XCTAssertEqual(PlanningRules.evaluate(context { $0.daysTrainedInARow = 7 }).decision, .noExtraTraining)
        XCTAssertEqual(PlanningRules.evaluate(context { $0.daysTrainedInARow = 6 }).decision, .planAsReviewed)
    }

    func testMissingDataIsUnknownNotRest() {
        let week = context { $0.daysWithoutData = 7; $0.checkedInToday = false }
        let result = PlanningRules.evaluate(week)
        XCTAssertTrue(result.uncertainties.contains("history_incomplete_7_of_14_days"))
        XCTAssertTrue(result.uncertainties.contains("no_check_in_today"))
        XCTAssertTrue(UncertaintyWords.text("history_incomplete_7_of_14_days").contains("not as rest"))
    }

    func testANoviceWithoutSupervisionIsFilteredQuietly() {
        let novice = context { $0.experience = .beginner; $0.supervised = false }
        let result = PlanningRules.evaluate(novice)
        XCTAssertEqual(result.decision, .planAsReviewed, "familiar exercises still run")
        XCTAssertTrue(result.triggered.contains("ELIG-SUPERVISION-03@1.0.0"), "the eligibility rule is on the record")
        XCTAssertNil(result.explanation)
    }

    func testEveryRuleIsVersionedLabelledAndDraftUntilReviewed() {
        XCTAssertEqual(Set(PlanningRules.all.map(\.id)).count, PlanningRules.all.count, "unique ids")
        for rule in PlanningRules.all {
            XCTAssertFalse(rule.version.isEmpty)
            XCTAssertEqual(rule.status, .draftRequiresExpertReview, "\(rule.id): nothing is expert-reviewed yet")
            for source in rule.basis { XCTAssertNotNil(EvidenceRegistry.source(source), "\(rule.id) cites \(source)") }
        }
        XCTAssertEqual(EvidenceRegistry.sources.count, 42)
    }

    func testTheDecisionRecordKeepsOneEntryPerDistinctDecision() throws {
        let suite = "PlanningRulesTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let trace = DecisionTrace(id: "a", day: "2026-10-01", createdAt: .now, knowledgeRelease: "k0", decision: .noExtraTraining,
                                  rules: ["SCHED-CONGESTION-05@1.0.0"], reasonCodes: ["RECENT_DEMANDING_PRACTICE_COMPETITION_NEAR"],
                                  uncertainties: [], selected: "No added workout", contentStatus: .draftRequiresExpertReview, inputs: [:])
        DecisionTraceStore.record(trace, defaults)
        var again = trace
        again.id = "b"
        DecisionTraceStore.record(again, defaults)
        XCTAssertEqual(DecisionTraceStore.all(defaults).count, 1, "the same decision isn't recorded twice")
        var changed = trace
        changed.id = "c"
        changed.decision = .planAsReviewed
        changed.rules = []
        changed.selected = "Gym day · 45 min"
        DecisionTraceStore.record(changed, defaults)
        XCTAssertEqual(DecisionTraceStore.all(defaults).map(\.id), ["a", "c"])
    }

    func testTheReleaseSaysWhatIsReviewed() {
        let release = KnowledgeRelease(release: "k3", quarantinedItems: ["box-jump"], reviewedItems: ["goblet-squat"], reviewedSports: ["golf"])
        XCTAssertTrue(release.isReviewed(item: "goblet-squat"))
        XCTAssertFalse(release.isReviewed(item: "box-jump"))
        XCTAssertTrue(release.isReviewed(sport: "golf"))
        XCTAssertFalse(KnowledgeRelease().isReviewed(sport: "basketball"), "nothing reviewed by default")
    }
}

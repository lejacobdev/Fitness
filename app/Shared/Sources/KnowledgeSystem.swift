import Foundation

// The governed core of AthleteOS's decisions (docs: "Athlete OS — The
// Backend Knowledge System", 2026-09-28): evidence and authority labelled
// separately, typed versioned rules in a fixed priority order, explicit
// decision outcomes (including "no extra training"), an inspectable record
// of every decision, and a release the server can use to switch rules off
// or quarantine content without an app update. Nothing here has been
// reviewed by the named experts yet: every rule and every piece of content
// is recorded as `draft_requires_expert_review` until it is.

// MARK: - Evidence

/// Evidence certainty and recommendation authority are separate (§2).
public enum EvidenceLabel: String, Codable, Sendable, CaseIterable {
    case high = "E-H", moderate = "E-M", low = "E-L", guidance = "G", heuristic = "H", product = "P"

    public var meaning: String {
        switch self {
        case .high: "High confidence in a tightly defined claim"
        case .moderate: "Moderate support, with real limitations"
        case .low: "Low or very low support"
        case .guidance: "Professional or public-health guidance"
        case .heuristic: "A practical rule, not proven science"
        case .product: "A product decision"
        }
    }
}

public enum ReviewStatus: String, Codable, Sendable {
    case draftRequiresExpertReview = "draft_requires_expert_review"
    case reviewed
    case quarantined
}

public struct EvidenceSource: Sendable, Identifiable, Equatable {
    public let id: String
    public let citation: String
    /// What it supports — and what it doesn't.
    public let scope: String
}

/// The 42 sources the specification was built on (accessed 28 Sep 2026).
public enum EvidenceRegistry {
    public static let sources: [EvidenceSource] = [
        EvidenceSource(id: "R01", citation: "NSCA / Lloyd et al. (2016). Position Statement on Long-Term Athletic Development.", scope: "Broad developmental principles; not app thresholds."),
        EvidenceSource(id: "R02", citation: "Bergeron et al. (2015). IOC consensus statement on youth athletic development. BJSM 49:843–851.", scope: "Developmental context and individual variation; not a readiness instrument."),
        EvidenceSource(id: "R03", citation: "Brenner & Watson / AAP (2024). Overuse Injuries, Overtraining, and Burnout in Young Athletes. Pediatrics 153.", scope: "Clinical report; some recommendations reflect expert opinion."),
        EvidenceSource(id: "R04", citation: "AAP (2024). Burnout in Young Athletes. HealthyChildren.org.", scope: "Weekly rest and yearly sport-break guidance; apply in context."),
        EvidenceSource(id: "R05", citation: "Faigenbaum et al. / NSCA (2009). Youth Resistance Training: Updated Position Statement. JSCR 23(S5).", scope: "Supervision and progression; final doses need full-text expert approval."),
        EvidenceSource(id: "R06", citation: "Lesinski, Prieske & Granacher (2016). Resistance training in youth athletes: meta-analysis. BJSM 50:781–795.", scope: "Broad method/outcome links; subgroup doses are not universal optima."),
        EvidenceSource(id: "R07", citation: "Plyometric-jump training by maturity: systematic review and meta-analysis (2023). PMID 37036542.", scope: "Low to very low certainty; no universal maturity algorithm."),
        EvidenceSource(id: "R08", citation: "Aldrich et al. (2024). Resisted sprint training and acceleration. IJES 17:986–1002.", scope: "Does not establish sled training as superior."),
        EvidenceSource(id: "R09", citation: "Schumann et al. (2022). Concurrent aerobic and strength training. Sports Med 52:601–612.", scope: "Distinct strength/hypertrophy/explosive outcomes; youth applicability indirect."),
        EvidenceSource(id: "R10", citation: "Saw, Main & Gastin (2016). Subjective self-reported measures in athlete monitoring. BJSM 50:281–291.", scope: "Contextual self-report monitoring; not an app composite or diagnosis."),
        EvidenceSource(id: "R11", citation: "Single-item self-report wellbeing measures in team sport (systematic review). PMID 32991706.", scope: "Adult field/court sports; limits for youth check-ins."),
        EvidenceSource(id: "R12", citation: "Foster et al. (2001). A new approach to monitoring exercise training. JSCR 15:109–115.", scope: "Session RPE is a load summary, not tissue or clinical risk."),
        EvidenceSource(id: "R13", citation: "Impellizzeri et al. (2020). Acute:chronic workload ratio: conceptual issues. PMID 32502973.", scope: "Why ACWR zones are not used as injury-risk categories."),
        EvidenceSource(id: "R14", citation: "Behm et al. (2016). Acute effects of muscle stretching. APNM 41:1–11.", scope: "Acute effects depend on duration and warm-up; not a blanket ban."),
        EvidenceSource(id: "R15", citation: "Resistance training and range of motion: meta-analysis (2023). PMID 36622555.", scope: "Range change does not establish injury prevention."),
        EvidenceSource(id: "R16", citation: "Chronic stretching and range of motion: meta-analysis (2023). PMID 37301370.", scope: "Range-of-motion outcome; not a universal need for more range."),
        EvidenceSource(id: "R17", citation: "Injury prevention programs in adolescent team sports: meta-analysis. PMID 26673035.", scope: "Program-level effect; single exercises don't inherit it."),
        EvidenceSource(id: "R18", citation: "Implementing neuromuscular warm-ups in youth team sport: systematic review (2024). PMID 38684329.", scope: "Implementation and adherence are central."),
        EvidenceSource(id: "R19", citation: "Neuromuscular training and injury rates in adolescent males (2026). PMID 41780148.", scope: "Adolescent males; heterogeneous strategies."),
        EvidenceSource(id: "R20", citation: "IOC consensus on elite youth athletes at the Olympic Games (2024). BJSM 58:946.", scope: "Environment and development; not training doses."),
        EvidenceSource(id: "R21", citation: "Reinebo et al. (2024). Psychological interventions and athletic performance. Sports Med 54:347–373.", scope: "Positive estimates not stable in sensitivity analyses."),
        EvidenceSource(id: "R22", citation: "Raabe et al. (2019). Autonomy support interventions with PE teachers and coaches. JSEP 41:345–355.", scope: "Coaching behaviour; not a digital motivation engine."),
        EvidenceSource(id: "R23", citation: "Williamson et al. (2024). Goal setting in sport: meta-analysis. IRSEP 17:1050–1078.", scope: "Process goals favourable; not individual guarantees."),
        EvidenceSource(id: "R24", citation: "Hatzigeorgiadis et al. (2011). Self-talk and sports performance. PPS 6:348–356.", scope: "Effects vary by task; no constant positive thinking required."),
        EvidenceSource(id: "R25", citation: "Chua et al. (2021). External attentional focus: systematic reviews and meta-analyses. PMID 34843301.", scope: "Read with R26; no universal cue rule."),
        EvidenceSource(id: "R26", citation: "McKay et al. (2024). Reporting bias, not external focus. Psych Bull 150:1347–1362.", scope: "Challenges broad external-focus superiority."),
        EvidenceSource(id: "R27", citation: "Reardon et al. (2026). Mental health in elite athletes: IOC consensus. BJSM 60:1083–1130.", scope: "Adolescent and Para-athlete gaps noted; no app diagnosis."),
        EvidenceSource(id: "R28", citation: "CDC. About Sleep (accessed 28 Sep 2026).", scope: "Age-based sleep duration; not a readiness threshold."),
        EvidenceSource(id: "R29", citation: "Mountjoy et al. (2023). IOC consensus on REDs. BJSM 57:1073–1098.", scope: "Scope and referral boundaries; no app REDs score."),
        EvidenceSource(id: "R30", citation: "CDC HEADS UP. Responding to a Sports-related Concussion.", scope: "Removal, medical assessment, emergency response."),
        EvidenceSource(id: "R31", citation: "CDC HEADS UP. Returning to Sports (updated 15 Sep 2025).", scope: "Healthcare-provider approval required; the app never clears anyone."),
        EvidenceSource(id: "R32", citation: "CDC. Heat and Athletes.", scope: "Stop, cool place if faint or weak; local protocol needs review."),
        EvidenceSource(id: "R33", citation: "Sports Dietitians Australia (2014). Sports nutrition for the adolescent athlete. PMID 24668620.", scope: "General adolescent fuelling principles."),
        EvidenceSource(id: "R34", citation: "S&C interventions and golf performance: systematic review (2020). PMID 32723013.", scope: "No exercise-specific guarantee."),
        EvidenceSource(id: "R35", citation: "Johansen et al. (2026). Physical training and golf shot performance. Sports Med.", scope: "Controlled-outcome certainty low; single-group very low."),
        EvidenceSource(id: "R36", citation: "Training load and match-play demands in basketball by competition level (2020). PLOS ONE.", scope: "Demand description, not a dose."),
        EvidenceSource(id: "R37", citation: "Dry-land training and swimming turn performance (2021). PMID 34501929.", scope: "Turn-specific; some categories inconclusive."),
        EvidenceSource(id: "R38", citation: "Small-sided games in football: acute and chronic adaptations. PMID 30373471.", scope: "Format matters; acute demand is not chronic adaptation."),
        EvidenceSource(id: "R39", citation: "Tapering and performance in endurance athletes (2023). PLOS ONE.", scope: "No universal taper rule."),
        EvidenceSource(id: "R40", citation: "Small-sided game formats in basketball: meta-analysis (2025). PMID 40656990.", scope: "Format-specific; no fixed load per small-sided session."),
        EvidenceSource(id: "R41", citation: "Maughan et al. (2018). IOC consensus: dietary supplements. BJSM.", scope: "Education and referral; no supplement advice for minors."),
        EvidenceSource(id: "R42", citation: "Walsh et al. (2021). Sleep and the athlete: expert consensus. BJSM 55:356–368.", scope: "Not a validation of exact sleep-to-training adjustments."),
    ]

    public static func source(_ id: String) -> EvidenceSource? { sources.first { $0.id == id } }
}

// MARK: - Decisions

/// Planning states, not health labels (§23).
public enum PlanDecision: String, Codable, Sendable, CaseIterable, Comparable {
    case planAsReviewed = "PLAN_AS_REVIEWED"
    case modifyOptionalWork = "MODIFY_OPTIONAL_WORK"
    case needsClarification = "NEEDS_CLARIFICATION"
    case noExtraTraining = "NO_EXTRA_TRAINING"
    case holdForProfessionalReview = "HOLD_FOR_PROFESSIONAL_REVIEW"

    /// How restrictive: the most restrictive triggered decision wins.
    var rank: Int {
        switch self {
        case .planAsReviewed: 0
        case .modifyOptionalWork: 1
        case .needsClarification: 2
        case .noExtraTraining: 3
        case .holdForProfessionalReview: 4
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

    /// Whether today's added workout is shown at all.
    public var allowsAddedTraining: Bool { self < .noExtraTraining }
}

/// What the planner knows about today — facts, plus what is unknown.
public struct PlanningContext: Sendable, Equatable {
    public var trainingPausedAfterHeadInjury = false
    public var headPainToday = false
    public var painToday: PainReport?
    public var painFollowUp: PainReport?
    /// "Are you ill or under a new restriction?" — nil when not asked.
    public var illness: IllnessAnswer?
    public var experience: TrainingExperience = .intermediate
    public var supervised = false
    public var checkedInToday = false
    public var scheduleKnown = true
    public var practiceToday = false
    /// Logged practice effort today (1–5), nil when not logged.
    public var practiceEffort: Int?
    /// Planned practice length today, minutes, when known.
    public var practiceMinutes: Int?
    public var competitionToday = false
    public var competitionTomorrow = false
    /// Days in the last 14 with no check-in, session or practice log.
    public var daysWithoutData = 0

    public init() {}
}

public enum IllnessAnswer: String, Codable, Sendable, CaseIterable {
    case no, yes, unsure

    public var title: String {
        switch self {
        case .no: "No"
        case .yes: "Yes"
        case .unsure: "Not sure"
        }
    }
}

/// A human-readable, typed, versioned rule (§26). Rules are data plus a
/// fixed predicate — never code from content or a model response.
public struct PlanningRule: Sendable, Identifiable {
    public let id: String
    public let version: String
    /// Higher wins: urgent safety first, preference last.
    public let priority: Int
    public let label: EvidenceLabel
    public let basis: [String]
    public let status: ReviewStatus
    public let reasonCode: String
    public let decision: PlanDecision
    /// What the athlete reads when this rule decides.
    public let explanation: String
    let when: @Sendable (PlanningContext) -> Bool

    /// Safety rules can't be switched off remotely.
    public var isSafety: Bool { id.hasPrefix("SAFE-") }
    public var versionedID: String { "\(id)@\(version)" }
}

public struct PlanningEvaluation: Sendable, Equatable {
    public let decision: PlanDecision
    /// Every triggered rule, highest priority first.
    public let triggered: [String]
    public let reasonCodes: [String]
    /// The decisive rule's explanation (nil: plan as usual).
    public let explanation: String?
    public let uncertainties: [String]
}

public enum PlanningRules {
    public static let all: [PlanningRule] = [
        PlanningRule(id: "SAFE-CONCUSSION-01", version: "1.0.0", priority: 1000, label: .guidance, basis: ["R30", "R31"],
                     status: .draftRequiresExpertReview, reasonCode: "POSSIBLE_HEAD_INJURY", decision: .holdForProfessionalReview,
                     explanation: "Training is paused until a doctor clears you after the head injury.",
                     when: { $0.trainingPausedAfterHeadInjury || $0.headPainToday }),
        PlanningRule(id: "SAFE-ILLNESS-02", version: "1.0.0", priority: 950, label: .guidance, basis: ["R03"],
                     status: .draftRequiresExpertReview, reasonCode: "ILLNESS_OR_RESTRICTION", decision: .noExtraTraining,
                     explanation: "You said you're ill or under a new restriction, so there's no added training today.",
                     when: { $0.illness == .yes }),
        PlanningRule(id: "SAFE-PAIN-03", version: "1.0.0", priority: 900, label: .guidance, basis: ["R03"],
                     status: .draftRequiresExpertReview, reasonCode: "PAIN_REPORTED", decision: .holdForProfessionalReview,
                     explanation: "You reported a lot of pain. No added training today — tell a coach, athletic trainer or parent.",
                     when: { $0.painToday?.level == .lot }),
        PlanningRule(id: "SAFE-PAIN-04", version: "1.0.0", priority: 890, label: .guidance, basis: ["R03"],
                     status: .draftRequiresExpertReview, reasonCode: "PAIN_REPORTED", decision: .modifyOptionalWork,
                     explanation: "Because you reported pain, work that loads that area is left out today.",
                     when: { $0.painToday != nil && $0.painToday?.level != .lot }),
        PlanningRule(id: "ELIG-SUPERVISION-03", version: "1.0.0", priority: 800, label: .guidance, basis: ["R05"],
                     status: .draftRequiresExpertReview, reasonCode: "SUPERVISION_REQUIRED", decision: .planAsReviewed,
                     explanation: "New to lifting and no coach supervising: coached lifts stay out; familiar exercises only.",
                     when: { $0.experience == .beginner && !$0.supervised }),
        PlanningRule(id: "DATA-UNKNOWN-04", version: "1.0.0", priority: 700, label: .product, basis: [],
                     status: .draftRequiresExpertReview, reasonCode: "NEEDS_INFORMATION", decision: .needsClarification,
                     explanation: "Not sure if you're ill? Tell an adult how you feel; until then today stays light.",
                     when: { $0.illness == .unsure }),
        PlanningRule(id: "SAFE-PAIN-FOLLOWUP-05", version: "1.0.0", priority: 650, label: .guidance, basis: ["R03"],
                     status: .draftRequiresExpertReview, reasonCode: "PAIN_RECENTLY", decision: .modifyOptionalWork,
                     explanation: "You reported pain recently, so today stays lighter until you say it's gone.",
                     when: { $0.painToday == nil && $0.painFollowUp != nil }),
        PlanningRule(id: "SCHED-CONGESTION-05", version: "1.0.0", priority: 600, label: .heuristic, basis: ["R03", "R39"],
                     status: .draftRequiresExpertReview, reasonCode: "RECENT_DEMANDING_PRACTICE_COMPETITION_NEAR", decision: .noExtraTraining,
                     explanation: "Practice today and a game tomorrow: no added workout. It protects tomorrow; it isn't a prediction about injury.",
                     when: { $0.practiceToday && ($0.competitionTomorrow || $0.competitionToday) && (($0.practiceEffort ?? 0) >= 4 || ($0.practiceMinutes ?? 0) >= 75 || $0.practiceEffort == nil) }),
        PlanningRule(id: "SCHED-COMPETITION-06", version: "1.0.0", priority: 590, label: .heuristic, basis: ["R39"],
                     status: .draftRequiresExpertReview, reasonCode: "COMPETITION_TODAY", decision: .noExtraTraining,
                     explanation: "Game day: no added workout. Save your energy for the game.",
                     when: { $0.competitionToday }),
    ]

    /// Highest priority first; rules switched off by the knowledge release
    /// are skipped — except safety rules, which can never be switched off.
    public static func evaluate(_ context: PlanningContext, disabled: Set<String> = []) -> PlanningEvaluation {
        let active = all.filter { $0.isSafety || !disabled.contains($0.id) }.sorted { $0.priority > $1.priority }
        let triggered = active.filter { $0.when(context) }
        let decision = triggered.map(\.decision).max() ?? .planAsReviewed
        // Eligibility rules that only filter exercises are recorded, not announced.
        let decisive = decision == .planAsReviewed ? nil : triggered.first { $0.decision == decision }
        var uncertainties: [String] = []
        if !context.checkedInToday { uncertainties.append("no_check_in_today") }
        if context.practiceToday && context.practiceEffort == nil { uncertainties.append("practice_effort_not_logged") }
        if !context.scheduleKnown { uncertainties.append("schedule_not_set") }
        if context.daysWithoutData > 0 { uncertainties.append("history_incomplete_\(context.daysWithoutData)_of_14_days") }
        return PlanningEvaluation(
            decision: decision,
            triggered: triggered.map(\.versionedID),
            reasonCodes: triggered.map(\.reasonCode).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } },
            explanation: decisive?.explanation,
            uncertainties: uncertainties
        )
    }
}

// MARK: - The knowledge release (server kill switch)

/// What the server currently publishes: rules switched off, exercises
/// quarantined, and what experts have reviewed. Nothing reviewed yet.
public struct KnowledgeRelease: Codable, Sendable, Equatable {
    public var release: String
    public var disabledRules: [String]
    public var quarantinedItems: [String]
    public var reviewedItems: [String]
    public var reviewedSports: [String]

    public init(release: String = "local-1", disabledRules: [String] = [], quarantinedItems: [String] = [],
                reviewedItems: [String] = [], reviewedSports: [String] = []) {
        self.release = release
        self.disabledRules = disabledRules
        self.quarantinedItems = quarantinedItems
        self.reviewedItems = reviewedItems
        self.reviewedSports = reviewedSports
    }

    public func isReviewed(item slug: String) -> Bool { reviewedItems.contains(slug) }
    public func isReviewed(sport slug: String) -> Bool { reviewedSports.contains(slug) }
}

// MARK: - The decision record

/// Why a day's plan looked the way it did, kept so it can be read and
/// reproduced (§29): the inputs that mattered, the rules and their
/// versions, the decision, what was unknown and the content's review state.
public struct DecisionTrace: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var day: String
    public var createdAt: Date
    public var knowledgeRelease: String
    public var decision: PlanDecision
    public var rules: [String]
    public var reasonCodes: [String]
    public var uncertainties: [String]
    /// The plan that was shown ("Gym day · 45 min", "No added workout").
    public var selected: String
    public var contentStatus: ReviewStatus
    public var inputs: [String: String]
}

public enum DecisionTraceStore {
    static let key = "progress.decisionTraces"

    public static func all(_ defaults: UserDefaults = .standard) -> [DecisionTrace] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return defaults.data(forKey: key).flatMap { try? decoder.decode([DecisionTrace].self, from: $0) } ?? []
    }

    /// Keeps one record per distinct decision a day, 90 days back.
    public static func record(_ trace: DecisionTrace, _ defaults: UserDefaults = .standard) {
        var traces = all(defaults)
        let same = traces.firstIndex {
            $0.day == trace.day && $0.decision == trace.decision && $0.rules == trace.rules
                && $0.selected == trace.selected && $0.knowledgeRelease == trace.knowledgeRelease
        }
        if same != nil { return }
        traces.append(trace)
        traces = Array(traces.sorted { $0.createdAt < $1.createdAt }.suffix(300))
        if let oldest = traces.last.flatMap({ Calendar.current.date(byAdding: .day, value: -90, to: $0.createdAt) }) {
            traces.removeAll { $0.createdAt < oldest }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(traces), forKey: key)
    }
}

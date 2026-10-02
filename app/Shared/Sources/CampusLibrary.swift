import Foundation

// V6 Campus (docs/VERSION-6.md §11–§17): an athlete education system, not
// random articles. Categories hold lessons in five levels; every lesson is
// tagged with the situations it's useful in, so Campus can recommend the
// right one on the right day.

public enum CampusLevel: Int, CaseIterable, Sendable, Comparable {
    case foundations = 1, development, performance, sportIQ, selfCoaching

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .foundations: "Foundations"
        case .development: "Development"
        case .performance: "Performance"
        case .sportIQ: "Sport IQ"
        case .selfCoaching: "Self-coaching"
        }
    }

    public var subtitle: String {
        switch self {
        case .foundations: "What every athlete needs to know."
        case .development: "How training and adaptation work."
        case .performance: "More advanced training ideas."
        case .sportIQ: "Understanding your sport."
        case .selfCoaching: "Making good decisions on your own."
        }
    }
}

/// A lesson written with its hook and athlete example inline (V6 lessons).
func campusLesson(_ id: String, _ title: String, _ minutes: Int, hook: (String, String), _ sections: [(String, String)],
                  example: String, _ takeaways: [String]) -> CampusLesson {
    var all = [CampusSection(heading: hook.0, body: hook.1)]
    all += sections.map { CampusSection(heading: $0.0, body: $0.1) }
    all.append(CampusSection(heading: CampusLesson.exampleHeading, body: example))
    return CampusLesson(id: id, title: title, minutes: minutes, sections: all, takeaways: takeaways)
}

public enum CampusLibrary {
    /// Every lesson's level (lessons not listed are Foundations).
    static let levels: [String: CampusLevel] = {
        var out: [String: CampusLevel] = [:]
        let table: [CampusLevel: [String]] = [
            .development: ["technique-load", "rest-days", "pressure", "landing", "feedback",
                           "ts-relative-strength", "ts-power", "ts-acceleration", "ts-conditioning", "ts-fatigue",
                           "am-squat-hinge", "am-push-pull", "am-deceleration", "am-locomotion",
                           "nu-fats", "nu-electrolytes", "nu-game-day", "nu-growth",
                           "sr-naps", "sr-school-stress", "sr-travel", "sr-after-games",
                           "ps-goals", "ps-self-talk", "ps-imagery", "ps-routines", "ps-reset",
                           "su-evidence", "su-risks", "su-marketing", "su-protein", "su-caffeine", "su-sports-drinks", "su-vitamins",
                           "dg-notifications", "dg-before-games", "dg-recovery-time"],
            .performance: ["overtraining", "force", "leadership",
                           "ts-specificity", "ts-in-season", "ts-off-season", "ts-more-less", "ts-frequency",
                           "am-mobility-stability", "am-coordination", "nu-timing", "sr-downshift",
                           "ps-emotions", "ps-bad-games", "ps-identity", "su-creatine", "su-preworkout", "dg-comparison"],
            .sportIQ: ["reading", "positioning", "game-plan"],
            .selfCoaching: ["what-matters", "check-ins", "healthy-data", "years", "specialise", "balance",
                            "sc-reading-body", "sc-adjusting", "sc-own-session", "sc-season-plan"],
        ]
        for (level, ids) in table { for id in ids { out[id] = level } }
        return out
    }()

    public static func level(of lessonID: String) -> CampusLevel { levels[lessonID] ?? .foundations }

    /// What each lesson is useful for, for contextual recommendations (§16).
    static let tags: [String: Set<String>] = [
        "sleep-power": ["sleep", "short-night"], "sr-how-much": ["sleep", "short-night"], "sr-routine": ["sleep", "late"],
        "sr-consistency": ["sleep", "late"], "dg-sleep": ["phone-sleep", "late", "sleep"], "dg-attention": ["focus", "phone"],
        "dg-intentional": ["phone"], "dg-before-games": ["game", "phone"],
        "pressure": ["game", "nerves"], "ps-routines": ["game"], "ps-self-talk": ["confidence", "nerves"], "confidence": ["confidence"],
        "ps-reset": ["mistakes"], "mistakes": ["mistakes", "bad-game"], "ps-bad-games": ["bad-game"], "ps-focus": ["focus"],
        "rest-days": ["recovery", "sore"], "sr-after-games": ["after-game", "recovery"], "ts-soreness": ["sore"],
        "overtraining": ["tired"], "ts-fatigue": ["tired", "hard-training"], "sr-downshift": ["hard-training", "stress"],
        "ts-power": ["power"], "ts-acceleration": ["acceleration", "speed"], "ts-relative-strength": ["strength"],
        "ts-conditioning": ["conditioning"], "ts-in-season": ["in-season"], "ts-off-season": ["off-season"],
        "nu-pre-practice": ["practice-fuel"], "nu-game-day": ["game", "fuel"], "hydration": ["heat", "fuel"],
        "su-what": ["supplements"], "su-creatine": ["creatine", "supplements"], "su-caffeine": ["caffeine", "supplements"],
        "su-protein": ["protein", "supplements"], "pain": ["pain"], "balance": ["exam"], "sr-school-stress": ["exam", "stress"],
        "sr-travel": ["travel"], "ps-identity": ["injured"],
    ]

    /// The lessons that fit a situation, most specific first.
    public static func lessons(tagged tag: String) -> [CampusLesson] {
        let ids = tags.filter { $0.value.contains(tag) }.map(\.key).sorted()
        return ids.compactMap { id in campusTopics.lazy.flatMap(\.lessons).first { $0.id == id } }
    }

    /// The draft label: written carefully from sources, not yet reviewed by
    /// an outside expert.
    public static let reviewNote = "Written from published research and sports-medicine guidance. Not yet reviewed by an outside expert."
}

/// V6 lessons' quizzes, merged.
let campusQuestionsV6: [String: [CampusQuestion]] = {
    var all: [String: [CampusQuestion]] = [:]
    for part in [trainingScienceQuestions, anatomyQuestions, nutritionQuestions, sleepQuestions, psychologyQuestions,
                 supplementQuestions, digitalQuestions, selfCoachingQuestions] {
        all.merge(part) { first, _ in first }
    }
    return all
}()

/// The old units' lessons, by id (for building the V6 categories).
private let legacyLessons: [String: CampusLesson] = Dictionary(uniqueKeysWithValues: legacyCampusTopics.flatMap(\.lessons).map { ($0.id, $0) })

private func ordered(_ ids: [String], extra: [CampusLesson]) -> [CampusLesson] {
    let all = ids.compactMap { legacyLessons[$0] } + extra
    return all.enumerated().sorted { lhs, rhs in
        let l = CampusLibrary.level(of: lhs.element.id), r = CampusLibrary.level(of: rhs.element.id)
        return l != r ? l < r : lhs.offset < rhs.offset
    }.map(\.element)
}

/// The V6 categories. Ids of the old units are kept where the unit lives on.
public let campusTopics: [CampusTopic] = [
    CampusTopic(id: "training-science", title: "Training science",
                subtitle: "Strength, power, speed, conditioning — and how your body adapts.", systemImage: "bolt.heart.fill",
                lessons: ordered(["adaptation", "qualities", "warm-up"], extra: trainingScienceLessons)),
    CampusTopic(id: "injury-anatomy", title: "Anatomy & movement",
                subtitle: "Muscles, joints, the movement patterns, and moving well.", systemImage: "figure.walk.motion",
                lessons: ordered(["body-basics", "technique-load", "force", "landing", "pain"], extra: anatomyLessons)),
    CampusTopic(id: "nutrition", title: "Nutrition & hydration",
                subtitle: "Fuel for training and growing. Performance, never dieting.", systemImage: "fork.knife",
                lessons: ordered(["fuel-basics", "hydration", "recovery-eating"], extra: nutritionLessons)),
    CampusTopic(id: "sleep", title: "Sleep & recovery",
                subtitle: "Sleep, rest days, stress and switching off.", systemImage: "moon.zzz.fill",
                lessons: ordered(["sleep-power", "rest-days", "overtraining"], extra: sleepLessons)),
    CampusTopic(id: "psychology", title: "Sports psychology",
                subtitle: "Confidence, focus, pressure, mistakes — skills you can train.", systemImage: "brain.head.profile",
                lessons: ordered(["confidence", "pressure", "mistakes", "feedback", "coach", "teammates", "leadership"], extra: psychologyLessons)),
    CampusTopic(id: "supplements", title: "Supplements & performance",
                subtitle: "Understand them — evidence, risks and marketing. Education, not advice.", systemImage: "pills.fill",
                lessons: ordered([], extra: supplementLessons)),
    CampusTopic(id: "digital", title: "Digital performance",
                subtitle: "Phones, attention, sleep and recovery time — used on purpose.", systemImage: "iphone",
                lessons: ordered([], extra: digitalLessons)),
    CampusTopic(id: "tactics", title: "Sport IQ",
                subtitle: "Reading the game, positioning and decisions.", systemImage: "sportscourt.fill",
                lessons: ordered(["reading", "positioning", "game-plan"], extra: [])),
    CampusTopic(id: "long-term", title: "Self-coaching",
                subtitle: "Reading your body, adjusting your plan, thinking long-term.", systemImage: "compass.drawing",
                lessons: ordered(["what-matters", "check-ins", "healthy-data", "years", "specialise", "balance"], extra: selfCoachingLessons)),
]


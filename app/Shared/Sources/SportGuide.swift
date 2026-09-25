import Foundation

/// The sport knowledge library: for every featured sport, what the sport
/// asks of the body, what the best athletes do, how training changes over
/// the season, the gym work and injury prevention that matter, tips per
/// position, mindset, fuel, the studies behind it, and a short quiz.
/// Written in content/src/guides and embedded by the content build
/// (Generated/SportGuides.swift).
public struct SportGuide: Decodable, Sendable, Identifiable, Hashable {
    public struct Demand: Decodable, Sendable, Hashable {
        public let label: String
        public let value: String
    }

    public struct Tip: Decodable, Sendable, Hashable {
        public let title: String
        public let body: String
    }

    public struct Season: Decodable, Sendable, Hashable {
        public let off: String
        public let pre: String
        public let inSeason: String

        enum CodingKeys: String, CodingKey {
            case off, pre
            case inSeason = "in"
        }
    }

    public struct Gym: Decodable, Sendable, Hashable {
        public let focus: [String]
        public let exercises: [String]
    }

    public struct Injury: Decodable, Sendable, Hashable {
        public let area: String
        public let body: String
        public let exercises: [String]
    }

    public struct Source: Decodable, Sendable, Hashable {
        public let title: String
        public let detail: String
        public let url: String
    }

    /// `kind` is "choice" (`options` + `answer`) or "trueFalse" (`truth`).
    public struct Question: Decodable, Sendable, Hashable {
        public let kind: String
        public let prompt: String
        public let options: [String]?
        public let answer: Int?
        public let truth: Bool?
        public let explain: String

        public var campusQuestion: CampusQuestion? {
            switch kind {
            case "choice":
                guard let options, let answer, options.indices.contains(answer) else { return nil }
                return .choice(prompt: prompt, options: options, answer: answer, explain: explain)
            case "trueFalse":
                guard let truth else { return nil }
                return .trueFalse(statement: prompt, answer: truth, explain: explain)
            default:
                return nil
            }
        }
    }

    public let slug: String
    public let headline: String
    public let demands: [Demand]
    public let succeed: [Tip]
    public let season: Season
    public let gym: Gym
    public let injuries: [Injury]
    /// Position slug → what matters most in that position.
    public let positions: [String: String]
    public let mindset: [String]
    public let fuel: String
    public let sources: [Source]
    public let quiz: [Question]

    public var id: String { slug }

    public static func forSport(_ slug: String?) -> SportGuide? {
        slug.flatMap { sportGuidesBySlug[$0] }
    }

    /// The quiz as Campus lesson steps: a teaching card from the guide, then
    /// a question, so it plays like any other lesson.
    public var quizSteps: [CampusStep] {
        let cards = succeed.map { CampusStep.teach(CampusSection(heading: $0.title, body: $0.body)) }
        let questions = quiz.compactMap(\.campusQuestion).map { CampusStep.question($0) }
        var out: [CampusStep] = []
        for i in 0..<max(cards.count, questions.count) {
            if i < cards.count { out.append(cards[i]) }
            if i < questions.count { out.append(questions[i]) }
        }
        return out
    }

    /// The advice for a season phase (after the season is off-season).
    public func seasonAdvice(for phase: SeasonPhase) -> String {
        switch phase {
        case .offSeason, .postSeason: season.off
        case .preSeason: season.pre
        case .inSeason: season.inSeason
        }
    }
}

/// Guides whose quiz the athlete has passed (backed up with Campus).
public enum SportGuideProgress {
    static let key = "campus.guidesPassed"

    public static func passed(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Records a passed quiz; true the first time for this sport.
    @discardableResult
    public static func markPassed(_ slug: String, defaults: UserDefaults = .standard) -> Bool {
        var set = passed(defaults)
        guard set.insert(slug).inserted else { return false }
        defaults.set(set.sorted(), forKey: key)
        return true
    }
}

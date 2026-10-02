import AVFoundation
import Foundation

/// The lesson that fits today: after a short night, the sleep lesson;
/// before a game, handling nerves; after reported pain, when pain means
/// stop. Nil on an ordinary day (the path's next lesson then).
public enum LessonPicker {
    public struct Context: Sendable {
        public var sleepHours: Double?
        public var sleepQuality: Int?
        public var soreness: Int?
        public var energy: Int?
        public var daysToGame: Int?
        public var pain: Bool
        public var examWeek: Bool
        // V6 §16: more of the athlete's real day.
        public var gameYesterday: Bool
        public var hardDayYesterday: Bool
        /// Short nights (under 7 h) in the last week.
        public var shortNights: Int
        public var lowConfidence: Bool
        /// What today's session trains (Capacity raw values).
        public var trainingToday: [String]
        public var inSeason: Bool
        /// Lessons already done: the next useful one is suggested instead.
        public var learned: Set<String>

        public init(sleepHours: Double? = nil, sleepQuality: Int? = nil, soreness: Int? = nil, energy: Int? = nil,
                    daysToGame: Int? = nil, pain: Bool = false, examWeek: Bool = false, gameYesterday: Bool = false,
                    hardDayYesterday: Bool = false, shortNights: Int = 0, lowConfidence: Bool = false,
                    trainingToday: [String] = [], inSeason: Bool = false, learned: Set<String> = []) {
            self.sleepHours = sleepHours
            self.sleepQuality = sleepQuality
            self.soreness = soreness
            self.energy = energy
            self.daysToGame = daysToGame
            self.pain = pain
            self.examWeek = examWeek
            self.gameYesterday = gameYesterday
            self.hardDayYesterday = hardDayYesterday
            self.shortNights = shortNights
            self.lowConfidence = lowConfidence
            self.trainingToday = trainingToday
            self.inSeason = inSeason
            self.learned = learned
        }
    }

    public static func forToday(_ context: Context) -> (id: String, reason: String)? {
        /// The first of these not learned yet (or the first, to replay).
        func pick(_ ids: [String], _ reason: String) -> (id: String, reason: String) {
            (ids.first { !context.learned.contains($0) } ?? ids[0], reason)
        }
        func fresh(_ ids: [String]) -> Bool { ids.contains { !context.learned.contains($0) } }

        if context.pain { return pick(["pain"], "You reported pain: when to stop, and when to get checked.") }
        if (context.sleepHours ?? 8) < 6.5 || (context.sleepQuality ?? 3) <= 1 {
            return pick(["sleep-power", "sr-how-much", "sr-routine"], "After a short night: how sleep helps you recover.")
        }
        if let days = context.daysToGame, days <= 1 {
            return pick(["pressure", "ps-routines", "nu-game-day"], "Competition coming up: handling pressure.")
        }
        if context.shortNights >= 3, fresh(["dg-sleep", "sr-consistency", "sr-routine"]) {
            return pick(["dg-sleep", "sr-consistency", "sr-routine"], "Several short nights this week: phones, routines and sleep.")
        }
        if context.gameYesterday, fresh(["sr-after-games"]) {
            return pick(["sr-after-games"], "You played yesterday: how recovery after games works.")
        }
        if (context.soreness ?? 1) >= 4 { return pick(["rest-days", "ts-soreness"], "Feeling sore: why recovery makes you better.") }
        if (context.energy ?? 3) <= 1 { return pick(["overtraining", "ts-fatigue"], "Low energy: spotting too much fatigue.") }
        if context.examWeek { return pick(["balance", "sr-school-stress"], "Exam week: balancing sport and school.") }
        if context.hardDayYesterday, fresh(["ts-fatigue", "sr-downshift"]) {
            return pick(["ts-fatigue", "sr-downshift"], "After a hard day: how recovery works.")
        }
        if context.lowConfidence, fresh(["confidence", "ps-self-talk", "ps-routines"]) {
            return pick(["confidence", "ps-self-talk", "ps-routines"], "Building confidence from preparation.")
        }
        if context.trainingToday.contains("power"), fresh(["ts-power"]) {
            return pick(["ts-power"], "Today's session trains power. Here's what power is.")
        }
        if context.trainingToday.contains("acceleration") || context.trainingToday.contains("speed"), fresh(["ts-acceleration"]) {
            return pick(["ts-acceleration"], "Today trains speed: how acceleration and top speed work.")
        }
        if context.inSeason, context.trainingToday.contains("strength") || context.trainingToday.contains("upperStrength"), fresh(["ts-in-season"]) {
            return pick(["ts-in-season"], "Why strength still matters in season.")
        }
        return nil
    }

    public static func lesson(_ id: String) -> (lesson: CampusLesson, topic: CampusTopic)? {
        for topic in campusTopics {
            if let lesson = topic.lessons.first(where: { $0.id == id }) { return (lesson, topic) }
        }
        return nil
    }
}

public extension SportGuide {
    /// "Know your position": the guide's advice for the athlete's position
    /// as a short lesson (no quiz).
    func positionLesson(positionSlug: String, positionName: String) -> CampusLesson? {
        guard let tip = positions[positionSlug] else { return nil }
        return CampusLesson(
            id: "position-\(slug)-\(positionSlug)", title: "Know your position", minutes: 2,
            sections: [
                CampusSection(heading: "The \(positionName.lowercased())", body: "What the best at your position do, in your sport."),
                CampusSection(heading: "Your job", body: tip),
            ],
            takeaways: succeed.prefix(2).map(\.title)
        )
    }
}

/// Reads a lesson aloud, for the bus: every teaching card in order.
@MainActor
final class LessonSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ lesson: CampusLesson) {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        let text = ([lesson.title] + lesson.steps.compactMap { step -> String? in
            if case .teach(let section) = step { return "\(section.heading). \(section.body.replacingOccurrences(of: "•", with: ""))" }
            return nil
        }).joined(separator: "\n\n")
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

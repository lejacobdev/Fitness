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

        public init(sleepHours: Double? = nil, sleepQuality: Int? = nil, soreness: Int? = nil, energy: Int? = nil,
                    daysToGame: Int? = nil, pain: Bool = false, examWeek: Bool = false) {
            self.sleepHours = sleepHours
            self.sleepQuality = sleepQuality
            self.soreness = soreness
            self.energy = energy
            self.daysToGame = daysToGame
            self.pain = pain
            self.examWeek = examWeek
        }
    }

    public static func forToday(_ context: Context) -> (id: String, reason: String)? {
        if context.pain { return ("pain", "You reported pain: when to stop, and when to get checked.") }
        if (context.sleepHours ?? 8) < 6.5 || (context.sleepQuality ?? 3) <= 1 {
            return ("sleep-power", "After a short night: how sleep helps you recover.")
        }
        if let days = context.daysToGame, days <= 1 { return ("pressure", "Game coming up: turn nerves into readiness.") }
        if (context.soreness ?? 1) >= 4 { return ("rest-days", "Feeling sore: why recovery makes you better.") }
        if (context.energy ?? 3) <= 1 { return ("overtraining", "Low energy: spotting too much fatigue.") }
        if context.examWeek { return ("balance", "Exam week: balancing sport and school.") }
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

import Foundation

/// §13's fuelling engine. Pure — no SwiftData, no HealthKit, no clock unless
/// passed in. Its whole job is to help a growing athlete eat ENOUGH around
/// training, never less: there is no calorie number anywhere in this file,
/// no deficit, no target weight. Guidance is plate-and-timing only, and every
/// string it can produce is linted in FuelEngineTests.
public struct FuelTip: Sendable, Equatable, Identifiable {
    public let id: String
    public let time: Date?
    public let title: String
    public let detail: String
    public let systemImage: String

    public init(id: String, time: Date?, title: String, detail: String, systemImage: String) {
        self.id = id
        self.time = time
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

/// Daily portion targets — "a protein portion, a carbohydrate portion,
/// colour on the plate" (§13), counted in hands and fists, never grams.
public struct PlateTargets: Sendable, Equatable {
    public let protein: Int
    public let carbs: Int
    public let colour: Int
}

public enum FuelEngine {
    /// §23-style named constants.
    public static let baseGlasses = 8
    public static let maxGlasses = 14
    /// A default after-school practice start, used when the athlete hasn't
    /// set their own training time.
    public static let defaultTrainingStartMinutes = 15 * 60 + 30

    public static let standingNote = "General sports-nutrition guidance, not medical advice. If you have specific dietary needs, a medical condition or follow a restrictive diet, talk to a doctor or registered dietitian."

    // MARK: Hydration

    /// Glasses (~250 ml) for the day: a base, one more per 30 minutes of
    /// training, two more in the heat.
    public static func hydrationTarget(trainingMinutes: Int, isHot: Bool = false) -> Int {
        let training = Int((Double(max(0, trainingMinutes)) / 30).rounded(.up))
        return min(maxGlasses, baseGlasses + training + (isHot ? 2 : 0))
    }

    // MARK: Plate

    public static func plateTargets(trainingMinutes: Int, isGameDay: Bool) -> PlateTargets {
        let heavy = isGameDay || trainingMinutes > 75
        let training = trainingMinutes > 0
        return PlateTargets(
            protein: 4,
            carbs: heavy ? 6 : (training ? 5 : 4),
            colour: 5
        )
    }

    // MARK: Around a session

    /// What and roughly when to eat around one training session, sized to
    /// its length and time of day.
    public static func sessionTimeline(start: Date, minutes: Int, calendar: Calendar = .current) -> [FuelTip] {
        guard minutes > 0 else { return [] }
        var tips: [FuelTip] = []
        let hour = calendar.component(.hour, from: start)
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))

        if hour < 9 {
            tips.append(FuelTip(
                id: "pre-early", time: start.addingTimeInterval(-45 * 60),
                title: "Quick fuel before an early session",
                detail: "Something light with carbs 30–60 minutes before: a banana, toast with honey, or a glass of milk. Training on empty makes the session harder, not better.",
                systemImage: "sunrise.fill"
            ))
        } else {
            tips.append(FuelTip(
                id: "pre-meal", time: start.addingTimeInterval(-150 * 60),
                title: "Proper meal 2–3 hours before",
                detail: "A plate with a carb portion, a protein portion and some colour — like pasta with chicken and veg, or a rice bowl.",
                systemImage: "fork.knife"
            ))
            tips.append(FuelTip(
                id: "pre-snack", time: start.addingTimeInterval(-45 * 60),
                title: "Top-up snack",
                detail: "If lunch feels like a long time ago, add a small carb snack 30–60 minutes before: fruit, a granola bar or a few crackers.",
                systemImage: "carrot.fill"
            ))
        }

        tips.append(FuelTip(
            id: "during-water", time: start,
            title: minutes > 60 ? "Water and a carb snack during" : "Sip water during",
            detail: minutes > 60
                ? "Over an hour: keep sipping, and take a quick carb (fruit, sports drink) around the halfway point."
                : "Take a few sips every 15–20 minutes, more in the heat.",
            systemImage: "drop.fill"
        ))

        tips.append(FuelTip(
            id: "post-recovery", time: end.addingTimeInterval(30 * 60),
            title: "Recovery within an hour",
            detail: "Protein plus carbs to refuel and rebuild: chocolate milk, a yogurt and fruit, or dinner if it's close. Bigger sessions need a bigger refuel.",
            systemImage: "arrow.clockwise.heart.fill"
        ))
        return tips
    }

    // MARK: Game day (§13's "one genuinely high-value piece")

    public static func gameDayTimeline(gameStart: Date, isTournament: Bool) -> [FuelTip] {
        var tips = [
            FuelTip(
                id: "game-3h", time: gameStart.addingTimeInterval(-3 * 3600),
                title: "3 hours out: your pre-game meal",
                detail: "A familiar meal built on carbs, with some protein, nothing too heavy or greasy: pasta, rice, potatoes, bread, lean meat or eggs. Nothing new on game day.",
                systemImage: "fork.knife"
            ),
            FuelTip(
                id: "game-1h", time: gameStart.addingTimeInterval(-3600),
                title: "1 hour out: a small top-up",
                detail: "A light, easy carb: a banana, a few crackers, or a sports drink. Keep sipping water.",
                systemImage: "carrot.fill"
            ),
            FuelTip(
                id: "game-warmup", time: gameStart.addingTimeInterval(-30 * 60),
                title: "Warm-up: sip, don't gulp",
                detail: "A few mouthfuls of water through the warm-up.",
                systemImage: "drop.fill"
            ),
        ]
        if isTournament {
            tips.append(FuelTip(
                id: "game-between", time: nil,
                title: "Between games",
                detail: "Refuel straight away with quick carbs and fluid: fruit, a sandwich, a sports drink. If there's more than two hours, have a proper small meal.",
                systemImage: "timer"
            ))
        }
        tips.append(FuelTip(
            id: "game-after", time: gameStart.addingTimeInterval(2 * 3600),
            title: "After the game",
            detail: "A full recovery meal with protein, carbs and colour, plus plenty of fluid. You earned it.",
            systemImage: "arrow.clockwise.heart.fill"
        ))
        return tips
    }

    /// Every sentence this engine can produce, for the language lint.
    public static var allGuidanceStrings: [String] {
        let reference = Date(timeIntervalSince1970: 1_790_000_000)
        let morning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: reference) ?? reference
        let afternoon = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: reference) ?? reference
        let tips = sessionTimeline(start: morning, minutes: 45) + sessionTimeline(start: afternoon, minutes: 90)
            + gameDayTimeline(gameStart: afternoon, isTournament: true)
        return tips.flatMap { [$0.title, $0.detail] } + [standingNote]
    }

    /// Words §13 forbids anywhere in fuelling guidance.
    public static let bannedWords = ["deficit", "diet plan", "dieting", "weight loss", "lose weight", "fat loss", "burn fat", "skinny", "calorie", "calories", "cutting", "body shape"]
}

/// §17: "sum the asleep stages rather than trusting inBed." Samples from
/// the iPhone and the Watch can overlap, so intervals are merged before
/// summing — otherwise one night can read as fourteen hours.
public enum SleepMath {
    public static func asleepHours(_ intervals: [(start: Date, end: Date)]) -> Double {
        let sorted = intervals.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: (start: Date, end: Date)?
        for interval in sorted {
            if let open = current, interval.start <= open.end {
                current = (open.start, max(open.end, interval.end))
            } else {
                if let open = current { total += open.end.timeIntervalSince(open.start) }
                current = interval
            }
        }
        if let open = current { total += open.end.timeIntervalSince(open.start) }
        return total / 3600
    }

    public static func label(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

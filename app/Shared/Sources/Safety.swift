import Foundation

/// Safety: the low-energy warning (constant fatigue while training a lot)
/// and the concussion return-to-play steps. The app explains and pauses —
/// it never diagnoses and never clears anyone to play; a doctor or athletic
/// trainer does.

// MARK: - Low energy

/// Feeling drained most days while training a lot can mean the body isn't
/// getting enough energy for the training (low energy availability / RED-S),
/// too little sleep, or illness. Worth saying out loud — kindly.
public struct LowEnergyWarning: Sendable, Equatable {
    public let lowDays: Int
    public let checkIns: Int
    public let trainingDays: Int
}

public enum LowEnergyCheck {
    public static let windowDays = 14

    /// Warns when, in the last two weeks, energy was 1–2 on at least 5
    /// check-ins and at least half of them, while training on 8 or more days.
    public static func evaluate(energies: [(date: Date, energy: Int)], trainingDays: Set<Date>,
                                now: Date = .now, calendar: Calendar = .current) -> LowEnergyWarning? {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) else { return nil }
        let recent = energies.filter { calendar.startOfDay(for: $0.date) >= start && $0.date <= now }
        let low = recent.filter { $0.energy <= 2 }.count
        let trained = trainingDays.filter { $0 >= start && $0 <= today }.count
        guard recent.count >= 5, low >= 5, low * 2 >= recent.count, trained >= 8 else { return nil }
        return LowEnergyWarning(lowDays: low, checkIns: recent.count, trainingDays: trained)
    }

    /// The athlete can hide the card for a week.
    static let snoozeKey = "safety.lowEnergySnoozedUntil"

    public static var isSnoozed: Bool {
        UserDefaults.standard.double(forKey: snoozeKey) > Date.now.timeIntervalSince1970
    }

    public static func snoozeForAWeek() {
        UserDefaults.standard.set(Date.now.addingTimeInterval(7 * 86_400).timeIntervalSince1970, forKey: snoozeKey)
    }

    public static let advice = [
        "Eat three proper meals and a snack before and after training — every day, not only on game days.",
        "Carbs are fuel: rice, pasta, bread, potatoes, fruit. Hard training needs more of them, not less.",
        "Sleep 8–10 hours. Tiredness adds up.",
        "Talk to a parent, your coach or athletic trainer, or a doctor — especially if you've lost weight, feel dizzy, get injured or ill often, or (for girls) your period has become irregular or stopped.",
    ]
}

// MARK: - Concussion

/// The graduated return to sport after a concussion, as in the 2023
/// Amsterdam international consensus and the CDC's HEADS UP guidance.
public enum ConcussionGuide {
    public struct Step: Sendable, Equatable {
        public let number: Int
        public let title: String
        public let what: String
        public let goal: String
    }

    public static let steps: [Step] = [
        Step(number: 1, title: "Everyday activity that doesn't make symptoms worse",
             what: "Normal daily things like walking around the house and short, easy walks. Screen time and school in small amounts.",
             goal: "Slowly get back to normal days."),
        Step(number: 2, title: "Light exercise",
             what: "Walking or an exercise bike at an easy to medium pace. No weights, no jumping, no contact.",
             goal: "Raise the heart rate a little."),
        Step(number: 3, title: "Sport-specific exercise",
             what: "Running or skating drills on your own. No head impact, no heading, no contact.",
             goal: "Add movement."),
        Step(number: 4, title: "Non-contact training drills",
             what: "Harder training drills like passing, and weights. Still no contact.",
             goal: "Exercise, coordination and thinking together."),
        Step(number: 5, title: "Full-contact practice — only after a doctor clears you",
             what: "Normal training with contact, once a doctor has cleared you (in writing, where your school requires it).",
             goal: "Get confidence back; coaches check your skills."),
        Step(number: 6, title: "Back to games",
             what: "Normal games.",
             goal: "Playing again."),
    ]

    public static let rules = [
        "Each step takes at least 24 hours.",
        "If symptoms come back or get worse, stop and go back to the step before once they settle.",
        "Get back to school first: most athletes return to full school days before full contact.",
        "Never go back to contact or games until a doctor has cleared you.",
    ]

    public static let rightAway = [
        "Stop playing straight away — don't finish the game or practice.",
        "Tell your coach, athletic trainer or a parent.",
        "No more sport that day, even if you feel fine.",
        "See a doctor.",
        "When in doubt, sit it out.",
    ]

    /// Signs that need emergency help (call your local emergency number).
    public static let emergency = [
        "A headache that gets worse and won't go away",
        "Throwing up more than once",
        "A seizure, or passing out",
        "Weakness, numbness, or trouble with balance or coordination",
        "Slurred speech, confusion or not recognising people or places",
        "Getting more and more drowsy, or can't be woken up",
        "One pupil bigger than the other",
        "Neck pain or tenderness",
    ]

    public static let source = "Based on the Amsterdam International Consensus Statement on Concussion in Sport (2023) and the CDC's HEADS UP program. This explains the usual steps — your doctor or athletic trainer decides."

    static let stepKey = "safety.concussionStep"

    /// The step the athlete's doctor or trainer said they're on (for their own reference).
    public static var currentStep: Int {
        get { max(1, min(6, UserDefaults.standard.integer(forKey: stepKey))) }
        set { UserDefaults.standard.set(newValue, forKey: stepKey) }
    }
}

/// The Safety Center (Me → Safety Center): what to do when something doesn't
/// feel right. Short and plain — it explains, it never diagnoses.
public enum SafetyTopic: String, CaseIterable, Identifiable, Sendable {
    case pain, headInjury, whenToStop, afterIllness, talkToAdult

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pain: "Pain"
        case .headInjury: "Head injury"
        case .whenToStop: "When to stop training"
        case .afterIllness: "Returning after illness"
        case .talkToAdult: "Talk to an adult"
        }
    }

    public var summary: String {
        switch self {
        case .pain: "Soreness is normal. Pain is a signal."
        case .headInjury: "When in doubt, sit it out."
        case .whenToStop: "Signs to stop straight away."
        case .afterIllness: "Coming back without a setback."
        case .talkToAdult: "Who to tell, and when."
        }
    }

    public var systemImage: String {
        switch self {
        case .pain: "bandage.fill"
        case .headInjury: "brain.head.profile"
        case .whenToStop: "hand.raised.fill"
        case .afterIllness: "thermometer.medium"
        case .talkToAdult: "person.2.fill"
        }
    }

    public var points: [String] {
        switch self {
        case .pain: [
            "Muscle soreness a day or two after hard training is normal and fades.",
            "Pain that is sharp, in a joint or bone, makes you limp, or gets worse as you train is different: stop that exercise.",
            "Swelling, a pop, numbness or tingling: stop training and tell an adult today.",
            "Pain that lasts more than a few days, or wakes you at night, needs a doctor or athletic trainer.",
            "Report pain in the morning check-in and today's training gets lighter.",
        ]
        case .headInjury: ConcussionGuide.rightAway
        case .whenToStop: [
            "Chest pain, trouble breathing, or feeling faint or dizzy.",
            "Sharp pain, a pop, or a joint that gives way.",
            "Any knock to the head, even if you feel fine.",
            "Feeling hot, confused or sick in the heat: stop, cool down and drink.",
            "In an emergency, call your local emergency number.",
        ]
        case .afterIllness: [
            "Fever, body aches or a stomach bug: no training until you've had no fever for 24 hours without medicine.",
            "Just a head cold? Light training can be fine. Stop if you feel worse.",
            "Come back with a few lighter days before full training.",
            "Set your day to Sick / Rest on Home and the plan backs off.",
            "Chest pain, a racing heart or unusual breathlessness after being ill: see a doctor before training.",
        ]
        case .talkToAdult: [
            "Coaches, athletic trainers, parents and school nurses are there to help. Telling them is the smart move.",
            "Tell someone about pain, a head knock, feeling low for a long time, or anything that worries you.",
            "Struggling or thinking about hurting yourself? Talk to someone now: a parent, a trusted adult, or your local emergency number.",
        ]
        }
    }

    /// Said once, here — not on every screen.
    public static let disclaimer = "AthleteOS gives general guidance, not medical advice, and can't diagnose anything. A doctor, athletic trainer or parent decides. In an emergency, call your local emergency number."
}

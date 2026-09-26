import Foundation

/// The athlete's weekly practice days, set once on Home. Workouts are built
/// around them: a short session after practice, a full gym day on days
/// without practice.
public enum PracticeSchedule {
    private static let key = "schedule.practiceWeekdays"
    private static let setKey = "schedule.isSet"

    /// Calendar weekdays (1 = Sunday … 7 = Saturday) with team practice.
    public static var weekdays: Set<Int> {
        get { Set((UserDefaults.standard.array(forKey: key) as? [Int]) ?? []) }
        set {
            UserDefaults.standard.set(newValue.sorted(), forKey: key)
            UserDefaults.standard.set(true, forKey: setKey)
        }
    }

    /// Whether the athlete has told us their practice days yet (or
    /// connected a calendar that has them).
    public static var isSet: Bool { UserDefaults.standard.bool(forKey: setKey) || !ScheduleStore.feeds.isEmpty }

    /// A connected team calendar decides first (a cancelled practice is no
    /// practice); weeks it says nothing about use the practice days.
    public static func hasPractice(on date: Date, calendar: Calendar = .current) -> Bool {
        if let confirmed = PracticeOverride.hasPractice(on: DayKey.of(date, calendar: calendar)) { return confirmed }
        if !ExtraPractices.on(DayKey.of(date, calendar: calendar)).isEmpty { return true }
        return ScheduleStore.imported.practiceStatus(on: date, calendar: calendar)
            ?? weekdays.contains(calendar.component(.weekday, from: date))
    }

    /// When practice is on that day, if the athlete told us.
    public static func time(on date: Date, calendar: Calendar = .current) -> PracticeTime? {
        if let extra = ExtraPractices.on(DayKey.of(date, calendar: calendar)).first?.time { return extra }
        return PracticeTimes.all[calendar.component(.weekday, from: date)]
    }
}

/// The kinds of workout Home builds.
public enum WorkoutMode: String, Sendable {
    /// Short and low-volume, after team practice: strength and injury
    /// prevention, never more running or jumping on tired legs.
    case afterPractice
    /// No practice today: the full planned gym session.
    case gymDay
    /// Every day: 10 minutes of mobility and breathing.
    case mobility
    /// A travel day: 15 minutes, no equipment, anywhere.
    case travel

    public var title: String {
        switch self {
        case .afterPractice: "After-practice workout"
        case .gymDay: "Gym day"
        case .mobility: "Mobility & movement prep"
        case .travel: "Travel workout"
        }
    }

    public var explanation: String {
        switch self {
        case .afterPractice: "Practice already trained your sport. This adds strength and injury prevention — short, so you still recover."
        case .gymDay: "No practice today, so this is your main strength and power session."
        case .mobility: "Loosen up for your sport, then calm down with slow breathing."
        case .travel: "Keep the habit going in a hotel room or at home — no equipment needed."
        }
    }
}

/// What the builder needs to know about the athlete.
public struct WorkoutModeContext {
    public var catalogue: Catalogue
    public var sport: SportInfo?
    public var positionSlug: String?
    public var formatSlug: String?
    public var equipment: Set<String>
    public var trainsUnderCoach: Bool
    public var age: Int
    public var date: Date
    /// The athlete's development goals (Me → My Development Goals).
    public var struggles: [Struggle]

    public init(catalogue: Catalogue, sport: SportInfo?, positionSlug: String?, formatSlug: String?,
                equipment: Set<String>, trainsUnderCoach: Bool, age: Int, date: Date = .now, struggles: [Struggle] = []) {
        self.struggles = struggles
        self.catalogue = catalogue
        self.sport = sport
        self.positionSlug = positionSlug
        self.formatSlug = formatSlug
        self.equipment = equipment
        self.trainsUnderCoach = trainsUnderCoach
        self.age = age
        self.date = date
    }
}

/// Builds the after-practice, mobility and travel workouts from the library.
/// Each slot lists good exercises in order of preference; the first one the
/// athlete can do (equipment, coaching, age, sport) is used, rotated by day so
/// the same slot doesn't always get the same exercise.
public enum WorkoutModeBuilder {
    /// Injury-prevention exercises for the areas a sport loads most
    /// (a sport's `commonLoadAreas`).
    static let preventionByArea: [String: [String]] = {
        let hamstrings = ["nordic-hamstring-curl", "nordic-assisted-band", "hamstring-slider-curl", "single-leg-rdl"]
        let groin = ["copenhagen-plank", "adductor-squeeze", "clamshell"]
        let knees = ["spanish-squat", "eccentric-step-down", "split-squat-bottom-hold"]
        let ankles = ["standing-calf-raise", "tibialis-raise", "single-leg-balance-eyes-closed"]
        let shoulders = ["band-external-rotation", "face-pull", "prone-y-t-w-raise", "push-up-plus"]
        let back = ["bird-dog", "dead-bug", "side-plank", "superman-hold"]
        let neck = ["neck-isometrics", "chin-tuck"]
        let wrists = ["band-wrist-extension", "wrist-roller", "plate-pinch"]
        return [
            "hamstrings": hamstrings, "groin": groin, "hips": groin, "hip-flexors": groin,
            "knees": knees, "knee": knees, "front-knee": knees,
            "ankles": ankles, "shins": ankles, "achilles": ankles,
            "shoulder": shoulders, "shoulders": shoulders, "elbow": shoulders, "elbows": shoulders, "upper-back": shoulders,
            "lower-back": back, "neck": neck,
            "wrists": wrists, "wrist": wrists, "lead-wrist": wrists, "forearms": wrists, "fingers": wrists,
        ]
    }()

    static let lowerStrength = ["split-squat", "bulgarian-split-squat", "reverse-lunge", "step-up", "goblet-squat", "kickstand-rdl", "single-leg-glute-bridge", "bodyweight-squat"]
    static let upperPull = ["inverted-row", "dumbbell-row", "chin-up", "pull-up", "towel-row", "prone-y-t-w-raise"]
    static let upperPush = ["push-up", "push-up-plus", "dumbbell-bench-press", "overhead-press-dumbbell", "incline-push-up"]
    static let core = ["dead-bug", "pallof-press", "side-plank", "bird-dog", "plank-shoulder-tap", "hollow-hold"]
    static let mobilityBase = ["worlds-greatest-stretch", "90-90-hip-switch", "thoracic-open-book", "ankle-knee-to-wall"]
    static let mobilityByArea: [String: String] = [
        "shoulder": "sleeper-stretch", "shoulders": "shoulder-dislocates-band", "elbow": "sleeper-stretch",
        "hamstrings": "hamstring-floss", "hip-flexors": "couch-stretch", "knees": "couch-stretch", "hips": "pigeon-stretch",
        "groin": "cossack-squat", "lower-back": "cat-camel", "upper-back": "thoracic-open-book", "ankles": "deep-squat-hold",
    ]
    static let travel = ["bodyweight-squat", "push-up", "split-squat", "single-leg-glute-bridge", "dead-bug", "side-plank", "worlds-greatest-stretch"]

    /// The athlete's own version of this workout when they made one,
    /// otherwise the one built for today.
    public static func build(_ mode: WorkoutMode, _ context: WorkoutModeContext) -> GeneratedSession? {
        if let mine = PlanCustomizationStore.load().workout(for: .mode(mode)), !mine.items.isEmpty {
            return mine.session(date: context.date, catalogue: context.catalogue)
        }
        return standard(mode, context)
    }

    /// The workout the app builds for this mode, ignoring the athlete's edits.
    public static func standard(_ mode: WorkoutMode, _ context: WorkoutModeContext) -> GeneratedSession? {
        var used: Set<String> = []
        var picks: [(CatalogueItem, String)] = []
        let rotation = Calendar.current.ordinality(of: .day, in: .era, for: context.date) ?? 0

        func pick(_ slugs: [String], why: String, rotate: Bool = true) {
            let candidates = slugs.compactMap { context.catalogue.item($0) }.filter { Self.usable($0, context) && !used.contains($0.slug) }
            guard !candidates.isEmpty else { return }
            let item = candidates[rotate ? rotation % candidates.count : 0]
            used.insert(item.slug)
            picks.append((item, why))
        }

        let areas = context.sport?.commonLoadAreas ?? []
        switch mode {
        case .afterPractice:
            pick(lowerStrength, why: "Single-leg strength: the base for sprinting, cutting and landing.")
            pick(rotation % 2 == 0 ? upperPull : upperPush, why: rotation % 2 == 0
                 ? "Pulling strength balances all the pushing and throwing in sport."
                 : "Upper-body pushing strength, kept to a moderate dose after practice.")
            // The first two *different* prevention groups the sport's load areas point to.
            var groups: [(area: String, slugs: [String])] = []
            for area in areas {
                guard let slugs = preventionByArea[area], !groups.contains(where: { $0.slugs == slugs }) else { continue }
                groups.append((area, slugs))
                if groups.count == 2 { break }
            }
            for group in groups {
                pick(group.slugs, why: "Protects your \(group.area.replacingOccurrences(of: "-", with: " ")), which your sport loads a lot.", rotate: false)
            }
            if picks.count < 4 { pick(preventionByArea["hamstrings"] ?? [], why: "Hamstring strength is one of the best-proven injury protections.", rotate: false) }
            pick(core, why: "A trunk that resists twisting passes force from legs to arms.")
            // One exercise for what the athlete wants to fix.
            if let quality = Struggles.topQuality(context.struggles), let struggle = context.struggles.first(where: { $0.boosts[quality] != nil }) {
                let matches = context.catalogue.itemsBySlug.values
                    .filter { ($0.qualities[quality] ?? 0) >= 0.6 && $0.kind == "exercise" }
                    .sorted { ($0.qualities[quality] ?? 0) != ($1.qualities[quality] ?? 0) ? ($0.qualities[quality] ?? 0) > ($1.qualities[quality] ?? 0) : $0.slug < $1.slug }
                    .map(\.slug)
                pick(Array(matches.prefix(8)), why: "For your goal: \(struggle.title.lowercased()).")
            }
        case .mobility:
            for slug in mobilityBase { pick([slug], why: "Keeps hips, spine and ankles moving freely.") }
            for area in areas.prefix(2) {
                if let slug = mobilityByArea[area] { pick([slug], why: "Loosens your \(area.replacingOccurrences(of: "-", with: " ")).") }
            }
            if context.struggles.contains(.mobility) {
                pick(["couch-stretch", "pigeon-stretch", "hamstring-floss", "cossack-squat"], why: "Extra range for your mobility goal.")
            }
            pick(["breathing-90-90"], why: "Slow breathing switches your body into recovery mode.")
        case .travel:
            for slug in travel { pick([slug], why: "No equipment, anywhere.") }
        case .gymDay:
            return nil
        }
        guard !picks.isEmpty else { return nil }

        let youth = context.age < 18
        let items = picks.enumerated().map { index, pair -> GeneratedPlannedItem in
            let (item, why) = pair
            var dose = PlanGenerator.clampedDose(item.defaultDose, isYouthEnvelope: youth)
            // Short sessions: at most 2 sets (after practice, on travel days, and relaxed mobility rounds).
            dose.sets = min(dose.sets, 2)
            return GeneratedPlannedItem(itemSlug: item.slug, order: index, dose: dose,
                                        restSec: mode == .mobility ? 15 : min(item.restSeconds, 75),
                                        rationale: why, quality: item.primaryQuality?.id ?? "")
        }
        let seconds = items.reduce(0) { total, item in
            let work = item.dose.seconds ?? max(30, (item.dose.reps ?? 8) * 4)
            return total + item.dose.sets * (work + item.restSec)
        }
        return GeneratedSession(date: context.date, title: mode.title,
                                focusQualities: picks.compactMap { $0.0.primaryQuality?.id },
                                estimatedMinutes: max(8, Int((Double(seconds) / 60).rounded())), items: items)
    }

    static func usable(_ item: CatalogueItem, _ context: WorkoutModeContext) -> Bool {
        item.fits(sport: context.sport?.slug, position: context.positionSlug, format: context.formatSlug)
            && PlanGenerator.isEligibleForEquipment(item, available: context.equipment)
            && (context.trainsUnderCoach || !item.isCoached)
            && item.minAge <= context.age
            && item.defaultDose.kind != "contacts"
    }
}

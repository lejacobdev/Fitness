import Foundation

/// The Mindset level: a 2-minute evening reflection ("one win, one
/// lesson"), season goals turned into one concrete focus point a week, and
/// the pre-game routines (breathing, visualization). Everything is kept in
/// UserDefaults under `mindset.` so it is backed up with the athlete's
/// settings (CloudSync) and comes back on a new phone.

/// One evening's reflection.
public struct Reflection: Codable, Sendable, Equatable, Identifiable {
    /// The calendar day, YYYY-MM-DD.
    public var day: String
    public var win: String
    public var lesson: String
    /// 1 (rough day) … 5 (great day), optional.
    public var feeling: Int?
    // The evening check-in (V3): mostly taps, one optional sentence.
    /// How hard was today: 1 easy … 4 very hard.
    public var hardness: Int?
    /// How the body feels: 1 fresh … 4 very sore.
    public var body: Int?
    /// How practice went: 1 tough … 4 great (nil: no practice).
    public var practice: Int?
    public var wentWell: [String]?
    public var needsWork: [String]?
    /// "What did you learn today?" — the one optional written answer.
    public var learned: String?
    public var id: String { day }
}

/// Tap answers for the evening check-in.
public enum EveningOptions {
    public static let hardness = ["Easy", "Moderate", "Hard", "Very hard"]
    public static let body = ["Fresh", "Normal", "Tired", "Very sore"]
    public static let practice = ["Tough", "Okay", "Good", "Great"]
    public static let areas = ["Effort", "Focus", "Technique", "Speed", "Strength", "Decisions", "Communication", "Confidence", "Recovery"]
}

/// What a season goal is about — decides the kind of weekly focus it gets.
public enum GoalArea: String, Codable, Sendable, CaseIterable, Identifiable {
    case performance, skill, fitness, health, confidence, team, school

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .performance: "Results"
        case .skill: "A skill"
        case .fitness: "Strength & speed"
        case .health: "Stay healthy"
        case .confidence: "Confidence & nerves"
        case .team: "Team & leadership"
        case .school: "School & balance"
        }
    }

    public var systemImage: String {
        switch self {
        case .performance: "trophy.fill"
        case .skill: "target"
        case .fitness: "bolt.fill"
        case .health: "heart.fill"
        case .confidence: "brain.head.profile"
        case .team: "person.3.fill"
        case .school: "book.closed.fill"
        }
    }

    /// Example goals, so nobody stares at an empty text field.
    public var examples: [String] {
        switch self {
        case .performance: ["Make the starting line-up", "Qualify for the regional final", "Play every game this season"]
        case .skill: ["Shoot 40% from three", "Serve with no double faults", "Use my weaker foot in games"]
        case .fitness: ["Jump 5 cm higher", "Run a faster 30 m sprint", "Do 10 strict pull-ups"]
        case .health: ["Miss no games through injury", "Sleep 8+ hours on school nights", "Warm up properly every time"]
        case .confidence: ["Stay calm on big points", "Bounce back fast after mistakes", "Enjoy game days instead of dreading them"]
        case .team: ["Talk more on the field", "Help the new players settle in", "Be a captain people trust"]
        case .school: ["Keep my grades up during the season", "Hand every assignment in on time", "Study a little every day, not all at once"]
        }
    }

    /// Concrete one-week actions for goals in this area, rotated week by week.
    var focusPoints: [String] {
        switch self {
        case .performance: [
            "Before every practice, write down one thing you'll do better than last time.",
            "Ask your coach: what's the one thing that would get me more minutes?",
            "Watch 10 minutes of your own games or a pro in your position — note one habit to copy.",
            "Give 100% on the first rep of every drill this week, even the boring ones.",
            "Arrive 10 minutes early to every practice and use them to get ready properly.",
        ]
        case .skill: [
            "Do 10 extra minutes on this skill after 3 practices this week.",
            "Film yourself doing the skill once — compare it with a good example.",
            "Practise the skill slowly and perfectly first, then at game speed.",
            "Ask a coach or teammate for one tip on this skill, and use it all week.",
            "Use the skill under pressure: count your reps in a drill and try to beat it.",
        ]
        case .fitness: [
            "Do every planned gym workout this week — no skipping the last exercise.",
            "Log the weight or reps of your main exercise each time, and add a little.",
            "Sleep 8+ hours on at least 5 nights — that's when your body gets stronger.",
            "Eat protein at every meal this week (eggs, yogurt, meat, beans, tofu).",
            "Warm up properly before every sprint or jump session — no cold starts.",
        ]
        case .health: [
            "Do your 10 minutes of mobility on at least 5 days this week.",
            "Tell your coach or trainer about any pain that lasts more than a day.",
            "In bed by the same time on every school night this week.",
            "Drink water through the day, not only at practice — carry a bottle.",
            "Do the injury-prevention exercises in your plan every time they come up.",
        ]
        case .confidence: [
            "Pick a cue word (like \"Next\") and use it after every mistake this week.",
            "Do the 2-minute breathing before every game or hard practice.",
            "Each evening, write down one thing you did well — the reflection counts.",
            "Before your next game, do the visualization: see your first three plays going well.",
            "Catch negative self-talk once a day and change it to what you'd tell a teammate.",
        ]
        case .team: [
            "Say one encouraging thing to a teammate at every practice.",
            "Learn something about a teammate you don't usually talk to.",
            "Be loud and clear on the field: call for the ball, call the plays.",
            "After a loss or bad practice, be the first to say \"let's go again\".",
            "Help pack up the equipment after practice at least twice.",
        ]
        case .school: [
            "Plan your week on Sunday: practices, games, tests and homework in one place.",
            "Use one free period or bus ride a day for homework.",
            "Start your next big assignment 3 days earlier than you normally would.",
            "Tell your teachers about away games early, before you miss class.",
            "No phone in bed on school nights — sleep helps grades and games.",
        ]
        }
    }
}

public struct SeasonGoal: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var text: String
    public var area: GoalArea
    public var createdAt: Date

    public init(id: String = UUID().uuidString, text: String, area: GoalArea, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.area = area
        self.createdAt = createdAt
    }
}

/// This week's focus for one goal.
public struct FocusPoint: Sendable, Equatable, Identifiable {
    public let goal: SeasonGoal
    public let text: String
    public var id: String { goal.id }
}

public enum MindsetRoutine: String, Codable, Sendable {
    case breathing, visualization
}

public enum MindsetEngine {
    public static let maxGoals = 3

    /// One focus point per goal, changing every week and different for two
    /// goals in the same area.
    public static func weeklyFocus(goals: [SeasonGoal], weekStart: Date, calendar: Calendar = .current) -> [FocusPoint] {
        let week = calendar.component(.weekOfYear, from: weekStart) + calendar.component(.yearForWeekOfYear, from: weekStart) * 53
        return goals.prefix(maxGoals).enumerated().map { index, goal in
            let points = goal.area.focusPoints
            return FocusPoint(goal: goal, text: points[(week + index) % points.count])
        }
    }

    /// The Mindset level for a week: 5 evening reflections, every focus
    /// point done, and one pre-game routine — together "a full week".
    public static func weekProgress(reflectionDays: Int, focusDone: Int, focusTotal: Int, routines: Int) -> (done: Int, target: Int) {
        let target = 5 + focusTotal + 1
        let done = min(reflectionDays, 5) + min(focusDone, focusTotal) + min(routines, 1)
        return (done, target)
    }
}

/// Where the Mindset things live (backed up under `mindset.`).
public enum MindsetStore {
    static let reflectionsKey = "mindset.reflections"
    static let goalsKey = "mindset.goals"
    static let focusDoneKey = "mindset.focusDone"
    static let routinesKey = "mindset.routines"
    static let cueWordKey = "mindset.cueWord"

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func weekKey(_ date: Date, calendar: Calendar) -> String {
        dayKey(calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date, calendar: calendar)
    }

    // Reflections (the last 120 days are kept).

    public static var reflections: [Reflection] {
        get { load([Reflection].self, reflectionsKey) ?? [] }
        set { save(Array(newValue.sorted { $0.day > $1.day }.prefix(120)), reflectionsKey) }
    }

    public static func reflection(on date: Date, calendar: Calendar = .current) -> Reflection? {
        let key = dayKey(date, calendar: calendar)
        return reflections.first { $0.day == key }
    }

    public static func saveReflection(win: String, lesson: String, feeling: Int?, on date: Date = .now, calendar: Calendar = .current) {
        let key = dayKey(date, calendar: calendar)
        var all = reflections.filter { $0.day != key }
        all.append(Reflection(day: key, win: win, lesson: lesson, feeling: feeling))
        reflections = all
    }

    /// Saves the evening check-in. "What went well" and "what needs work"
    /// also become the win and lesson the Mindset page shows.
    public static func saveEvening(hardness: Int?, body: Int?, practice: Int?, wentWell: [String], needsWork: [String],
                                   learned: String?, on date: Date = .now, calendar: Calendar = .current) {
        let key = dayKey(date, calendar: calendar)
        var all = reflections.filter { $0.day != key }
        let note = learned?.trimmingCharacters(in: .whitespacesAndNewlines)
        all.append(Reflection(
            day: key,
            win: wentWell.isEmpty ? (note ?? "") : wentWell.joined(separator: ", "),
            lesson: needsWork.isEmpty ? "" : needsWork.joined(separator: ", "),
            feeling: practice.map { $0 + 1 }, hardness: hardness, body: body, practice: practice,
            wentWell: wentWell, needsWork: needsWork, learned: (note?.isEmpty ?? true) ? nil : note
        ))
        reflections = all
    }

    /// Last evening's answers, for today's plan (ADAPT).
    public static func yesterdaySignal(now: Date = .now, calendar: Calendar = .current) -> EveningSignal? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              let reflection = reflection(on: yesterday, calendar: calendar),
              reflection.hardness != nil || reflection.body != nil else { return nil }
        return EveningSignal(hardness: reflection.hardness, body: reflection.body)
    }

    /// Reflections in the week containing `date`.
    public static func reflectionDays(inWeekOf date: Date, calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let keys = Set((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }.map { dayKey($0, calendar: calendar) })
        return reflections.filter { keys.contains($0.day) }.count
    }

    /// Consecutive days with a reflection, ending today (or yesterday, so
    /// the streak doesn't look lost before this evening's).
    public static func reflectionStreak(now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(reflections.map(\.day))
        var day = days.contains(dayKey(now, calendar: calendar)) ? now : (calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        var streak = 0
        while days.contains(dayKey(day, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // Goals and weekly focus.

    public static var goals: [SeasonGoal] {
        get { load([SeasonGoal].self, goalsKey) ?? [] }
        set { save(Array(newValue.prefix(MindsetEngine.maxGoals)), goalsKey) }
    }

    /// Goal ids whose focus point is done, per week.
    private static var focusDone: [String: [String]] {
        get { load([String: [String]].self, focusDoneKey) ?? [:] }
        set {
            // Keep the last ~12 weeks.
            let kept = newValue.keys.sorted().suffix(12)
            save(newValue.filter { kept.contains($0.key) }, focusDoneKey)
        }
    }

    public static func isFocusDone(_ goalID: String, week date: Date = .now, calendar: Calendar = .current) -> Bool {
        focusDone[weekKey(date, calendar: calendar)]?.contains(goalID) ?? false
    }

    public static func setFocusDone(_ goalID: String, _ done: Bool, week date: Date = .now, calendar: Calendar = .current) {
        let key = weekKey(date, calendar: calendar)
        var all = focusDone
        var ids = Set(all[key] ?? [])
        if done { ids.insert(goalID) } else { ids.remove(goalID) }
        all[key] = ids.sorted()
        focusDone = all
    }

    // Pre-game routines.

    private static var routineLog: [String: [String]] {
        get { load([String: [String]].self, routinesKey) ?? [:] }
        set {
            let kept = newValue.keys.sorted().suffix(60)
            save(newValue.filter { kept.contains($0.key) }, routinesKey)
        }
    }

    public static func logRoutine(_ routine: MindsetRoutine, on date: Date = .now, calendar: Calendar = .current) {
        var all = routineLog
        all[dayKey(date, calendar: calendar), default: []].append(routine.rawValue)
        routineLog = all
    }

    public static func routines(inWeekOf date: Date, calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let keys = Set((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }.map { dayKey($0, calendar: calendar) })
        return routineLog.filter { keys.contains($0.key) }.reduce(0) { $0 + $1.value.count }
    }

    /// The word the athlete says to reset after a mistake.
    public static var cueWord: String {
        get { UserDefaults.standard.string(forKey: cueWordKey) ?? "Next" }
        set { UserDefaults.standard.set(newValue, forKey: cueWordKey) }
    }

    /// This week's Mindset level.
    public static func weekProgress(now: Date = .now, calendar: Calendar = .current) -> (done: Int, target: Int) {
        let focus = MindsetEngine.weeklyFocus(goals: goals, weekStart: now, calendar: calendar)
        return MindsetEngine.weekProgress(
            reflectionDays: reflectionDays(inWeekOf: now, calendar: calendar),
            focusDone: focus.filter { isFocusDone($0.goal.id, week: now, calendar: calendar) }.count,
            focusTotal: focus.count,
            routines: routines(inWeekOf: now, calendar: calendar)
        )
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

// MARK: - Pre-game routines

/// Guided breathing. "Calm" (in 4, out 6: a long exhale slows the heart and
/// settles nerves) for before a game; "Focus" (box breathing, 4-4-4-4) to
/// lock in.
public enum BreathingPattern: String, CaseIterable, Sendable, Identifiable {
    case calm, focus

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .calm: "Calm down"
        case .focus: "Lock in"
        }
    }

    public var explanation: String {
        switch self {
        case .calm: "Breathe in for 4, out slowly for 6. The long breath out slows your heart and settles nerves."
        case .focus: "Box breathing: in 4, hold 4, out 4, hold 4. Used by athletes to get calm and sharp at the same time."
        }
    }

    /// (what to do, seconds, lungs filling up?) for one breath.
    public var phases: [(label: String, seconds: Double, expand: Bool)] {
        switch self {
        case .calm: [("Breathe in", 4, true), ("Breathe out slowly", 6, false)]
        case .focus: [("Breathe in", 4, true), ("Hold", 4, true), ("Breathe out", 4, false), ("Hold", 4, false)]
        }
    }

    public var cycleSeconds: Double { phases.reduce(0) { $0 + $1.seconds } }

    /// The phase at `elapsed` seconds into the exercise.
    public func phase(at elapsed: Double) -> (index: Int, label: String, progress: Double, expand: Bool) {
        var t = elapsed.truncatingRemainder(dividingBy: cycleSeconds)
        for (index, phase) in phases.enumerated() {
            if t < phase.seconds { return (index, phase.label, t / phase.seconds, phase.expand) }
            t -= phase.seconds
        }
        let last = phases[phases.count - 1]
        return (phases.count - 1, last.label, 1, last.expand)
    }
}

/// The game-day visualization, step by step.
public struct VisualizationStep: Sendable, Equatable {
    public let title: String
    public let text: String
    public let seconds: Int
}

public enum GameDayVisualization {
    public static func steps(sportName: String, cueWord: String) -> [VisualizationStep] {
        let place = sportName.isEmpty ? "where you play" : "where you play \(sportName.lowercased())"
        return [
            VisualizationStep(title: "Get comfortable", text: "Sit or lie down somewhere quiet. Close your eyes. Take three slow breaths, longer out than in.", seconds: 25),
            VisualizationStep(title: "See the place", text: "Picture \(place): the lights, the sounds, the smell, your teammates, the crowd. Make it as real as you can.", seconds: 40),
            VisualizationStep(title: "Your warm-up", text: "Feel yourself warming up: loose, quick, strong. Your body is ready.", seconds: 30),
            VisualizationStep(title: "Your first three plays", text: "See yourself doing your first three actions well — through your own eyes, at real speed. Feel the ball, the ground, your breath.", seconds: 60),
            VisualizationStep(title: "A mistake, and your reset", text: "Now something goes wrong. See it. Take one breath, say \"\(cueWord)\" in your head, and see yourself doing the very next play well.", seconds: 45),
            VisualizationStep(title: "Your best moment", text: "Picture the play you want to make today. See it, feel it, hear it. Enjoy it.", seconds: 40),
            VisualizationStep(title: "Ready", text: "Take one last deep breath. Say \"\(cueWord)\". Open your eyes — you've already played it once. Go play.", seconds: 15),
        ]
    }
}

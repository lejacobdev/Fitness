import Foundation

/// Benchmark tests every 6–8 weeks: the same few simple tests, done the
/// same way each time, so the athlete sees real improvement — jump height,
/// 10 m / 30 m sprint, plank, push-ups, and one test for their sport.
/// Results are kept under `benchmark.` (backed up with the settings).

public enum BenchmarkUnit: String, Codable, Sendable {
    case centimeters, seconds, reps, outOf10

    public func format(_ value: Double) -> String {
        switch self {
        case .centimeters: "\(Int(value.rounded())) cm"
        case .seconds: value >= 100 ? Self.minutes(value) : String(format: "%.2f s", value)
        case .reps: "\(Int(value.rounded()))"
        case .outOf10: "\(Int(value.rounded()))/10"
        }
    }

    /// A change, said the way an athlete would ("3 cm higher", "0.12 s faster").
    public func formatChange(_ delta: Double, higherIsBetter: Bool) -> String {
        let better = higherIsBetter ? delta > 0 : delta < 0
        let size = abs(delta)
        switch self {
        case .centimeters: return "\(Int(size.rounded())) cm \(better ? "higher" : "lower")"
        case .seconds:
            let amount = size >= 100 ? Self.minutes(size) : String(format: "%.2f s", size)
            return "\(amount) \(better ? "faster" : "slower")"
        case .reps: return "\(better ? "+" : "−")\(Int(size.rounded()))"
        case .outOf10: return "\(better ? "+" : "−")\(Int(size.rounded())) of 10"
        }
    }

    private static func minutes(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// How a test is measured in the app.
public enum BenchmarkRunner: String, Codable, Sendable {
    /// A slow-motion video, then the take-off and landing frames.
    case jumpVideo
    /// A partner's stopwatch: start, a split at 10 m, stop at 30 m.
    case sprintStopwatch
    /// A stopwatch (holds, timed runs).
    case stopwatch
    /// A big tap counter.
    case counter
    /// Measured another way (tape measure, a machine): typed in.
    case entry
}

public struct BenchmarkTest: Identifiable, Sendable, Equatable {
    public enum Level: String, Sendable { case body, sport }

    public let id: String
    public let name: String
    public let level: Level
    public let unit: BenchmarkUnit
    public let higherIsBetter: Bool
    public let runner: BenchmarkRunner
    public let systemImage: String
    /// How to do it, the same way every time.
    public let howTo: [String]
    /// A counted test with a time limit ("in 60 s") gets a countdown.
    public var timeLimit: Int? = nil
}

public enum BenchmarkCatalog {
    public static let jump = BenchmarkTest(
        id: "jump", name: "Vertical jump", level: .body, unit: .centimeters, higherIsBetter: true, runner: .jumpVideo,
        systemImage: "arrow.up.to.line",
        howTo: [
            "Hands on hips the whole time — no arm swing, so every test is the same.",
            "Dip and jump straight up as high as you can. Land on both feet with straight legs, then bend.",
            "Have someone film your feet from the side with the phone on the floor or at knee height, in Slo-mo if they can.",
            "Do 3 jumps with a minute's rest; the best one counts.",
        ]
    )
    public static let sprint10 = BenchmarkTest(
        id: "sprint10", name: "10 m sprint", level: .body, unit: .seconds, higherIsBetter: false, runner: .sprintStopwatch,
        systemImage: "hare.fill",
        howTo: [
            "Mark 0, 10 and 30 m on a flat track or field.",
            "Start standing, front foot on the line. A partner at the side taps Go on your first movement.",
            "They tap 10 m as you pass it and Stop at 30 m — one run gives both times.",
            "Warm up properly first. Two runs, 3 minutes' rest; the best counts.",
        ]
    )
    public static let sprint30 = BenchmarkTest(
        id: "sprint30", name: "30 m sprint", level: .body, unit: .seconds, higherIsBetter: false, runner: .sprintStopwatch,
        systemImage: "figure.run",
        howTo: [
            "Timed in the same run as the 10 m sprint.",
            "Run all the way through the 30 m line — don't slow down before it.",
        ]
    )
    public static let plank = BenchmarkTest(
        id: "plank", name: "Plank hold", level: .body, unit: .seconds, higherIsBetter: true, runner: .stopwatch,
        systemImage: "figure.core.training",
        howTo: [
            "Forearms and toes, body in one straight line from head to heels.",
            "Start the clock when you're in position; stop when your hips sag or rise and you can't fix it.",
            "Once, fresh — not after a workout.",
        ]
    )
    public static let pushUps = BenchmarkTest(
        id: "pushups", name: "Push-ups", level: .body, unit: .reps, higherIsBetter: true, runner: .counter,
        systemImage: "figure.strengthtraining.functional",
        howTo: [
            "As many as you can with good form: chest to a fist's height from the floor, arms straight at the top, body straight.",
            "Tap the counter (or have a partner count). Stop when your form breaks.",
            "Do them from the knees if full push-ups aren't possible yet — and always test the same way.",
        ]
    )

    public static let body: [BenchmarkTest] = [jump, sprint10, sprint30, plank, pushUps]

    private static func sport(_ slug: String, _ name: String, _ unit: BenchmarkUnit, higher: Bool, _ runner: BenchmarkRunner,
                              _ icon: String, limit: Int? = nil, _ howTo: [String]) -> BenchmarkTest {
        BenchmarkTest(id: "sport.\(slug)", name: name, level: .sport, unit: unit, higherIsBetter: higher, runner: runner,
                      systemImage: icon, howTo: howTo, timeLimit: limit)
    }

    private static func proAgility(_ slug: String) -> BenchmarkTest {
        sport(slug, "Pro agility shuttle (5-10-5)", .seconds, higher: false, .stopwatch, "arrow.left.arrow.right", [
            "Three lines 5 m apart. Start straddling the middle line.",
            "Sprint 5 m to one side and touch the line, 10 m to the other and touch it, then 5 m back through the middle.",
            "A partner times from your first move to crossing the middle. Two tries; the best counts.",
        ])
    }
    private static func longJump(_ slug: String) -> BenchmarkTest {
        sport(slug, "Standing long jump", .centimeters, higher: true, .entry, "arrow.right.to.line", [
            "Toes behind a line, feet shoulder-width. Swing your arms and jump forward as far as you can.",
            "Land on both feet and hold it. Measure from the line to the back of your nearest heel.",
            "Three jumps; the best counts. Type the distance in cm.",
        ])
    }
    private static func wallSit(_ slug: String) -> BenchmarkTest {
        sport(slug, "Wall sit", .seconds, higher: true, .stopwatch, "figure.strengthtraining.traditional", [
            "Back flat against a wall, thighs parallel to the floor, knees over ankles.",
            "Hold as long as you can. Stop when you have to stand up.",
        ])
    }

    /// One test per sport, measured with a phone and little else. Sports
    /// without their own fall back to the pro agility shuttle.
    public static func sportTest(for sportSlug: String) -> BenchmarkTest {
        switch sportSlug {
        case "football", "flag-football", "field-hockey", "rugby": return proAgility(sportSlug)
        case "track-and-field", "indoor-track-and-field", "weightlifting": return longJump(sportSlug)
        case "basketball":
            return sport(sportSlug, "Free throws", .outOf10, higher: true, .counter, "basketball.fill", [
                "10 free throws after a normal warm-up, same routine every shot.",
                "Count how many go in.",
            ])
        case "soccer":
            return sport(sportSlug, "Juggling", .reps, higher: true, .counter, "soccerball", [
                "Keep the ball up with feet, thighs and head. Count every touch until it drops.",
                "Best of three tries.",
            ])
        case "volleyball":
            return sport(sportSlug, "Serves in", .outOf10, higher: true, .counter, "volleyball.fill", [
                "10 serves from behind the end line, your normal game serve.",
                "Count how many land in the court.",
            ])
        case "tennis":
            return sport(sportSlug, "First serves in", .outOf10, higher: true, .counter, "tennis.racket", [
                "10 first serves at full game pace, 5 to each service box.",
                "Count how many land in.",
            ])
        case "badminton":
            return sport(sportSlug, "Court corners in 30 s", .reps, higher: true, .counter, "figure.badminton", limit: 30, [
                "Start in the middle. Move to touch a corner of the court and back to the middle — that's one.",
                "Any corner order. Count how many in 30 seconds.",
            ])
        case "baseball", "softball":
            return sport(sportSlug, "Home to first", .seconds, higher: false, .stopwatch, "figure.baseball", [
                "Take your normal swing (or a dry swing) from the batter's box and run through first base.",
                "A partner times from the swing to your foot hitting the bag. Two tries.",
            ])
        case "cross-country":
            return sport(sportSlug, "1.6 km (1 mile) run", .seconds, higher: false, .stopwatch, "figure.run", [
                "Four laps of a 400 m track (or a measured flat route).",
                "Warm up first, then run it as fast as you can hold. Stop the clock at the finish.",
            ])
        case "swimming-diving":
            return sport(sportSlug, "50 m freestyle", .seconds, higher: false, .stopwatch, "figure.pool.swim", [
                "Push-off start, 50 m freestyle at full effort.",
                "A partner times from the push-off to your touch.",
            ])
        case "water-polo":
            return sport(sportSlug, "Eggbeater, hands up", .seconds, higher: true, .stopwatch, "figure.water.fitness", [
                "In deep water, eggbeater with both hands out of the water above your head.",
                "Stop the clock when your hands touch the water.",
            ])
        case "golf":
            return sport(sportSlug, "Putts from 2 m", .outOf10, higher: true, .counter, "figure.golf", [
                "10 putts from 2 m (about 6 ft), around the hole.",
                "Count how many drop.",
            ])
        case "bowling":
            return sport(sportSlug, "Single-pin spares", .outOf10, higher: true, .counter, "figure.bowling", [
                "10 shots at a single corner pin (7 or 10), alternating.",
                "Count how many you knock down.",
            ])
        case "lacrosse":
            return sport(sportSlug, "Wall ball in 60 s", .reps, higher: true, .counter, "figure.lacrosse", limit: 60, [
                "Stand 3–4 m from a wall. Throw and catch as fast as you can, strong hand.",
                "Count clean catches in 60 seconds.",
            ])
        case "wrestling":
            return sport(sportSlug, "Burpees in 60 s", .reps, higher: true, .counter, "figure.wrestling", limit: 60, [
                "Chest to the floor, jump at the top with hands overhead.",
                "Count full burpees in 60 seconds.",
            ])
        case "competitive-spirit":
            return sport(sportSlug, "Tuck jumps in 30 s", .reps, higher: true, .counter, "figure.jumprope", limit: 30, [
                "Knees to chest, land softly each time.",
                "Count good tuck jumps in 30 seconds.",
            ])
        case "gymnastics":
            return sport(sportSlug, "Hollow hold", .seconds, higher: true, .stopwatch, "figure.gymnastics", [
                "On your back, lower back pressed into the floor, arms and legs straight and off the floor.",
                "Stop when your lower back lifts.",
            ])
        case "ice-hockey":
            return sport(sportSlug, "Skater hops in 30 s", .reps, higher: true, .counter, "figure.hockey", limit: 30, [
                "Jump sideways from one leg to the other over about 1 m, landing balanced each time.",
                "Count landings in 30 seconds.",
            ])
        case "rowing":
            return sport(sportSlug, "500 m on the rowing machine", .seconds, higher: false, .entry, "figure.rower", [
                "Damper at your normal setting, after a warm-up.",
                "Row 500 m as fast as you can; the machine's time counts.",
            ])
        case "skiing", "mountain-biking": return wallSit(sportSlug)
        case "snowboarding", "unified-sports":
            return sport(sportSlug, "One-leg balance", .seconds, higher: true, .stopwatch, "figure.stand", [
                "Stand on one leg, other foot off the floor, hands on hips.",
                "Stop the clock when the other foot touches down or you hop. Up to 60 s; test both legs and keep the lower one.",
            ])
        default: return proAgility(sportSlug)
        }
    }

    public static func tests(for sportSlug: String?) -> [BenchmarkTest] {
        body + (sportSlug.map { [sportTest(for: $0)] } ?? [])
    }
}

public struct BenchmarkResult: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var testID: String
    public var value: Double
    public var date: Date

    public init(id: String = UUID().uuidString, testID: String, value: Double, date: Date = .now) {
        self.id = id
        self.testID = testID
        self.value = value
        self.date = date
    }
}

public enum BenchmarkMath {
    /// Jump height from flight time (take-off to landing): h = g·t²/8.
    /// The method used by validated jump apps; needs the athlete to land
    /// the way they took off (straight legs).
    public static func jumpHeightCentimeters(flightTime: Double) -> Double {
        9.81 * flightTime * flightTime / 8 * 100
    }

    /// The latest result against the one before it.
    public static func change(_ results: [BenchmarkResult], test: BenchmarkTest)
        -> (latest: BenchmarkResult, previous: BenchmarkResult?, delta: Double?, improved: Bool?)? {
        let sorted = results.filter { $0.testID == test.id }.sorted { $0.date < $1.date }
        guard let latest = sorted.last else { return nil }
        guard sorted.count > 1 else { return (latest, nil, nil, nil) }
        let previous = sorted[sorted.count - 2]
        let delta = latest.value - previous.value
        return (latest, previous, delta, delta == 0 ? nil : (test.higherIsBetter ? delta > 0 : delta < 0))
    }

    /// The best result so far.
    public static func best(_ results: [BenchmarkResult], test: BenchmarkTest) -> BenchmarkResult? {
        let mine = results.filter { $0.testID == test.id }
        return test.higherIsBetter ? mine.max { $0.value < $1.value } : mine.min { $0.value < $1.value }
    }

    /// The biggest improvement since the previous test among `tests`, as a
    /// short line for Home ("Vertical jump: 3 cm higher").
    public static func headline(_ results: [BenchmarkResult], tests: [BenchmarkTest]) -> String? {
        var bestLine: (String, Double)?
        for test in tests {
            guard let change = change(results, test: test), let delta = change.delta, change.improved == true,
                  let previous = change.previous, previous.value != 0 else { continue }
            let relative = abs(delta / previous.value)
            if bestLine == nil || relative > bestLine!.1 {
                bestLine = ("\(test.name): \(test.unit.formatChange(delta, higherIsBetter: test.higherIsBetter))", relative)
            }
        }
        return bestLine?.0
    }
}

/// When the next tests are due: 6 weeks after the last, overdue after 8.
public enum BenchmarkSchedule {
    public static let dueAfterDays = 42
    public static let overdueAfterDays = 56

    public enum Status: Equatable, Sendable {
        /// Never tested: the first results are the starting point.
        case firstTime
        case notYet(daysLeft: Int)
        case due
        case overdue
    }

    public static func status(lastTest: Date?, now: Date = .now, calendar: Calendar = .current) -> Status {
        guard let lastTest else { return .firstTime }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastTest), to: calendar.startOfDay(for: now)).day ?? 0
        if days >= overdueAfterDays { return .overdue }
        if days >= dueAfterDays { return .due }
        return .notYet(daysLeft: dueAfterDays - days)
    }
}

public enum BenchmarkStore {
    static let resultsKey = "benchmark.results"

    public static var results: [BenchmarkResult] {
        get { UserDefaults.standard.data(forKey: resultsKey).flatMap { try? JSONDecoder().decode([BenchmarkResult].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue.sorted { $0.date < $1.date }), forKey: resultsKey) }
    }

    /// Saves a result. Several tries on the same day keep only the best.
    public static func record(_ value: Double, for test: BenchmarkTest, on date: Date = .now, calendar: Calendar = .current) {
        var all = results
        if let index = all.firstIndex(where: { $0.testID == test.id && calendar.isDate($0.date, inSameDayAs: date) }) {
            let old = all[index].value
            let better = test.higherIsBetter ? value > old : value < old
            if better { all[index].value = value }
        } else {
            all.append(BenchmarkResult(testID: test.id, value: value, date: date))
        }
        results = all
    }

    public static func delete(_ result: BenchmarkResult) {
        results = results.filter { $0.id != result.id }
    }

    /// The last day any body test was done.
    public static func lastTestDate(_ results: [BenchmarkResult] = results) -> Date? {
        let bodyIDs = Set(BenchmarkCatalog.body.map(\.id))
        return results.filter { bodyIDs.contains($0.testID) }.map(\.date).max()
    }
}

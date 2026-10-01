import SwiftUI

// MARK: - The part of the day

/// Home changes its purpose through the day — PREPARE, PERFORM, REFLECT —
/// and its light with it. Same app, same dark design; only the ambient glow,
/// the greeting, the hero and the call to action change.
public enum DayPhase: String, Sendable, CaseIterable {
    /// 5:00–11:30: prepare. What does my body feel like, what's planned?
    case morning
    /// 11:30–17:30: perform. What's next? Start it.
    case day
    /// 17:30–24:00: reflect. What happened, what did I learn?
    case evening
    /// 0:00–5:00: rest. Nothing to do but sleep.
    case night

    public static func at(_ date: Date, calendar: Calendar = .current) -> DayPhase {
        at(minute: minuteOfDay(date, calendar: calendar))
    }

    public static func at(minute: Int) -> DayPhase {
        switch minute {
        case 300..<690: .morning
        case 690..<1050: .day
        case 1050..<1440: .evening
        default: .night
        }
    }

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    public var greeting: String {
        switch self {
        case .morning: "Good morning"
        case .day: "Good afternoon"
        case .evening: "Good evening"
        case .night: "Good night"
        }
    }

    public var systemImage: String {
        switch self {
        case .morning: "sunrise.fill"
        case .day: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }

    /// Athlete OS red, with the character of the hour: warmer in the
    /// morning, pure in the day, deeper crimson in the evening.
    public var red: Color {
        switch self {
        case .morning: Color(hex: "#F0523A")
        case .day: AppTheme.red
        case .evening: Color(hex: "#D23A4E")
        case .night: Color(hex: "#B23447")
        }
    }
}

// MARK: - Ambient light

/// The glow at the top of Home: a colour and a strength that drift through
/// the day. Anchors hold for hours and blend into each other over an hour or
/// two, so 5:29 pm and 5:31 pm look the same.
public struct AmbientLight: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var strength: Double

    /// (minute of the day, light). Wraps around midnight.
    static let anchors: [(minute: Int, light: AmbientLight)] = [
        (0, .night), (270, .night),          // until 4:30 near-black with faint dark red
        (390, .morning), (630, .morning),    // 6:30–10:30 warm red morning light
        (750, .day), (990, .day),            // 12:30–16:30 sharp Athlete OS red
        (1110, .evening), (1350, .evening),  // 18:30–22:30 crimson / burgundy
        (1440, .night),
    ]

    static let night = AmbientLight(red: 0.36, green: 0.05, blue: 0.09, strength: 0.22)
    static let morning = AmbientLight(red: 0.94, green: 0.33, blue: 0.20, strength: 0.30)
    static let day = AmbientLight(red: 0.94, green: 0.27, blue: 0.27, strength: 0.22)
    static let evening = AmbientLight(red: 0.52, green: 0.08, blue: 0.16, strength: 0.38)

    public static func at(_ date: Date, calendar: Calendar = .current) -> AmbientLight {
        at(minute: DayPhase.minuteOfDay(date, calendar: calendar))
    }

    public static func at(minute: Int) -> AmbientLight {
        let m = ((minute % 1440) + 1440) % 1440
        for index in 0..<(anchors.count - 1) {
            let (from, to) = (anchors[index], anchors[index + 1])
            guard m >= from.minute, m <= to.minute else { continue }
            let span = Double(to.minute - from.minute)
            let t = span == 0 ? 0 : Double(m - from.minute) / span
            return from.light.mixed(with: to.light, t: t)
        }
        return .night
    }

    func mixed(with other: AmbientLight, t: Double) -> AmbientLight {
        let t = min(max(t, 0), 1)
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return AmbientLight(red: lerp(red, other.red), green: lerp(green, other.green),
                            blue: lerp(blue, other.blue), strength: lerp(strength, other.strength))
    }

    public var color: Color { Color(red: red, green: green, blue: blue) }
}

/// Home's backdrop (V5): near-black space, the hour's light from the top,
/// a low crimson field on the side and the sport's geometry barely there.
/// Checked once a minute; every change is tiny.
struct HomeAmbientBackground: View {
    var sportSlug: String?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let light = AmbientLight.at(context.date)
            ZStack(alignment: .top) {
                AppTheme.background
                RadialGradient(colors: [light.color.opacity(light.strength), light.color.opacity(light.strength * 0.3), .clear],
                               center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 520)
                    .frame(height: 640)
                    .animation(.easeInOut(duration: 2), value: light)
                RadialGradient(colors: [AppTheme.crimson.opacity(0.16), AppTheme.atmosphere.opacity(0.10), .clear],
                               center: UnitPoint(x: 1.0, y: 1.0), startRadius: 0, endRadius: 460)
                if let sportSlug {
                    SportAtmosphere(sportSlug: sportSlug)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// Red as light behind a hero word or number: a soft, blurred bloom that
/// never changes the layout.
struct HeroBloom: View {
    var color: Color = AppTheme.brand

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [color.opacity(0.32), color.opacity(0.08), .clear],
                                 center: .center, startRadius: 0, endRadius: 150))
            .frame(width: 320, height: 200)
            .blur(radius: 24)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A hero button's label: "CHECK IN →".
struct HeroCTALabel: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased()).tracking(1.6)
            Image(systemName: "arrow.right").font(.subheadline.weight(.bold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// A glass data block: a big value, a small tracked label. Heights differ
/// on purpose so a row of them reads like a layout, not a table.
struct GlassMetric: View {
    let value: String
    let label: String
    var height: CGFloat = 76
    var accent: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(accent ?? AppTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .bottomLeading)
        .glassSurface(cornerRadius: 20, tint: accent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Readiness as an instrument: a thin three-part line, the current state lit.
/// Never a number.
struct ReadinessScale: View {
    let level: TodayReadiness

    private static let order: [TodayReadiness] = [.recovery, .reduced, .normal]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.order, id: \.rawValue) { step in
                let lit = step == level
                Capsule()
                    .fill(lit ? AppTheme.color(for: step.band) : Color.white.opacity(0.10))
                    .frame(height: lit ? 4 : 2)
                    .shadow(color: lit ? AppTheme.color(for: step.band).opacity(0.7) : .clear, radius: 6)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

// MARK: - Quotes for the hour

public extension DailyQuotes {
    /// A short quote that fits the hour: preparation in the morning,
    /// performance in the day, reflection in the evening. Same all day
    /// within a part of the day.
    static func short(for phase: DayPhase, date: Date = .now, calendar: Calendar = .current) -> DailyQuote {
        let starts: [String]
        switch phase {
        case .morning:
            starts = ["The will to win is important", "Make each day your masterpiece", "What you do today can improve",
                      "Don't count the days", "Set your goals high", "Some people want it to happen"]
        case .day:
            starts = ["Pressure is a privilege", "You miss 100%", "Hard work beats talent", "Champions keep playing",
                      "Talent wins games", "Don't let what you cannot do"]
        case .evening, .night:
            starts = ["I've learned that something constructive", "It's not whether you get knocked down",
                      "Excellence is the gradual result", "Just keep going", "Tough times don't last",
                      "I really think a champion is defined"]
        }
        let pool = all.filter { quote in quote.text.count <= 100 && starts.contains { quote.text.hasPrefix($0) } }
        guard !pool.isEmpty else { return short(for: date, calendar: calendar) }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }
}

// MARK: - The day's progress

/// What today is made of, for the evening's "Today complete" and the ring:
/// practice (when there is one), the workout (when one is planned or done),
/// mobility and the reflection. A rest day completes without a workout.
public struct DayProgress: Equatable, Sendable {
    public enum Part: String, Sendable, CaseIterable, Identifiable {
        case practice, workout, mobility, reflection
        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .practice: "Practice"
            case .workout: "Workout"
            case .mobility: "Mobility"
            case .reflection: "Reflection"
            }
        }

        public var color: Color {
            switch self {
            case .practice: AppTheme.orange
            case .workout: AppTheme.red
            case .mobility: AppTheme.cyan
            case .reflection: AppTheme.purple
            }
        }
    }

    public struct Item: Equatable, Sendable, Identifiable {
        public let part: Part
        public let done: Bool
        public var id: String { part.rawValue }
    }

    public let items: [Item]

    public init(practiceToday: Bool, practiceLogged: Bool, workoutPlanned: Bool, workoutDone: Bool,
                mobilityDone: Bool, reflected: Bool) {
        var items: [Item] = []
        if practiceToday || practiceLogged { items.append(Item(part: .practice, done: practiceLogged)) }
        if workoutPlanned || workoutDone { items.append(Item(part: .workout, done: workoutDone)) }
        items.append(Item(part: .mobility, done: mobilityDone))
        items.append(Item(part: .reflection, done: reflected))
        self.items = items
    }

    public var doneCount: Int { items.filter(\.done).count }
    public var isComplete: Bool { items.allSatisfy(\.done) }
}

/// The day's parts as one ring: a segment each, filled when done.
struct DayCompletionRing: View {
    let progress: DayProgress
    var size: CGFloat = 132
    var lineWidth: CGFloat = 10

    var body: some View {
        let count = max(progress.items.count, 1)
        let gap = 0.018
        ZStack {
            ForEach(Array(progress.items.enumerated()), id: \.element.id) { index, item in
                let start = Double(index) / Double(count) + gap / 2
                let end = Double(index + 1) / Double(count) - gap / 2
                Circle()
                    .trim(from: start, to: end)
                    .stroke(item.done ? item.part.color : AppTheme.fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(progress.doneCount)/\(progress.items.count)")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.5), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.doneCount) of \(progress.items.count) done today")
    }
}

// MARK: - The week

/// "Your week" on Home: one small block, not accounting software.
public struct WeekSummary: Equatable, Sendable {
    public let practices: Int
    public let workouts: Int
    public let mobility: Int
    public let checkIns: Int
    /// Days of the week so far (Monday = 1 … today).
    public let daysSoFar: Int
    /// Monday … Sunday: something done that day (a check-in, practice or workout).
    public let active: [Bool]

    /// `sessions`: when each workout started and whether it was mobility.
    public static func make(now: Date, sessions: [(date: Date, mobility: Bool)], practiceDays: [String],
                            checkInDates: [Date], calendar: Calendar = .current) -> WeekSummary {
        var monday = calendar
        monday.firstWeekday = 2
        let start = monday.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let keys = days.map { DayKey.of($0, calendar: calendar) }
        let inWeek = { (date: Date) in date >= start && date < (calendar.date(byAdding: .day, value: 7, to: start) ?? now) }
        let weekSessions = sessions.filter { inWeek($0.date) }
        let weekPractices = Set(practiceDays.filter { keys.contains($0) })
        let checkInDays = Set(checkInDates.filter(inWeek).map { DayKey.of($0, calendar: calendar) })
        let sessionDays = Set(weekSessions.map { DayKey.of($0.date, calendar: calendar) })
        let today = calendar.startOfDay(for: now)
        return WeekSummary(
            practices: weekPractices.count,
            workouts: weekSessions.filter { !$0.mobility }.count,
            mobility: weekSessions.filter(\.mobility).count,
            checkIns: checkInDays.count,
            daysSoFar: days.filter { $0 <= today }.count,
            active: keys.map { checkInDays.contains($0) || sessionDays.contains($0) || weekPractices.contains($0) }
        )
    }
}

/// The week (V5): one 2x2 of glass numbers and a dot per day. The only
/// weekly summary on Home.
struct HomeWeekBlock: View {
    let week: WeekSummary
    let accent: Color

    var body: some View {
        VStack(spacing: 14) {
            HomeEyebrow("This week")
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    GlassMetric(value: Self.twoDigits(week.practices), label: week.practices == 1 ? "Practice" : "Practices",
                                height: 92, accent: AppTheme.orange)
                    GlassMetric(value: Self.twoDigits(week.workouts), label: week.workouts == 1 ? "Workout" : "Workouts",
                                height: 92, accent: AppTheme.red)
                }
                GridRow {
                    GlassMetric(value: Self.twoDigits(week.mobility), label: "Mobility", height: 76, accent: AppTheme.cyan)
                    GlassMetric(value: "\(week.checkIns)/\(week.daysSoFar)", label: "Check-ins", height: 76)
                }
            }
            .frame(maxWidth: 400)
            HStack(spacing: 10) {
                ForEach(Array(week.active.enumerated()), id: \.offset) { index, active in
                    Circle()
                        .fill(active ? accent : (index < week.daysSoFar ? AppTheme.fill : AppTheme.fill.opacity(0.5)))
                        .frame(width: 7, height: 7)
                        .shadow(color: active ? accent.opacity(0.7) : .clear, radius: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Active on \(week.active.filter { $0 }.count) of \(week.daysSoFar) days this week")
        }
        .frame(maxWidth: .infinity)
    }

    static func twoDigits(_ value: Int) -> String {
        value < 10 && value >= 0 ? "0\(value)" : "\(value)"
    }
}

// MARK: - Small pieces of the centred Home

/// A small spaced-out label above a section ("TODAY'S FOCUS").
struct HomeEyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(2.2)
            .foregroundStyle(AppTheme.mutedText)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A compact supporting row: a small coloured dot, title left, value
/// right, never centred. (V5: fewer icons — the dot carries the colour.)
struct HomeDetailRow<Trailing: View>: View {
    let systemImage: String
    let color: Color
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.6), radius: 4)
                .frame(width: 14)
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            trailing
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// "Why? →": the text first, the icon after it.
struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.caption.weight(.bold))
        }
    }
}

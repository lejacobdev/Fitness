import SwiftUI

// MARK: - Off-season programs (7)

/// A 4–8 week block with one clear goal and a test at each end. While it
/// runs, the weekly plan leans towards the goal and uses the block's gym
/// days; it never adds sessions on top of the athlete's own settings.
public struct TrainingProgram: Codable, Sendable, Equatable {
    public var goal: Struggle
    public var weeks: Int
    public var gymDaysPerWeek: Int
    public var startedAt: Date
    public var finishedAt: Date?

    public init(goal: Struggle, weeks: Int, gymDaysPerWeek: Int, startedAt: Date) {
        self.goal = goal
        self.weeks = weeks
        self.gymDaysPerWeek = gymDaysPerWeek
        self.startedAt = startedAt
    }

    /// Week 1… of the block, nil once it's over.
    public func week(on date: Date = .now, calendar: Calendar = .current) -> Int? {
        guard finishedAt == nil else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startedAt), to: calendar.startOfDay(for: date)).day ?? 0
        let week = days / 7 + 1
        return days >= 0 && week <= weeks ? week : nil
    }

    /// The tests: in the first week (a starting point) and in the last.
    public func isTestWeek(on date: Date = .now) -> Bool {
        guard let week = week(on: date) else { return false }
        return week == 1 || week == weeks
    }
}

public enum ProgramStore {
    static let key = "plans.program"

    public static var current: TrainingProgram? {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(TrainingProgram.self, from: $0) } }
        set { UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: key) }
    }

    /// The running block, if any.
    public static var active: TrainingProgram? { current.flatMap { $0.week() != nil ? $0 : nil } }

    public static let goals: [Struggle] = [.acceleration, .maxSpeed, .strength, .power, .conditioning, .mobility]
}

struct ProgramsView: View {
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var program = ProgramStore.current
    @State private var goal: Struggle = .strength
    @State private var weeks = 6
    @State private var days = 2
    @State private var showingTests = false
    @Environment(\.workoutContext) private var context

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Off-season program", subtitle: "One goal for a few weeks, with a test at the start and the end.")
                    if let program, let week = program.week() {
                        running(program, week: week)
                    } else {
                        setup
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
            .sheet(isPresented: $showingTests) {
                BenchmarksView(sportSlug: context?.athlete?.activeSport?.sportSlug)
            }
        }
    }

    private func running(_ program: TrainingProgram, week: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WEEK \(week) OF \(program.weeks)").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(AppTheme.secondaryText)
            Text(program.goal.title).font(.system(size: 30, weight: .bold)).foregroundStyle(AppTheme.ink)
            ProgressView(value: Double(week), total: Double(program.weeks)).tint(AppTheme.brand)
            Text("\(program.gymDaysPerWeek) gym days a week lean towards \(program.goal.title.lowercased()). Practice and games still come first.")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
            if program.isTestWeek() {
                Button { showingTests = true } label: { Label(week == 1 ? "Take your starting tests" : "Take your end tests", systemImage: "stopwatch") }
                    .buttonStyle(.primary)
            }
            Button("End the program", role: .destructive) {
                var ended = program
                ended.finishedAt = .now
                ProgramStore.current = ended
                self.program = ended
                onChanged()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.red)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal").font(.headline).foregroundStyle(AppTheme.ink)
            WrapLayout(spacing: 8) {
                ForEach(ProgramStore.goals) { option in
                    Button { goal = option } label: { Chip(option.title, isSelected: goal == option) }.buttonStyle(.plain)
                }
            }
            Text("Length").font(.headline).foregroundStyle(AppTheme.ink)
            WrapLayout(spacing: 8) {
                ForEach([4, 6, 8], id: \.self) { value in
                    Button { weeks = value } label: { Chip("\(value) weeks", isSelected: weeks == value) }.buttonStyle(.plain)
                }
            }
            Text("Gym days a week").font(.headline).foregroundStyle(AppTheme.ink)
            WrapLayout(spacing: 8) {
                ForEach([2, 3], id: \.self) { value in
                    Button { days = value } label: { Chip("\(value)", isSelected: days == value) }.buttonStyle(.plain)
                }
            }
            Button("Start the program") {
                let started = TrainingProgram(goal: goal, weeks: weeks, gymDaysPerWeek: days, startedAt: .now)
                ProgramStore.current = started
                program = started
                onChanged()
            }
            .buttonStyle(.primary)
            Text("Best in the off-season. In season, practice and games already ask a lot — the app keeps the gym short then.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Back after illness (8)

/// The few days after being sick (§13: reassess, conservative template —
/// draft, not yet expert-reviewed). Two days of light movement, then three
/// lighter days; any fever or feeling worse means stop and rest again.
public enum IllnessReturn {
    static let key = "dayStatus.lastSickEnd"
    public static let days = 5

    public static func markRecovered(on date: Date = .now, calendar: Calendar = .current) {
        UserDefaults.standard.set(DayKey.of(date, calendar: calendar), forKey: key)
    }

    /// Day 1… of the return, nil when not returning.
    public static func day(on date: Date = .now, calendar: Calendar = .current) -> Int? {
        // A "sick" status that simply ran out ends the illness too.
        if DayStatusStore.storedStatus == .sick, let until = DayStatusStore.until,
           calendar.startOfDay(for: until) < calendar.startOfDay(for: date),
           let after = calendar.date(byAdding: .day, value: 1, to: until) {
            let stored = UserDefaults.standard.string(forKey: key) ?? ""
            if stored < DayKey.of(after, calendar: calendar) { markRecovered(on: after, calendar: calendar) }
        }
        guard let key = UserDefaults.standard.string(forKey: key) else { return nil }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let end = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        let days = (calendar.dateComponents([.day], from: end, to: calendar.startOfDay(for: date)).day ?? 0) + 1
        return days >= 1 && days <= Self.days ? days : nil
    }

    public static func reason(day: Int) -> String {
        day <= 2
            ? "Back after being ill: day \(day) of \(days), light movement only. Fever or feeling worse? Stop and rest."
            : "Back after being ill: day \(day) of \(days), a lighter day. Fever or feeling worse? Stop and rest."
    }
}

// MARK: - School hours (13)

/// When school ends on each weekday, so a long school day (or an exam
/// today) keeps added training short.
public enum SchoolHours {
    static let key = "schedule.schoolEnds"

    /// Weekday (1 = Sunday) → minutes after midnight school ends.
    public static var ends: [Int: Int] {
        get {
            let entries = UserDefaults.standard.stringArray(forKey: key) ?? []
            return Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (Int, Int)? in
                let parts = entry.split(separator: "=").compactMap { Int($0) }
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            })
        }
        set { UserDefaults.standard.set(newValue.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }, forKey: key) }
    }

    /// School ending at 4:30 pm or later counts as a long day.
    public static let longDayFrom = 16 * 60 + 30

    public static func isLongDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        (ends[calendar.component(.weekday, from: date)] ?? 0) >= longDayFrom
    }
}

struct SchoolHoursSection: View {
    let onChanged: () -> Void
    @State private var ends = SchoolHours.ends

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("School hours", subtitle: "A long school day keeps added training short.")
            VStack(spacing: 0) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { weekday in
                    HStack {
                        Text(Calendar.current.weekdaySymbols[weekday - 1]).font(.body).foregroundStyle(AppTheme.ink)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { ends[weekday] ?? 0 },
                            set: { value in
                                if value == 0 { ends[weekday] = nil } else { ends[weekday] = value }
                                SchoolHours.ends = ends
                                onChanged()
                            }
                        )) {
                            Text("Not set").tag(0)
                            ForEach(Array(stride(from: 12 * 60, through: 18 * 60, by: 30)), id: \.self) { minutes in
                                Text(PracticeTime(start: minutes, end: minutes).label.components(separatedBy: " – ").first ?? "").tag(minutes)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: 48)
                }
            }
            .cardStyle(padding: 12)
        }
    }
}

// MARK: - Tournament and travel mode (16)

/// Away tournaments: the time difference, sleep, between games, food on the
/// road and a hotel-room workout — in one place.
struct TournamentModeView: View {
    let onHotelWorkout: () -> Void
    let onFood: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("travel.timeZone") private var timeZoneID = TimeZone.current.identifier

    private static let zones = ["America/Los_Angeles", "America/Denver", "America/Chicago", "America/New_York", "Europe/London",
                                "Europe/Berlin", "Asia/Tokyo", "Australia/Sydney"]

    private var hoursDifference: Int {
        let there = TimeZone(identifier: timeZoneID) ?? .current
        return (there.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 3600
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Tournament & travel", subtitle: "Everything for a trip with games, in one place.")
                    section("Where are you going?") {
                        Picker("Time zone", selection: $timeZoneID) {
                            Text("Same time zone").tag(TimeZone.current.identifier)
                            ForEach(Self.zones, id: \.self) { zone in
                                Text(zone.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone).tag(zone)
                            }
                        }
                        Text(timeText).font(.subheadline).foregroundStyle(AppTheme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    section("Between games") {
                        bullets([
                            "Right after a game: drink, and eat a snack with carbs and some protein within an hour.",
                            "Feet up and easy movement — no extra workout during a tournament.",
                            "Next game within 2–3 hours: small, familiar snacks only.",
                            "Feeling faint, sick or dizzy in the heat? Stop, cool down, tell an adult.",
                        ])
                    }
                    section("Sleep away from home") {
                        bullets([
                            "Same bedtime routine as at home: it tells your body it's night.",
                            "Bring what helps: earplugs, eye mask, your pillow.",
                            "A short nap (20–30 min) early in the afternoon is fine; long late naps make the night harder.",
                        ])
                    }
                    ButtonRow {
                        Button("Food on the road") { dismiss(); onFood() }.buttonStyle(.secondary)
                        Button("Hotel-room workout") { dismiss(); onHotelWorkout() }.buttonStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
    }

    private var timeText: String {
        let h = hoursDifference
        if h == 0 { return "No time difference: keep your normal routine." }
        let way = h > 0 ? "ahead" : "behind"
        let shift = h > 0 ? "earlier" : "later"
        return "\(abs(h)) hour\(abs(h) == 1 ? "" : "s") \(way). A few days before you leave, go to bed and get up about an hour \(shift) each day. When you arrive, get outside in daylight in the morning and eat at local times."
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(AppTheme.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func bullets(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines, id: \.self) { line in
                Text("• " + line).font(.subheadline).foregroundStyle(AppTheme.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

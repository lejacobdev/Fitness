import SwiftUI

/// The Athlete Score as shown: the engine's value smoothed against last
/// week's, and the trend against about a month ago.
struct AthleteScoreSnapshot: Equatable {
    let score: AthleteScore
    /// nil while the score is still learning.
    let shown: Int?
    let trend: AthleteScore.Trend
}

/// Feeds the engine from what the phone already has, and keeps the weekly
/// values (for smoothing and the trend) and the paused days.
@MainActor
enum AthleteScoreStore {
    private static let historyKey = "athleteScore.weekly"
    private static let pausedKey = "athleteScore.pausedDays"

    static func snapshot(athlete: Athlete, sessions: [Session], now: Date = .now, calendar: Calendar = .current) -> AthleteScoreSnapshot {
        notePausedDay(now, calendar: calendar)
        let input = input(athlete: athlete, sessions: sessions, now: now, calendar: calendar)
        let score = AthleteScoreEngine.score(input, calendar: calendar)
        var history = UserDefaults.standard.dictionary(forKey: historyKey) as? [String: Int] ?? [:]
        let thisWeek = weekKey(now, calendar: calendar)
        guard let raw = score.value else { return AthleteScoreSnapshot(score: score, shown: nil, trend: .steady) }
        let lastWeek = history.filter { $0.key < thisWeek }.max { $0.key < $1.key }?.value
        // While sick, travelling or on holiday the score holds where it was.
        let paused = DayStatusStore.status(on: now, calendar: calendar) != .active
        let shown = paused ? (history[thisWeek] ?? lastWeek ?? raw) : AthleteScoreEngine.smoothed(raw, lastWeek: lastWeek)
        history[thisWeek] = shown
        let kept = history.sorted { $0.key > $1.key }.prefix(26)
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) }), forKey: historyKey)
        let points = kept.compactMap { entry in date(fromKey: entry.key, calendar: calendar).map { (week: $0, value: entry.value) } }
        return AthleteScoreSnapshot(score: score, shown: shown,
                                    trend: AthleteScoreEngine.trend(current: shown, history: points, now: now, calendar: calendar))
    }

    private static func notePausedDay(_ now: Date, calendar: Calendar) {
        guard DayStatusStore.status(on: now, calendar: calendar) != .active else { return }
        var days = Set(UserDefaults.standard.stringArray(forKey: pausedKey) ?? [])
        days.insert(DayKey.of(now, calendar: calendar))
        UserDefaults.standard.set(Array(days.sorted().suffix(120)), forKey: pausedKey)
    }

    private static func input(athlete: Athlete, sessions: [Session], now: Date, calendar: Calendar) -> AthleteScoreInput {
        let cutoff = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        let recent = sessions.filter { $0.startedAt >= cutoff }
        let kinds = SessionKinds.all
        let activities = recent.map {
            AthleteScoreInput.Activity(date: $0.startedAt, minutes: $0.minutes, rpe: $0.sessionRPE, mobility: kinds[$0.clientId] == .mobility)
        }
        let practices = PracticeLogStore.logs.compactMap { log in
            date(fromKey: log.day, calendar: calendar).map {
                AthleteScoreInput.Practice(date: $0.addingTimeInterval(17 * 3600), minutes: log.minutes, hard: log.hard, went: log.went)
            }
        }
        let checkIns = athlete.checkIns.map {
            AthleteScoreInput.Wellness(date: $0.date, sleep: $0.sleepQuality, energy: $0.energy, soreness: $0.soreness, stress: $0.stress)
        }
        let feelings = MindsetStore.reflections.compactMap { reflection in
            date(fromKey: reflection.day, calendar: calendar).map {
                AthleteScoreInput.Feeling(date: $0.addingTimeInterval(20 * 3600), day: reflection.feeling, practice: reflection.practice,
                                          learned: !(reflection.learned ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        let paused = Set((UserDefaults.standard.stringArray(forKey: pausedKey) ?? []).compactMap { date(fromKey: $0, calendar: calendar) })
        return AthleteScoreInput(now: now, activities: activities, practices: practices, checkIns: checkIns, feelings: feelings,
                                 plannedPerWeek: plannedPerWeek(athlete: athlete, now: now) + PracticeSchedule.weekdays.count,
                                 pausedDays: paused,
                                 developmentChanges: testChanges(sportSlug: athlete.activeSport?.sportSlug, now: now, calendar: calendar)
                                    + liftChanges(sessions: recent, now: now, calendar: calendar))
    }

    private static func plannedPerWeek(athlete: Athlete, now: Date) -> Int {
        if let chosen = PlanCustomizationStore.load().settings.effectiveSessionsPerWeek { return chosen }
        guard let sport = athlete.activeSport else { return 2 }
        switch PhaseCalculator.phase(today: now, seasonStart: sport.seasonStart, seasonEnd: sport.seasonEnd) {
        case .offSeason, .preSeason: return 3
        case .inSeason, .postSeason: return 2
        }
    }

    /// Each test's latest result (from the last four months) against the one before.
    private static func testChanges(sportSlug: String?, now: Date, calendar: Calendar) -> [Double] {
        let cutoff = calendar.date(byAdding: .day, value: -120, to: now) ?? now
        let tests = BenchmarkCatalog.body + BenchmarkCatalog.tests(for: sportSlug)
        var seen = Set<String>()
        return tests.compactMap { test -> Double? in
            guard seen.insert(test.id).inserted,
                  let change = BenchmarkMath.change(BenchmarkStore.results, test: test),
                  change.latest.date >= cutoff, let previous = change.previous, previous.value != 0 else { return nil }
            let relative = (change.latest.value - previous.value) / abs(previous.value)
            return test.higherIsBetter ? relative : -relative
        }
    }

    /// Estimated one-rep max per exercise: the last four weeks against the four before.
    private static func liftChanges(sessions: [Session], now: Date, calendar: Calendar) -> [Double] {
        let split = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        var recent: [String: Double] = [:]
        var before: [String: Double] = [:]
        for session in sessions {
            for set in session.sets {
                guard let reps = set.reps, (1...12).contains(reps), let weight = set.weightKg, weight > 0 else { continue }
                let estimate = weight * (1 + Double(reps) / 30)
                if session.startedAt >= split {
                    recent[set.itemSlug] = max(recent[set.itemSlug] ?? 0, estimate)
                } else {
                    before[set.itemSlug] = max(before[set.itemSlug] ?? 0, estimate)
                }
            }
        }
        return recent.compactMap { slug, value in before[slug].map { (value - $0) / $0 } }
    }

    private static func weekKey(_ date: Date, calendar: Calendar) -> String {
        DayKey.of(calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date, calendar: calendar)
    }

    private static func date(fromKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// The score as a ring of light: the number inside, the arc lit red.
/// While learning, a quiet white arc shows how far along it is.
struct AthleteScoreRing: View {
    let snapshot: AthleteScoreSnapshot?
    var size: CGFloat = 76

    private var lineWidth: CGFloat { max(5, size * 0.075) }
    private var fraction: Double {
        if let shown = snapshot?.shown { return Double(shown) / 100 }
        return snapshot?.score.learning?.progress ?? 0
    }

    var body: some View {
        ZStack {
            Circle().stroke(AppTheme.fill, lineWidth: lineWidth)
            if snapshot?.shown != nil {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(AngularGradient(colors: [AppTheme.crimson, AppTheme.brightRed, AppTheme.brightRed], center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(360 * max(fraction, 0.01))),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AppTheme.brightRed.opacity(0.55), radius: size * 0.08)
            } else {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if let shown = snapshot?.shown {
                Text(String(shown))
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
            } else {
                Text("New")
                    .font(.system(size: size * 0.18, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// What the score says, why, and what it is made of.
struct AthleteScoreSheet: View {
    let snapshot: AthleteScoreSnapshot
    @Environment(\.dismiss) private var dismiss

    private var score: AthleteScore { snapshot.score }

    private var trendLine: String {
        if let learning = score.learning { return learning.detail }
        switch snapshot.trend {
        case .up: return "Up since last month"
        case .steady: return "Steady over the last month"
        case .down: return "A little lower than last month"
        }
    }

    private var directionTitle: String {
        switch score.direction {
        case .pushMore: "Room to push"
        case .holdSteady: "Keep it steady"
        case .easeOff: "Ease off a little"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    VStack(spacing: 16) {
                        Text("Athlete Score")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .accessibilityAddTraits(.isHeader)
                        AthleteScoreRing(snapshot: snapshot, size: 168)
                            .background { HeroBloom(color: AppTheme.brand) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(snapshot.shown.map { "Athlete Score \($0) of 100" } ?? "Athlete Score, still getting to know you")
                        Text(score.word)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(trendLine)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(score.learning == nil ? directionTitle : "For now")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(score.advice)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .glassSurface(tint: score.learning == nil ? AppTheme.brand : nil)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("What it's made of")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.bottom, 8)
                        ForEach(score.components, id: \.part) { component in
                            partRow(component)
                            if component.part != score.components.last?.part {
                                Divider().overlay(AppTheme.hairline)
                            }
                        }
                    }

                    Text("Only you see this. It looks at the last four weeks and moves slowly, so one day never changes it. Sick, travel and holiday days never lower it, and pain is never part of it — if something hurts, stop and get it checked.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
        }
    }

    private func partRow(_ component: AthleteScore.Component) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(component.part.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(component.value.map(String.init) ?? "Not yet")
                    .font(component.value == nil ? .subheadline : .body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(component.value == nil ? AppTheme.mutedText : AppTheme.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.fill)
                    Capsule()
                        .fill(AppTheme.brightRed)
                        .frame(width: proxy.size.width * Double(component.value ?? 0) / 100)
                        .shadow(color: AppTheme.brightRed.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 4)
            Text(component.detail)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

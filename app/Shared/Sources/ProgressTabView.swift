import SwiftData
import SwiftUI

/// The calendar's colours: what each day was.
enum ProgressColors {
    /// A completed workout.
    static let workout = AppTheme.red
    /// Team practice.
    static let practice = AppTheme.orange
    /// The extra workout after practice.
    static let afterPractice = Color(hex: "#FACC15")
    /// Stretching and mobility.
    static let mobility = AppTheme.water
}

/// Everything on one day of the calendar.
struct DayMarks: Equatable {
    var workouts = 0
    var practiceDone = false
    var practiceScheduled = false
    var afterPractice = 0
    var mobility = 0
    var game = false
    var plannedWorkout = false

    /// Filled segments: things that happened.
    var done: [Color] {
        var colors: [Color] = []
        if workouts > 0 { colors.append(ProgressColors.workout) }
        if practiceDone { colors.append(ProgressColors.practice) }
        if afterPractice > 0 { colors.append(ProgressColors.afterPractice) }
        if mobility > 0 { colors.append(ProgressColors.mobility) }
        return colors
    }

    /// Outlined segments: planned or scheduled, not (yet) logged.
    var planned: [Color] {
        var colors: [Color] = []
        if plannedWorkout && workouts == 0 { colors.append(ProgressColors.workout) }
        if practiceScheduled && !practiceDone { colors.append(ProgressColors.practice) }
        return colors
    }

    var isEmpty: Bool { done.isEmpty && planned.isEmpty && !game }
}

/// A dot split into one slice per thing that happened that day; planned
/// things are outlined, and a game day gets a ring.
struct PieDot: View {
    let marks: DayMarks
    var size: CGFloat = 16

    var body: some View {
        let done = marks.done
        let planned = marks.planned
        let ring = marks.game
        let ringColor = AppTheme.ink
        Canvas { context, canvasSize in
            let inset: CGFloat = ring ? 3 : 1
            let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: inset, dy: inset)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            func slice(_ index: Int, of count: Int) -> Path {
                var path = Path()
                let start = Angle.degrees(-90 + 360 * Double(index) / Double(count))
                let end = Angle.degrees(-90 + 360 * Double(index + 1) / Double(count))
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                path.closeSubpath()
                return path
            }
            if !done.isEmpty {
                for (index, color) in done.enumerated() {
                    context.fill(done.count == 1 ? Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)) : slice(index, of: done.count),
                                 with: .color(color))
                }
            } else if !planned.isEmpty {
                for (index, color) in planned.enumerated() {
                    var arc = Path()
                    let start = Angle.degrees(-90 + 360 * Double(index) / Double(planned.count))
                    let end = Angle.degrees(-90 + 360 * Double(index + 1) / Double(planned.count))
                    arc.addArc(center: center, radius: radius - 1, startAngle: start, endAngle: end, clockwise: false)
                    context.stroke(arc, with: .color(color), lineWidth: 2)
                }
            }
            if ring {
                let outer = CGRect(x: center.x - radius - 2.5, y: center.y - radius - 2.5, width: (radius + 2.5) * 2, height: (radius + 2.5) * 2)
                context.stroke(Path(ellipseIn: outer), with: .color(ringColor), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The Progress section: a motivating look back (and ahead) — a calendar
/// that zooms from a month out to the season and the year, team practice
/// logged as simply or as exactly as the athlete likes, what they practised
/// most and least, and their schedule and events.
struct ProgressTabView: View {
    let athlete: Athlete
    let week: GeneratedWeek?
    let onPlanInputsChanged: () -> Void

    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var zoom: Zoom = .month
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedDay: DayBox?
    @State private var loggingPractice: DayBox?
    @State private var sheet: ProgressSheet?
    @State private var statsPeriod: StatsPeriod = ProAccess.isPro ? .season : .month
    @State private var revision = 0
    @State private var tracking = ProAccess.isPro ? TrackingLevel.current : .easy
    @State private var paywall: ProFeature?

    enum Zoom: String, CaseIterable, Identifiable {
        case month = "Month", season = "Season", year = "Year"
        var id: String { rawValue }
    }

    enum StatsPeriod: String, CaseIterable, Identifiable {
        case month = "30 days", season = "This season", all = "All time"
        var id: String { rawValue }
    }

    enum ProgressSheet: String, Identifiable {
        case schedule, calendars, addGame, addTraining, history, tests
        var id: String { rawValue }
    }

    /// A date for `.sheet(item:)`.
    struct DayBox: Identifiable {
        let date: Date
        var id: Double { date.timeIntervalSince1970 }
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var sportSlug: String? { athlete.activeSport?.sportSlug }

    // MARK: Marks

    /// What happened (and is planned) on every day, by YYYY-MM-DD.
    private var marksByDay: [String: DayMarks] {
        _ = revision
        var marks: [String: DayMarks] = [:]
        let kinds = SessionKinds.all
        for session in sessions {
            let key = DayKey.of(session.startedAt, calendar: calendar)
            switch kinds[session.clientId] ?? .gym {
            case .afterPractice: marks[key, default: DayMarks()].afterPractice += 1
            case .mobility: marks[key, default: DayMarks()].mobility += 1
            default: marks[key, default: DayMarks()].workouts += 1
            }
        }
        for log in PracticeLogStore.logs { marks[log.day, default: DayMarks()].practiceDone = true }
        for game in athlete.competitions { marks[DayKey.of(game.date, calendar: calendar), default: DayMarks()].game = true }
        for session in week?.sessions ?? [] where session.date >= calendar.startOfDay(for: .now) {
            marks[DayKey.of(session.date, calendar: calendar), default: DayMarks()].plannedWorkout = true
        }
        return marks
    }

    private func marks(on date: Date, from all: [String: DayMarks]) -> DayMarks {
        var day = all[DayKey.of(date, calendar: calendar)] ?? DayMarks()
        // Scheduled practice, from the season start (or a year back) on.
        if !day.practiceDone, date >= practiceScheduleStart, PracticeSchedule.hasPractice(on: date, calendar: calendar) {
            day.practiceScheduled = true
        }
        return day
    }

    private var practiceScheduleStart: Date {
        athlete.activeSport?.seasonStart ?? calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Progress", subtitle: "Every workout, practice and game — what you've done and what's coming.")
                    summaryCard
                    calendarCard
                    practiceSection
                    statsSection
                    scheduleSection
                    workoutsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.bottom, 20)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { revision += 1 }
            .sheet(item: $selectedDay, onDismiss: { revision += 1 }) { box in
                DayDetailSheet(athlete: athlete, date: box.date, marks: marks(on: box.date, from: marksByDay), week: week) {
                    let date = box.date
                    selectedDay = nil
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        loggingPractice = DayBox(date: date)
                    }
                }
            }
            .sheet(item: $loggingPractice, onDismiss: { revision += 1; tracking = ProAccess.isPro ? TrackingLevel.current : .easy }) { box in
                PracticeLogSheet(athlete: athlete, date: box.date)
            }
            .sheet(item: $sheet, onDismiss: { revision += 1 }) { sheet in
                switch sheet {
                case .schedule: PracticeScheduleSheet { onPlanInputsChanged() }
                case .calendars: ScheduleSheet(athlete: athlete, onChanged: onPlanInputsChanged)
                case .addGame: AddGameSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .addTraining: ExtraPracticeSheet { onPlanInputsChanged() }
                case .history: SessionHistoryView()
                case .tests: BenchmarksView(sportSlug: sportSlug)
                }
            }
            .proFeature(item: $paywall, athlete: athlete)
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        let all = marksByDay
        let thisMonth = monthTotals(for: .now, all)
        let lastMonth = monthTotals(for: calendar.date(byAdding: .month, value: -1, to: .now) ?? .now, all)
        let streak = AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: sessions.map(\.startedAt))
        let total = thisMonth.workouts + thisMonth.practices + thisMonth.mobility
        let lastTotal = lastMonth.workouts + lastMonth.practices + lastMonth.mobility
        let message: String = {
            if total == 0 { return "A fresh month. The first workout is the hardest — start today." }
            if total > lastTotal, lastTotal > 0 { return "Already more than all of last month. Keep it rolling!" }
            if lastTotal > total { return "\(lastTotal - total) more to beat last month." }
            return "Every session counts. Keep showing up."
        }()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This month")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Label("\(streak) day streak", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.orange)
            }
            HStack(spacing: 10) {
                stat(thisMonth.workouts, "workouts", ProgressColors.workout)
                stat(thisMonth.practices, "practices", ProgressColors.practice)
                stat(thisMonth.mobility, "mobility", ProgressColors.mobility)
            }
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .cardStyle()
    }

    private func stat(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthTotals(for date: Date, _ all: [String: DayMarks]) -> (workouts: Int, practices: Int, mobility: Int) {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return (0, 0, 0) }
        var result = (workouts: 0, practices: 0, mobility: 0)
        var day = interval.start
        while day < interval.end {
            if let marks = all[DayKey.of(day, calendar: calendar)] {
                result.workouts += marks.workouts + marks.afterPractice
                result.practices += marks.practiceDone ? 1 : 0
                result.mobility += marks.mobility
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        return result
    }

    // MARK: Calendar

    private var calendarCard: some View {
        let all = marksByDay
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Zoom.allCases) { value in
                    // Month is free; the whole season and year are Pro.
                    let locked = value != .month && !ProAccess.isPro
                    Button {
                        if locked { paywall = .fullSeasonCalendar } else { withAnimation(.easeInOut(duration: 0.2)) { zoom = value } }
                    } label: {
                        Text(value.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(zoom == value ? AppTheme.onAccent : AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(zoom == value ? AppTheme.accent : AppTheme.fill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(value.rawValue)
                }
            }
            switch zoom {
            case .month: monthView(all)
            case .season: overview(months: seasonMonths, all)
            case .year: overview(months: yearMonths, all)
            }
            legend
        }
        .cardStyle(padding: 16)
        #if os(iOS)
        .gesture(MagnifyGesture().onEnded { value in
            // Pinch out to see more, in to see less (the season and year are Pro).
            guard ProAccess.isPro else {
                if value.magnification < 0.8 { paywall = .fullSeasonCalendar }
                return
            }
            withAnimation {
                if value.magnification < 0.8 { zoom = zoom == .month ? .season : .year }
                if value.magnification > 1.25 { zoom = zoom == .year ? .season : .month }
            }
        })
        #endif
    }

    private var legend: some View {
        let items: [(Color, String)] = [(ProgressColors.workout, "Workout"), (ProgressColors.practice, "Team practice"),
                                          (ProgressColors.afterPractice, "After practice"), (ProgressColors.mobility, "Mobility")]
        return VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                ForEach(items, id: \.1) { item in
                    HStack(spacing: 6) {
                        Circle().fill(item.0).frame(width: 10, height: 10)
                        Text(item.1).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.secondaryText).lineLimit(1)
                    }
                }
            }
            Text("Outlined: planned. Ring: game. Tap a day to see it; pinch or use the buttons to zoom.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// Leading blanks so the 1st lands on its weekday (Monday first).
    private func leadingBlanks(_ monthStart: Date) -> Int {
        (calendar.component(.weekday, from: monthStart) + 5) % 7
    }

    private func days(in monthStart: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
    }

    private func monthView(_ all: [String: DayMarks]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let blanks = leadingBlanks(month)
        let monthDays = days(in: month)
        return VStack(spacing: 10) {
            HStack {
                Button { month = calendar.date(byAdding: .month, value: -1, to: month) ?? month } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
                }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Button { month = calendar.date(byAdding: .month, value: 1, to: month) ?? month } label: {
                    Image(systemName: "chevron.right").font(.headline).frame(width: 44, height: 44)
                }
            }
            .foregroundStyle(AppTheme.ink)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption.weight(.bold)).foregroundStyle(AppTheme.secondaryText)
                }
                ForEach(0..<blanks, id: \.self) { _ in Color.clear.frame(height: 48) }
                ForEach(monthDays, id: \.self) { day in
                    let isToday = calendar.isDateInToday(day)
                    Button { selectedDay = DayBox(date: day) } label: {
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.subheadline.weight(isToday ? .heavy : .semibold))
                                .foregroundStyle(isToday ? AppTheme.onAccent : AppTheme.ink)
                                .frame(width: 30, height: 26)
                                .background(isToday ? AppTheme.accent : Color.clear, in: Capsule())
                            PieDot(marks: marks(on: day, from: all), size: 16)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                }
            }
            .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -60 { month = calendar.date(byAdding: .month, value: 1, to: month) ?? month }
                if value.translation.width > 60 { month = calendar.date(byAdding: .month, value: -1, to: month) ?? month }
            })
        }
    }

    private var seasonMonths: [Date] {
        guard let sport = athlete.activeSport else { return yearMonths }
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: sport.seasonStart)) ?? sport.seasonStart
        var months: [Date] = []
        var cursor = start
        while cursor <= sport.seasonEnd, months.count < 12 {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? sport.seasonEnd.addingTimeInterval(1)
        }
        return months.isEmpty ? yearMonths : months
    }

    private var yearMonths: [Date] {
        let year = calendar.component(.year, from: month)
        return (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0, day: 1)) }
    }

    /// Zoomed out: every month as a small grid of dots.
    private func overview(months: [Date], _ all: [String: DayMarks]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return VStack(alignment: .leading, spacing: 10) {
            if zoom == .year {
                HStack {
                    Button { month = calendar.date(byAdding: .year, value: -1, to: month) ?? month } label: {
                        Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text(String(calendar.component(.year, from: month))).font(.title3.bold())
                    Spacer()
                    Button { month = calendar.date(byAdding: .year, value: 1, to: month) ?? month } label: {
                        Image(systemName: "chevron.right").font(.headline).frame(width: 44, height: 44)
                    }
                }
                .foregroundStyle(AppTheme.ink)
            } else {
                Text("Your season").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(months, id: \.self) { monthStart in
                    Button {
                        month = monthStart
                        withAnimation { zoom = .month }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(monthStart.formatted(.dateTime.month(.abbreviated)))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(calendar.isDate(monthStart, equalTo: .now, toGranularity: .month) ? AppTheme.brand : AppTheme.ink)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                                ForEach(0..<leadingBlanks(monthStart), id: \.self) { _ in Color.clear.frame(height: 10) }
                                ForEach(days(in: monthStart), id: \.self) { day in
                                    let dayMarks = marks(on: day, from: all)
                                    if dayMarks.isEmpty {
                                        Circle().fill(AppTheme.fill).frame(width: 5, height: 5).frame(height: 10)
                                    } else {
                                        PieDot(marks: dayMarks, size: 10)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Team practice

    private var practiceSection: some View {
        let todayKey = DayKey.of(.now, calendar: calendar)
        let loggedToday = PracticeLogStore.log(on: todayKey, sportSlug: sportSlug) != nil
        let practiceToday = PracticeSchedule.hasPractice(on: .now, calendar: calendar)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Team practice", subtitle: "Log what you did at practice — as simply or as exactly as you like. Then you'll see what you practise most and least.")
            HStack(spacing: 8) {
                ForEach(TrackingLevel.allCases, id: \.self) { level in
                    let locked = level == .exact && !ProAccess.isPro
                    Button {
                        if locked {
                            paywall = .detailedTracking
                        } else {
                            tracking = level
                            TrackingLevel.current = level
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(level.title).font(.headline)
                            Text(level == .easy ? "Time, effort, mood, result" : "+ each part of your game")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(tracking == level ? AppTheme.onAccent : AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(.horizontal, 6)
                        .background(tracking == level ? AppTheme.accent : AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            if loggedToday {
                Label("Today's practice is logged", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.green)
            }
            Button { loggingPractice = DayBox(date: .now) } label: {
                Label(loggedToday ? "Edit today's practice" : (practiceToday ? "Log today's practice" : "Log a practice"), systemImage: "square.and.pencil")
            }
            .buttonStyle(.primary)
            Text("To log an earlier practice, tap its day in the calendar.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var statsSince: String? {
        switch statsPeriod {
        case .month: return DayKey.of(calendar.date(byAdding: .day, value: -30, to: .now) ?? .now, calendar: calendar)
        case .season: return athlete.activeSport.map { DayKey.of($0.seasonStart, calendar: calendar) }
        case .all: return nil
        }
    }

    private var statsSection: some View {
        _ = revision
        let logs = PracticeLogStore.logs.filter { sportSlug == nil || $0.sportSlug == sportSlug }
        let counts = PracticeStats.counts(logs, since: statsSince)
        let ratings = PracticeStats.ratings(logs, since: statsSince)
        let top = counts.first?.count ?? 1
        let insight = PracticeStats.insight(counts, allTypes: SportPractice.types(for: sportSlug))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What you practised", subtitle: "From your practice logs. See where your time goes.")
            WrapLayout(spacing: 8) {
                ForEach(StatsPeriod.allCases) { period in
                    // The last 30 days are free; longer is Pro.
                    let locked = period != .month && !ProAccess.isPro
                    Button {
                        if locked { paywall = .fullHistory } else { statsPeriod = period }
                    } label: {
                        Chip(period.rawValue, isSelected: statsPeriod == period)
                    }
                    .buttonStyle(.plain)
                }
            }
            if counts.isEmpty {
                Text("Nothing logged yet. After your next practice, tap “Log today's practice” and pick what you did.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 16)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(counts, id: \.type) { entry in
                        HStack(spacing: 10) {
                            Text(entry.type)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 130, alignment: .leading)
                            GeometryReader { proxy in
                                Capsule().fill(ProgressColors.practice)
                                    .frame(width: max(8, proxy.size.width * Double(entry.count) / Double(top)))
                            }
                            .frame(height: 12)
                            Text("\(entry.count)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                    if let insight {
                        if ProAccess.isPro {
                            Label(insight, systemImage: "lightbulb.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ink)
                                .padding(.top, 4)
                        } else {
                            Button { paywall = .detailedTracking } label: {
                                Label("See what you practise least", systemImage: "lightbulb")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                }
                .cardStyle(padding: 16)
            }
            if !ratings.isEmpty, ProAccess.isPro {
                VStack(alignment: .leading, spacing: 10) {
                    Text(SportPractice.components(for: sportSlug).title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    ForEach(ratings, id: \.item) { entry in
                        HStack {
                            Text(entry.item).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("\(SportPractice.ratingWords[max(0, min(3, Int(entry.average.rounded()) - 1))]) · \(entry.times)×")
                                .font(.subheadline)
                                .foregroundStyle(entry.average >= 3 ? AppTheme.green : (entry.average < 2 ? AppTheme.red : AppTheme.secondaryText))
                        }
                    }
                }
                .cardStyle(padding: 16)
            }
        }
    }

    // MARK: Schedule & events

    private var scheduleSection: some View {
        let upcomingGames = AthleteStats.upcomingCompetitions(athlete).prefix(4)
        let extras = ExtraPractices.all.filter { $0.day >= DayKey.of(.now, calendar: calendar) }.prefix(4)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Schedule & events", subtitle: "Your practice times and your games — workouts are planned around them.")
            row("Practice days & times", PracticeSchedule.weekdays.isEmpty ? "Not set" : practiceSummary, icon: "clock.fill") { sheet = .schedule }
            row("Team & school calendars", ScheduleStore.feeds.isEmpty ? "Connect TeamSnap, Google or Apple" : "\(ScheduleStore.feeds.count) connected", icon: "link") { sheet = .calendars }
            ButtonRow {
                Button { sheet = .addGame } label: { Label("Add a game", systemImage: "sportscourt.fill") }
                    .buttonStyle(.primary)
                Button { sheet = .addTraining } label: { Label("Add a training", systemImage: "plus") }
                    .buttonStyle(.secondary)
            }
            if !upcomingGames.isEmpty || !extras.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(upcomingGames), id: \.id) { game in
                        Label("\(game.date.formatted(.dateTime.weekday(.abbreviated).month().day())) · \(game.kind.rawValue.capitalized) · \(game.isHome ? "Home" : "Away")\(game.notes.map { " · \($0)" } ?? "")",
                              systemImage: "sportscourt.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                    }
                    ForEach(Array(extras)) { extra in
                        HStack {
                            Label("\(extra.day) · \(extra.title)\(extra.time.map { " · \($0.label)" } ?? "")", systemImage: "figure.run")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Button {
                                ExtraPractices.all = ExtraPractices.all.filter { $0.id != extra.id }
                                revision += 1
                                onPlanInputsChanged()
                            } label: {
                                Image(systemName: "trash").foregroundStyle(AppTheme.secondaryText).frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(extra.title)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)
            }
        }
    }

    private var practiceSummary: String {
        let symbols = calendar.shortWeekdaySymbols
        let times = PracticeTimes.all
        return PracticeSchedule.weekdays.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }
            .map { day in symbols[day - 1] + (times[day].map { " \($0.label)" } ?? "") }
            .joined(separator: ", ")
    }

    private func row(_ title: String, _ detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.fill, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(AppTheme.ink)
                    Text(detail).font(.subheadline).foregroundStyle(AppTheme.secondaryText).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Workouts

    private var workoutsSection: some View {
        let kinds = SessionKinds.all
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your workouts", subtitle: "\(sessions.count) done so far.")
            ForEach(sessions.prefix(5)) { session in
                let kind = kinds[session.clientId] ?? .gym
                HStack(spacing: 12) {
                    Circle().fill(color(kind)).frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label(kind)).font(.headline).foregroundStyle(AppTheme.ink)
                        Text("\(session.startedAt.formatted(.dateTime.weekday(.abbreviated).month().day())) · \(session.minutes) min · \(session.sets.count) sets")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                .cardStyle(padding: 12)
            }
            ButtonRow {
                Button { sheet = .history } label: { Label("All workouts", systemImage: "clock.arrow.circlepath") }
                    .buttonStyle(.secondary)
                Button { sheet = .tests } label: { Label("Tests", systemImage: "stopwatch.fill") }
                    .buttonStyle(.secondary)
            }
        }
    }

    private func color(_ kind: WorkoutKind) -> Color {
        switch kind {
        case .afterPractice: ProgressColors.afterPractice
        case .mobility: ProgressColors.mobility
        default: ProgressColors.workout
        }
    }

    private func label(_ kind: WorkoutKind) -> String {
        switch kind {
        case .gym: "Gym workout"
        case .afterPractice: "After practice"
        case .mobility: "Stretching & mobility"
        case .travel: "Travel workout"
        case .coach: "From your coach"
        }
    }
}

// MARK: - A day

struct DayDetailSheet: View {
    let athlete: Athlete
    let date: Date
    let marks: DayMarks
    let week: GeneratedWeek?
    let onLogPractice: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.startedAt) private var sessions: [Session]

    private var calendar: Calendar { .current }
    private var dayKey: String { DayKey.of(date) }
    private var isFuture: Bool { calendar.startOfDay(for: date) > calendar.startOfDay(for: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(date.formatted(.dateTime.weekday(.wide).month(.wide).day()), subtitle: isFuture ? "Coming up" : nil)
                    let kinds = SessionKinds.all
                    let done = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
                    ForEach(done) { session in
                        let kind = kinds[session.clientId] ?? .gym
                        item(kind == .afterPractice ? "After-practice workout" : (kind == .mobility ? "Stretching & mobility" : "Workout"),
                             "\(session.minutes) min · \(session.sets.count) sets\(session.sessionRPE.map { " · effort \($0)/10" } ?? "")",
                             color: kind == .afterPractice ? ProgressColors.afterPractice : (kind == .mobility ? ProgressColors.mobility : ProgressColors.workout))
                    }
                    if let log = PracticeLogStore.log(on: dayKey) {
                        item("Team practice", practiceSummary(log), color: ProgressColors.practice)
                    } else if marks.practiceScheduled {
                        let time = PracticeSchedule.time(on: date).map { " · \($0.label)" } ?? ""
                        item("Team practice\(time)", isFuture ? "Scheduled" : "Not logged yet", color: ProgressColors.practice, outlined: true)
                    }
                    ForEach(athlete.competitions.filter { calendar.isDate($0.date, inSameDayAs: date) }, id: \.id) { game in
                        item(game.kind.rawValue.capitalized, "\(game.isHome ? "Home" : "Away")\(game.notes.map { " · \($0)" } ?? "")", color: AppTheme.ink, outlined: true)
                    }
                    if let planned = week?.sessions.first(where: { calendar.isDate($0.date, inSameDayAs: date) }), isFuture || done.isEmpty {
                        item("Planned: \(planned.title)", "About \(planned.estimatedMinutes) min · \(planned.items.count) exercises", color: ProgressColors.workout, outlined: true)
                    }
                    if let checkIn = athlete.checkIns.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                        item("Check-in", "Sleep \(checkIn.sleepQuality)/5 · energy \(checkIn.energy)/5 · soreness \(checkIn.soreness)/5", color: AppTheme.green)
                    }
                    if marks.isEmpty && done.isEmpty {
                        Text(isFuture ? "Nothing planned yet." : "Nothing logged on this day.")
                            .font(.body)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    if !isFuture {
                        Button {
                            onLogPractice()
                        } label: {
                            Label(PracticeLogStore.log(on: dayKey) == nil ? "Log a team practice on this day" : "Edit this practice", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.primary)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func practiceSummary(_ log: PracticeLog) -> String {
        let types = log.types.isEmpty ? "" : log.types.joined(separator: ", ") + " · "
        return "\(types)hard \(log.hard)/5 · went \(log.went)/5 · mood \(log.mood)/5"
    }

    private func item(_ title: String, _ detail: String, color: Color, outlined: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(color, lineWidth: outlined ? 3 : 0)
                .background(Circle().fill(outlined ? Color.clear : color))
                .frame(width: 18, height: 18)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(AppTheme.ink)
                Text(detail).font(.subheadline).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14)
    }
}

// MARK: - Logging a practice

struct PracticeLogSheet: View {
    let athlete: Athlete
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var sportSlug: String
    @State private var level = ProAccess.isPro ? TrackingLevel.current : .easy
    @State private var showingPaywall = false
    @State private var types: Set<String> = []
    @State private var hard = 3
    @State private var went = 3
    @State private var mood = 3
    @State private var minutes = 90
    @State private var tiredMuscles: Set<String> = []
    @State private var ratings: [String: Int] = [:]
    @State private var note = ""
    @State private var existing: PracticeLog?

    init(athlete: Athlete, date: Date) {
        self.athlete = athlete
        self.date = date
        let sport = athlete.activeSport?.sportSlug ?? athlete.sports.first?.sportSlug ?? ""
        _sportSlug = State(initialValue: sport)
        let log = PracticeLogStore.log(on: DayKey.of(date), sportSlug: sport)
        _existing = State(initialValue: log)
        if let log {
            _types = State(initialValue: Set(log.types))
            _hard = State(initialValue: log.hard)
            _went = State(initialValue: log.went)
            _mood = State(initialValue: log.mood)
            _minutes = State(initialValue: log.minutes ?? 90)
            _tiredMuscles = State(initialValue: Set(log.tiredMuscles))
            _ratings = State(initialValue: log.ratings)
            _note = State(initialValue: log.note ?? "")
            if !log.tiredMuscles.isEmpty || !log.ratings.isEmpty { _level = State(initialValue: .exact) }
        } else if let time = PracticeSchedule.time(on: date) {
            _minutes = State(initialValue: max(15, time.end - time.start))
        }
    }

    var body: some View {
        StepScaffold(
            title: "Team practice",
            subtitle: date.formatted(.dateTime.weekday(.wide).month().day()) + " — log it your way. Easy takes 10 seconds.",
            buttonTitle: "Save", onBack: { dismiss() },
            onContinue: save
        ) {
            if athlete.sports.count > 1 {
                WrapLayout(spacing: 8) {
                    ForEach(athlete.sports, id: \.id) { sport in
                        Button { sportSlug = sport.sportSlug; types = [] } label: {
                            Chip(allSportsBySlug[sport.sportSlug]?.name ?? sport.sportSlug, isSelected: sportSlug == sport.sportSlug)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(TrackingLevel.allCases, id: \.self) { value in
                    let locked = value == .exact && !ProAccess.isPro
                    Button {
                        if locked {
                            showingPaywall = true
                        } else {
                            level = value
                            TrackingLevel.current = value
                        }
                    } label: {
                        Chip(value.title, isSelected: level == value)
                    }
                    .buttonStyle(.plain)
                }
            }

            section("What did you do?") {
                WrapLayout(spacing: 8) {
                    ForEach(SportPractice.types(for: sportSlug), id: \.self) { type in
                        Button {
                            if types.contains(type) { types.remove(type) } else { types.insert(type) }
                        } label: { Chip(type, isSelected: types.contains(type)) }
                            .buttonStyle(.plain)
                    }
                }
            }
            scale("How hard was it?", low: "Easy", high: "Exhausting", value: $hard)
            scale("How did it go?", low: "Badly", high: "Great", value: $went)
            section("How do you feel now?") {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        let faces = ["😣", "😕", "😐", "🙂", "😄"]
                        Button { mood = value } label: {
                            Text(faces[value - 1])
                                .font(.system(size: 30))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(mood == value ? AppTheme.accent.opacity(0.15) : AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mood \(value) of 5")
                    }
                }
            }
            section("How long? \(minutes) min") {
                Stepper("", value: $minutes, in: 15...300, step: 15).labelsHidden()
            }

            if level == .exact {
                section("What feels worked?") {
                    WrapLayout(spacing: 8) {
                        ForEach(MuscleRegion.allCases, id: \.self) { region in
                            Button {
                                if tiredMuscles.contains(region.rawValue) { tiredMuscles.remove(region.rawValue) } else { tiredMuscles.insert(region.rawValue) }
                            } label: { Chip(region.displayName, isSelected: tiredMuscles.contains(region.rawValue)) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                let components = SportPractice.components(for: sportSlug)
                section(components.title) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(components.items, id: \.self) { component in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(component).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                                HStack(spacing: 6) {
                                    ForEach(1...4, id: \.self) { value in
                                        Button {
                                            ratings[component] = ratings[component] == value ? nil : value
                                        } label: {
                                            Text(SportPractice.ratingWords[value - 1])
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(ratings[component] == value ? AppTheme.onAccent : AppTheme.ink)
                                                .frame(maxWidth: .infinity, minHeight: 38)
                                                .background(ratings[component] == value ? AppTheme.accent : AppTheme.fill, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                section("Note (optional)") {
                    TextField("Anything to remember?", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            if let existing {
                Button("Delete this log", role: .destructive) {
                    PracticeLogStore.delete(existing)
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(AppTheme.red)
                .frame(maxWidth: .infinity)
            }
        }
        .proFeature(isPresented: $showingPaywall, athlete: athlete, feature: .detailedTracking)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(AppTheme.ink)
            content()
        }
    }

    private func scale(_ title: String, low: String, high: String, value: Binding<Int>) -> some View {
        section(title) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { option in
                        Button { value.wrappedValue = option } label: {
                            Text("\(option)")
                                .font(.headline)
                                .foregroundStyle(value.wrappedValue == option ? AppTheme.onAccent : AppTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(value.wrappedValue == option ? AppTheme.accent : AppTheme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack { Text(low); Spacer(); Text(high) }
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let order = SportPractice.types(for: sportSlug)
        PracticeLogStore.save(PracticeLog(
            id: existing?.id ?? UUID().uuidString, day: DayKey.of(date), sportSlug: sportSlug,
            types: order.filter { types.contains($0) } + types.subtracting(order).sorted(),
            hard: hard, went: went, mood: mood, minutes: minutes,
            tiredMuscles: level == .exact ? tiredMuscles.sorted() : [],
            ratings: level == .exact ? ratings : [:],
            note: level == .exact && !trimmed.isEmpty ? trimmed : nil
        ))
        dismiss()
    }
}

// MARK: - Practice days & times

struct PracticeScheduleSheet: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var days = PracticeSchedule.weekdays
    @State private var times = PracticeTimes.all

    var body: some View {
        StepScaffold(title: "Practice days & times", subtitle: "Tap the days you have team practice and set when it is. Workouts are planned around it.",
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: save) {
            VStack(spacing: 10) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                    dayRow(weekday)
                }
            }
        }
    }

    private func dayRow(_ weekday: Int) -> some View {
        let on = days.contains(weekday)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                if on { days.remove(weekday) } else {
                    days.insert(weekday)
                    if times[weekday] == nil { times[weekday] = PracticeTime(start: 16 * 60, end: 18 * 60) }
                }
            } label: {
                OptionRow(title: Calendar.current.weekdaySymbols[weekday - 1], subtitle: on ? times[weekday]?.label ?? "Practice" : "No practice",
                          systemImage: on ? "sportscourt.fill" : "circle", isSelected: on)
            }
            .buttonStyle(.plain)
            if on {
                HStack {
                    DatePicker("From", selection: minutes(weekday, \.start), displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: minutes(weekday, \.end), displayedComponents: .hourAndMinute)
                }
                .font(.subheadline.weight(.semibold))
                .tint(AppTheme.accent)
                .padding(.horizontal, 6)
            }
        }
    }

    private func minutes(_ weekday: Int, _ keyPath: WritableKeyPath<PracticeTime, Int>) -> Binding<Date> {
        Binding(
            get: {
                let value = times[weekday]?[keyPath: keyPath] ?? 16 * 60
                return Calendar.current.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var time = times[weekday] ?? PracticeTime(start: 16 * 60, end: 18 * 60)
                time[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                times[weekday] = time
            }
        )
    }

    private func save() {
        PracticeSchedule.weekdays = days
        PracticeTimes.all = times.filter { days.contains($0.key) }
        onSaved()
        dismiss()
    }
}

/// A one-off team training (a weekend session, a camp day).
struct ExtraPracticeSheet: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var title = "Team training"
    @State private var start = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    @State private var end = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now) ?? .now

    var body: some View {
        StepScaffold(title: "Add a training", subtitle: "An extra team session. It counts as a practice day, so your gym workout moves off it.",
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: save) {
            DatePicker("Day", selection: $date, displayedComponents: .date)
                .font(.headline)
                .tint(AppTheme.accent)
            TextField("What is it?", text: $title)
                .font(.title3)
                .padding(16)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $end, displayedComponents: .hourAndMinute)
            }
            .font(.subheadline.weight(.semibold))
            .tint(AppTheme.accent)
        }
    }

    private func save() {
        let calendar = Calendar.current
        func minutes(_ date: Date) -> Int { calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date) }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        ExtraPractices.all = ExtraPractices.all + [ExtraPractice(day: DayKey.of(date), title: trimmed.isEmpty ? "Team training" : trimmed,
                                                               time: PracticeTime(start: minutes(start), end: max(minutes(end), minutes(start) + 15)))]
        onSaved()
        dismiss()
    }
}

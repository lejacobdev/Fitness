import SwiftData
import SwiftUI

struct LiveSessionLaunch: Identifiable {
    let id = UUID()
    let planned: GeneratedSession?
}

enum QuickAction: String, Identifiable, CaseIterable {
    case logWorkout, checkIn, addGame, improve, history, fuel
    var id: String { rawValue }
}

/// The home screen, laid out the way Cal AI lays out its own: logo and a
/// streak flame on top, a week strip, one hero card with a big number and a
/// ring, three small ring cards, then the day's content as a list of
/// thumbnail rows, and a floating black "+" for everything else.
struct TodayView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let week: GeneratedWeek?
    @Binding var selectedTab: AppTab
    let onPlanInputsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var allSessions: [Session]
    @State private var selectedDate = Date.now
    @State private var catalogue = Catalogue()
    @State private var readinessOverridden = false
    @State private var liveLaunch: LiveSessionLaunch?
    @State private var activeSheet: TodaySheet?
    @State private var pendingAction: QuickAction?
    @State private var detailItem: CatalogueItem?
    @State private var coachReport: CoachReportContent?

    enum TodaySheet: String, Identifiable {
        case quickActions, checkIn, addGame, history, fuel, exercises
        var id: String { rawValue }
    }

    private var calendar: Calendar { .current }
    private var isSelectedToday: Bool { calendar.isDateInToday(selectedDate) }
    private var todaysCheckIn: CheckIn? { AthleteStats.todaysCheckIn(athlete) }

    private var plannedForSelectedDay: GeneratedSession? {
        week?.sessions.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var readinessAdjustment: ReadinessApplier.Result? {
        guard isSelectedToday, !readinessOverridden,
              let planned = plannedForSelectedDay, let band = todaysCheckIn?.readinessBand
        else { return nil }
        return ReadinessApplier.apply(to: planned, band: band)
    }

    private var displayedSession: GeneratedSession? {
        readinessAdjustment?.session ?? plannedForSelectedDay
    }

    private var gameOnSelectedDay: Competition? {
        athlete.competitions.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var loggedOnSelectedDay: [Session] {
        allSessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDate) }
    }

    private var selectedWeekInterval: DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)
    }

    private var loggedThisWeek: Int {
        guard let interval = selectedWeekInterval else { return 0 }
        return allSessions.filter { interval.contains($0.startedAt) }.count
    }

    private var plannedThisWeek: Int {
        max(week?.sessions.count ?? 0, 1)
    }

    private var markedDays: Set<Date> {
        var days = Set((week?.sessions ?? []).map { calendar.startOfDay(for: $0.date) })
        days.formUnion(allSessions.prefix(60).map { calendar.startOfDay(for: $0.startedAt) })
        days.formUnion(athlete.competitions.map { calendar.startOfDay(for: $0.date) })
        return days
    }

    private var streak: Int {
        AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: allSessions.map(\.startedAt))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        VStack(alignment: .leading, spacing: 8) {
                            WeekStrip(selection: $selectedDate, marked: markedDays, gameDays: Set(athlete.competitions.map { calendar.startOfDay(for: $0.date) }))
                            WeekStripLegend()
                        }
                        if !isSelectedToday {
                            Button { selectedDate = .now } label: {
                                Label("Back to today", systemImage: "arrow.uturn.backward")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(AppTheme.ink)
                        }
                        // The day's plan: the big widget.
                        if let game = gameOnSelectedDay {
                            gameDayCard(game)
                        } else if let session = displayedSession {
                            workoutCard(session)
                        } else {
                            restDayCard
                        }
                        // Overview widgets: each opens what it's about.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            statCardItems
                        }
                        ForEach(SavedSkillPlans.days(on: selectedDate, athlete: athlete, catalogue: catalogue)) { day in
                            SkillPlanTodayCard(day: day, catalogue: catalogue) { detailItem = $0 }
                        }
                        if isSelectedToday, let coachReport {
                            CoachHeadlineCard(report: coachReport, catalogue: catalogue)
                        }
                        if isSelectedToday {
                            GettingStartedCard(
                                athlete: athlete, hasLoggedSession: !allSessions.isEmpty,
                                onCheckIn: { activeSheet = .checkIn },
                                onAddGame: { activeSheet = .addGame },
                                onStartSession: {
                                    liveLaunch = LiveSessionLaunch(planned: gameOnSelectedDay == nil ? displayedSession : nil)
                                },
                                onImprove: { selectedTab = .improve },
                                onLibrary: { selectedTab = .library }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)

                FloatingActionButton(accessibilityLabel: "Add: log a workout, check in, add a game, food or past workouts") {
                    activeSheet = .quickActions
                }
                .padding(20)

            }
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: allSessions.count + athlete.checkIns.count) {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                coachReport = CoachStore.reportForThisWeek(athlete: athlete, sessions: allSessions, catalogue: catalogue, context: modelContext)
            }
            .onChange(of: selectedDate) { readinessOverridden = false }
            .sheet(item: $activeSheet, onDismiss: runPendingAction) { sheet in
                switch sheet {
                case .quickActions:
                    QuickActionsSheet { action in
                        pendingAction = action
                        activeSheet = nil
                    }
                    .presentationDetents([.height(560)])
                case .checkIn:
                    CheckInSheet(athlete: athlete)
                        .presentationDetents([.large])
                case .addGame:
                    AddGameSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .history:
                    SessionHistoryView()
                case .fuel:
                    FuelView(athlete: athlete, todaysSession: plannedForSelectedDay)
                case .exercises:
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Do them in this order. Tap one to watch how it's done.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                ForEach(Array((displayedSession?.items ?? []).enumerated()), id: \.element.order) { index, item in
                                    plannedItemRow(item, number: index + 1)
                                }
                            }
                            .padding(20)
                        }
                        .appScreen()
                        .navigationTitle(displayedSession?.title ?? "Exercises")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { activeSheet = nil }.fontWeight(.semibold) }
                        }
                        .sheet(item: $detailItem) { item in
                            NavigationStack { ItemDetailView(item: item) }
                        }
                    }
                }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
            .fullScreenCover(item: $liveLaunch) { launch in
                LiveSessionView(athlete: athlete, apiClient: apiClient, planned: launch.planned)
            }
        }
    }

    private func runPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .logWorkout: liveLaunch = LiveSessionLaunch(planned: nil)
        case .checkIn: activeSheet = .checkIn
        case .addGame: activeSheet = .addGame
        case .improve: selectedTab = .improve
        case .history: activeSheet = .history
        case .fuel: activeSheet = .fuel
        }
    }

    // MARK: - Header

    private var greeting: String {
        let hour = calendar.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSelectedToday ? "\(greeting) · \(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))" : selectedDate.formatted(.dateTime.month(.wide).day()))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(isSelectedToday ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppTheme.orange)
                    Text("\(streak)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.ink)
                        .contentTransition(.numericText())
                    Text("day streak")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.card, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(streak) day streak: days in a row you checked in or trained")
            }
            HStack(spacing: 8) {
                Text("Training for")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                SportSwitcher(athlete: athlete, onChanged: onPlanInputsChanged)
            }
        }
    }

    // MARK: - Do this now

    /// The one thing to do next, first on the screen: the check-in if it's
    /// still to do, then the day's workout with its Start button right on it
    /// (or the game-day / rest-day card).
    @ViewBuilder
    private var doThisNow: some View {
        if isSelectedToday, todaysCheckIn == nil, gameOnSelectedDay == nil {
            VStack(alignment: .leading, spacing: 10) {
                StepLabel(1, "First, tell us how you feel — 10 seconds")
                CheckInCard(athlete: athlete)
                if displayedSession != nil { StepLabel(2, "Then do today's workout — it adapts to your answers").padding(.top, 6) }
            }
        }
        if let game = gameOnSelectedDay {
            gameDayCard(game)
        } else if let session = displayedSession {
            workoutCard(session)
        } else {
            restDayCard
        }
    }

    private func workoutCard(_ session: GeneratedSession) -> some View {
        let done = isSelectedToday && !loggedOnSelectedDay.isEmpty
        let focus = session.focusQualities.first.flatMap { qualitiesBySlug[$0]?.shortName }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isSelectedToday ? "TODAY'S WORKOUT" : "\(selectedDate.formatted(.dateTime.weekday(.wide)).uppercased())'S WORKOUT")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if done { Tag("Done", color: AppTheme.green) }
            }
            Text(session.title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 14) {
                Label("About \(session.estimatedMinutes) min", systemImage: "clock")
                Label("\(session.items.count) exercises", systemImage: "list.bullet")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .labelStyle(CompactLabelStyle())
            if let focus {
                Text("Works on: \(focus.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if let reason = readinessAdjustment?.reason {
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(AppTheme.color(for: todaysCheckIn?.readinessBand)).frame(width: 8, height: 8).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("We made it lighter because of your check-in").font(.footnote.bold()).foregroundStyle(AppTheme.ink)
                        Text(reason).font(.footnote).foregroundStyle(AppTheme.secondaryText)
                        Button("I feel fine — use the full workout") { readinessOverridden = true }
                            .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    }
                }
            } else if isSelectedToday, readinessOverridden {
                Button("Use the lighter workout instead") { readinessOverridden = false }
                    .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.ink)
            }
            // What's in it: a row of thumbnails, each opening its how-to.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(session.items, id: \.order) { item in
                        let catalogueItem = catalogue.item(item.itemSlug)
                        Button { detailItem = catalogueItem } label: { ItemThumbnail(item: catalogueItem, size: 56) }
                            .buttonStyle(.plain)
                            .disabled(catalogueItem == nil)
                            .accessibilityLabel(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                    }
                    Button { activeSheet = .exercises } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "list.bullet").font(.subheadline.weight(.semibold))
                            Text("See all").font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            if isSelectedToday {
                if done {
                    Button { liveLaunch = LiveSessionLaunch(planned: nil) } label: { Label("Log another workout", systemImage: "plus") }
                        .buttonStyle(.secondary)
                } else {
                    Button { liveLaunch = LiveSessionLaunch(planned: session) } label: { Label("Start workout", systemImage: "play.fill") }
                        .buttonStyle(.primary)
                }
            } else if selectedDate > .now {
                Text("This is planned for \(selectedDate.formatted(.dateTime.weekday(.wide))). You can also do it now.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                StartWorkoutButton("Do this workout now", session: session, prominent: false)
            } else {
                Text(loggedOnSelectedDay.isEmpty ? "This day has passed." : "Done on this day.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    /// The workout's exercises, each opening its how-to.
    @ViewBuilder
    private var exercisesSection: some View {
        if gameOnSelectedDay == nil, let session = displayedSession {
            SectionHeader("What's in this workout", subtitle: "Do them in this order. Tap one to watch how it's done.")
            ForEach(Array(session.items.enumerated()), id: \.element.order) { index, item in
                plannedItemRow(item, number: index + 1)
            }
        }
    }

    /// Readiness, sleep, next game and the week — each card opens what it's about.
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("How you're doing", subtitle: todaysCheckIn == nil
                ? "The first two fill in after today's check-in. Tap any card for more."
                : (todaysCheckIn?.readinessBand == nil ? "After a week of check-ins, we'll tell you how hard to train each day." : "Based on this morning's check-in. Tap any card for more."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statCardItems
            }
        }
    }

    // MARK: - Stat cards

    /// The overview widgets under the day's plan. Each opens what it's about;
    /// the check-in opens as an overlay.
    @ViewBuilder
    private var statCardItems: some View {
        let band = todaysCheckIn?.readinessBand
        let sleep = todaysCheckIn?.sleepQuality
        let nextGame = AthleteStats.upcomingCompetitions(athlete).first
        let daysToGame = nextGame.map { AthleteStats.daysUntil($0.date) }
        let last = allSessions.first
        Button { activeSheet = .checkIn } label: {
            if todaysCheckIn == nil {
                WidgetTile(value: "Check in", label: "How you feel", progress: 0, color: AppTheme.orange, systemImage: "sun.max.fill",
                             caption: "10 seconds — tunes today's workout", highlight: true)
            } else {
                WidgetTile(
                    value: band.map { $0 == .green ? "Ready to push" : ($0 == .amber ? "Go steady" : "Take it easy") } ?? "Learning you",
                    label: "Ready to train?",
                    progress: band.map { $0 == .green ? 1 : ($0 == .amber ? 0.6 : 0.3) } ?? 0.15,
                    color: AppTheme.color(for: band),
                    systemImage: "waveform.path.ecg",
                    caption: band == nil ? "Needs a week of check-ins" : "Tap to change your answers"
                )
            }
        }
        .buttonStyle(.plain)
        Button { activeSheet = .checkIn } label: { WidgetTile(
            value: sleep.map { "\($0) of 5" } ?? "Not yet",
            label: "Sleep last night",
            progress: Double(sleep ?? 0) / 5,
            color: AppTheme.purple,
            systemImage: "moon.fill",
            caption: sleep.map { $0 >= 4 ? "Well rested" : ($0 == 3 ? "Okay" : "Short on sleep") } ?? "Fills in after your check-in"
        ) }
        .buttonStyle(.plain)
        Button {
            if nextGame == nil { activeSheet = .addGame } else { selectedTab = .plan }
        } label: { WidgetTile(
            value: daysToGame.map { $0 == 0 ? "Today" : ($0 == 1 ? "Tomorrow" : "In \($0) days") } ?? "None yet",
            label: "Next game",
            progress: daysToGame.map { max(0.05, 1 - Double($0) / 14) } ?? 0,
            color: AppTheme.brand,
            systemImage: "sportscourt.fill",
            caption: nextGame == nil ? "Tap to add one" : "Training eases off before it"
        ) }
        .buttonStyle(.plain)
        Button { selectedTab = .plan } label: { WidgetTile(
            value: "\(loggedThisWeek) of \(week?.sessions.count ?? 0)",
            label: "Workouts this week",
            progress: Double(loggedThisWeek) / Double(plannedThisWeek),
            color: AppTheme.ink,
            systemImage: "flame.fill",
            caption: "Tap to see the whole week"
        ) }
        .buttonStyle(.plain)
        Button { activeSheet = .fuel } label: { WidgetTile(
            value: gameOnSelectedDay != nil ? "Game day" : (displayedSession != nil ? "Training day" : "Rest day"),
            label: "Food & water",
            progress: 0.5,
            color: AppTheme.green,
            systemImage: "fork.knife",
            caption: "What to eat and drink today"
        ) }
        .buttonStyle(.plain)
        Button { activeSheet = .history } label: { WidgetTile(
            value: last.map { calendar.isDateInToday($0.startedAt) ? "Today" : (calendar.isDateInYesterday($0.startedAt) ? "Yesterday" : $0.startedAt.formatted(.dateTime.weekday(.abbreviated))) } ?? "None yet",
            label: "Last workout",
            progress: last == nil ? 0 : 1,
            color: AppTheme.blue,
            systemImage: "clock.arrow.circlepath",
            caption: last.map { "\($0.minutes) min" + ($0.sessionRPE.map { " · effort \($0)/10" } ?? "") } ?? "Your workouts show here"
        ) }
        .buttonStyle(.plain)
    }

    private func plannedItemRow(_ item: GeneratedPlannedItem, number: Int) -> some View {
        let catalogueItem = catalogue.item(item.itemSlug)
        return Button {
            detailItem = catalogueItem
        } label: {
            HStack(spacing: 14) {
                ItemThumbnail(item: catalogueItem)
                    .overlay(alignment: .topLeading) {
                        Text("\(number)")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.inkInverse)
                            .frame(width: 20, height: 20)
                            .background(AppTheme.ink, in: Circle())
                            .offset(x: -6, y: -6)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text(DoseFormatter.text(item.dose))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                    Text(DoseFormatter.rest(item.restSec))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    if let quality = qualitiesBySlug[item.quality] {
                        Tag("Builds \(quality.shortName.lowercased())", color: AppTheme.orange)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 12)
        }
        .buttonStyle(.plain)
        .disabled(catalogueItem == nil)
    }

    private func gameDayCard(_ game: Competition) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.brand)
                .frame(width: 64, height: 64)
                .background(AppTheme.brand.opacity(0.12), in: Circle())
            Text(game.kind == .tournament ? "Tournament day" : (game.kind == .meet ? "Meet day" : "Game day"))
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            Text("No workout today — save your energy for the game. Eat a proper meal about 3 hours before, have a snack an hour before, warm up, and play.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.purple)
                .frame(width: 64, height: 64)
                .background(AppTheme.purple.opacity(0.12), in: Circle())
            Text("Rest day")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            Text("No workout planned today. Resting is how your body gets stronger from training — a good night's sleep is today's job.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            if isSelectedToday {
                Button("Log a workout anyway") { liveLaunch = LiveSessionLaunch(planned: nil) }
                    .buttonStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }

    // MARK: - Recent activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("Your recent workouts")
                Button("See all") { activeSheet = .history }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ForEach(allSessions.prefix(3)) { session in
                SessionRow(session: session)
            }
        }
    }
}

/// One logged session as a Cal AI-style list card.
struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.source == .watch ? "applewatch" : "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(AppTheme.ink)
                .frame(width: 64, height: 64)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.startedAt.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(session.startedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                HStack(spacing: 10) {
                    Label("\(session.minutes) min", systemImage: "clock")
                    Label("\(session.sets.count) sets done", systemImage: "list.bullet")
                    if let rpe = session.sessionRPE {
                        Label("Effort \(rpe)/10", systemImage: "flame")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
                .labelStyle(CompactLabelStyle())
            }
        }
        .cardStyle(padding: 12)
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

/// Cal AI's "+" sheet: a grid of big tiles for everything that isn't the
/// day's main action.
struct QuickActionsSheet: View {
    let onSelect: (QuickAction) -> Void

    private struct Tile: Identifiable {
        let action: QuickAction
        let title: String
        let detail: String
        let icon: String
        var id: QuickAction { action }
    }

    private let tiles: [Tile] = [
        Tile(action: .logWorkout, title: "Log a workout", detail: "Something you did that isn't in your plan", icon: "figure.run"),
        Tile(action: .checkIn, title: "Check in", detail: "How you slept and feel today", icon: "sun.max.fill"),
        Tile(action: .addGame, title: "Add a game", detail: "Your plan builds up to it", icon: "sportscourt.fill"),
        Tile(action: .improve, title: "Improve a skill", detail: "A plan for one skill, like shooting", icon: "chart.line.uptrend.xyaxis"),
        Tile(action: .fuel, title: "Food & water", detail: "What to eat and drink today", icon: "fork.knife"),
        Tile(action: .history, title: "Past workouts", detail: "Everything you've done", icon: "clock.arrow.circlepath"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(AppTheme.hairline)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            Text("What do you want to do?")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tiles) { tile in
                    Button {
                        onSelect(tile.action)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: tile.icon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(tile.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(tile.detail)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2, reservesSpace: true)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 126)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .appScreen()
    }
}

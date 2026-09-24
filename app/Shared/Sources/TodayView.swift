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
        case quickActions, checkIn, addGame, history, fuel
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
                        WeekStrip(selection: $selectedDate, marked: markedDays, gameDays: Set(athlete.competitions.map { calendar.startOfDay(for: $0.date) }))
                        doThisNow
                        exercisesSection
                        ForEach(SavedSkillPlans.days(on: selectedDate, athlete: athlete, catalogue: catalogue)) { day in
                            SkillPlanTodayCard(day: day, catalogue: catalogue) { detailItem = $0 }
                        }
                        statusSection
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
                        if isSelectedToday, let coachReport {
                            SectionHeader("Coach notes", subtitle: "What your last week of training says.")
                            CoachHeadlineCard(report: coachReport, catalogue: catalogue)
                        }
                        if !allSessions.isEmpty {
                            recentActivity
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)

                FloatingActionButton(accessibilityLabel: "Quick actions") {
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
                    .presentationDetents([.height(500)])
                case .checkIn:
                    CheckInSheet(athlete: athlete)
                case .addGame:
                    AddGameSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .history:
                    SessionHistoryView()
                case .fuel:
                    FuelView(athlete: athlete, todaysSession: plannedForSelectedDay)
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
                    Text(greeting)
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
                    Text(streak == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.card, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(streak) day streak")
            }
            SportSwitcher(athlete: athlete, onChanged: onPlanInputsChanged)
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
                StepLabel(1, "Check in first — 10 seconds")
                CheckInCard(athlete: athlete)
                if displayedSession != nil { StepLabel(2, "Then do today's workout").padding(.top, 6) }
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
                Label("\(session.estimatedMinutes) min", systemImage: "clock")
                Label("\(session.items.count) exercises", systemImage: "list.bullet")
                if let focus { Label(focus, systemImage: "scope") }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .labelStyle(CompactLabelStyle())
            if let reason = readinessAdjustment?.reason {
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(AppTheme.color(for: todaysCheckIn?.readinessBand)).frame(width: 8, height: 8).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Made lighter for how you feel today").font(.footnote.bold()).foregroundStyle(AppTheme.ink)
                        Text(reason).font(.footnote).foregroundStyle(AppTheme.secondaryText)
                        Button("Use the original workout") { readinessOverridden = true }
                            .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    }
                }
            } else if isSelectedToday, readinessOverridden {
                Button("Use the lighter workout instead") { readinessOverridden = false }
                    .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.ink)
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
                StartWorkoutButton("Do this workout now", session: session, prominent: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    /// The workout's exercises, each opening its how-to.
    @ViewBuilder
    private var exercisesSection: some View {
        if gameOnSelectedDay == nil, let session = displayedSession {
            SectionHeader("The exercises", subtitle: "Tap one to watch how it's done and see the muscles it works.")
            ForEach(session.items, id: \.order) { item in
                plannedItemRow(item)
            }
        }
    }

    /// Readiness, sleep, next game and the week — each card opens what it's about.
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("How you're doing", subtitle: todaysCheckIn == nil
                ? "Readiness and sleep fill in after today's check-in."
                : (todaysCheckIn?.readinessBand == nil ? "Readiness starts adjusting your workouts after a week of check-ins." : "From this morning's check-in."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statCardItems
            }
        }
    }

    // MARK: - Stat cards

    @ViewBuilder
    private var statCardItems: some View {
        let band = todaysCheckIn?.readinessBand
        let sleep = todaysCheckIn?.sleepQuality
        let nextGame = AthleteStats.upcomingCompetitions(athlete).first
        let daysToGame = nextGame.map { AthleteStats.daysUntil($0.date) }
            Button { activeSheet = .checkIn } label: { RingStatCard(
                value: band.map { $0.rawValue.capitalized } ?? (todaysCheckIn == nil ? "Check in" : "Learning"),
                label: "Readiness",
                progress: band.map { $0 == .green ? 1 : ($0 == .amber ? 0.6 : 0.3) } ?? 0,
                color: AppTheme.color(for: band),
                systemImage: "waveform.path.ecg"
            ) }
            .buttonStyle(.plain)
            .disabled(todaysCheckIn != nil)
            Button { activeSheet = .checkIn } label: { RingStatCard(
                value: sleep.map { "\($0)/5" } ?? "—",
                label: "Sleep",
                progress: Double(sleep ?? 0) / 5,
                color: AppTheme.purple,
                systemImage: "moon.fill"
            ) }
            .buttonStyle(.plain)
            .disabled(todaysCheckIn != nil)
            Button {
                if nextGame == nil { activeSheet = .addGame } else { selectedTab = .plan }
            } label: { RingStatCard(
                value: daysToGame.map { $0 == 0 ? "Today" : "\($0)d" } ?? "Add",
                label: "Next game",
                progress: daysToGame.map { max(0.05, 1 - Double($0) / 14) } ?? 0,
                color: AppTheme.brand,
                systemImage: "sportscourt.fill"
            ) }
            .buttonStyle(.plain)
            Button { activeSheet = .history } label: { RingStatCard(
                value: "\(loggedThisWeek) of \(week?.sessions.count ?? 0)",
                label: "Workouts this week",
                progress: Double(loggedThisWeek) / Double(plannedThisWeek),
                color: AppTheme.ink,
                systemImage: "flame.fill"
            ) }
            .buttonStyle(.plain)
    }

    private func plannedItemRow(_ item: GeneratedPlannedItem) -> some View {
        let catalogueItem = catalogue.item(item.itemSlug)
        return Button {
            detailItem = catalogueItem
        } label: {
            HStack(spacing: 14) {
                ItemThumbnail(item: catalogueItem)
                VStack(alignment: .leading, spacing: 5) {
                    Text(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(DoseFormatter.text(item.dose))
                        Text("·")
                        Text("\(item.restSec)s rest")
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    if let quality = qualitiesBySlug[item.quality] {
                        Tag(quality.shortName, color: AppTheme.orange)
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
            Text("The warm-up sequence and nothing else. Eat 3 hours out, top up an hour before, and go play.")
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
            Text("Recovery is part of the plan. Sleep is the best thing you can do for your training today.")
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
                SectionTitle("Recent activity")
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
                    Label("\(session.sets.count) sets", systemImage: "list.bullet")
                    if let rpe = session.sessionRPE {
                        Label("RPE \(rpe)", systemImage: "flame")
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
        let icon: String
        var id: QuickAction { action }
    }

    private let tiles: [Tile] = [
        Tile(action: .logWorkout, title: "Log a workout", icon: "figure.run"),
        Tile(action: .checkIn, title: "Check-in", icon: "sun.max.fill"),
        Tile(action: .addGame, title: "Add a game", icon: "sportscourt.fill"),
        Tile(action: .improve, title: "Improve a skill", icon: "chart.line.uptrend.xyaxis"),
        Tile(action: .fuel, title: "Fuel & water", icon: "fork.knife"),
        Tile(action: .history, title: "History", icon: "clock.arrow.circlepath"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(AppTheme.hairline)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tiles) { tile in
                    Button {
                        onSelect(tile.action)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: tile.icon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(tile.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110)
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

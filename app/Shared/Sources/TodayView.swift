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
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        WeekStrip(selection: $selectedDate, marked: markedDays)
                        heroCard
                        statCards
                        if isSelectedToday, let coachReport {
                            CoachHeadlineCard(report: coachReport, catalogue: catalogue)
                        }
                        if isSelectedToday {
                            checkInSection
                        }
                        daySection
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

    private var header: some View {
        HStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            Text("Student Athlete")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(AppTheme.orange)
                Text("\(streak)")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.card, in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
        }
    }

    // MARK: - Hero

    private var heroNumber: String {
        if gameOnSelectedDay != nil { return "Game" }
        if let displayedSession { return "\(displayedSession.estimatedMinutes)" }
        return "Rest"
    }

    private var heroLabel: String {
        if gameOnSelectedDay != nil { return "Warm-up only today" }
        if displayedSession != nil { return "Minutes planned" }
        return "Recovery day"
    }

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(heroNumber)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(heroLabel)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                if let displayedSession {
                    Tag(displayedSession.title, color: AppTheme.ink)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            RingView(progress: Double(loggedThisWeek) / Double(plannedThisWeek), color: AppTheme.ink, lineWidth: 10) {
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(loggedThisWeek)/\(week?.sessions.count ?? 0)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(width: 112, height: 112)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(loggedThisWeek) of \(week?.sessions.count ?? 0) sessions done this week")
        }
        .cardStyle(padding: 22)
    }

    // MARK: - Stat cards

    private var statCards: some View {
        let band = todaysCheckIn?.readinessBand
        let sleep = todaysCheckIn?.sleepQuality
        let nextGame = AthleteStats.upcomingCompetitions(athlete).first
        let daysToGame = nextGame.map { AthleteStats.daysUntil($0.date) }
        return HStack(spacing: 12) {
            RingStatCard(
                value: band.map { $0.rawValue.capitalized } ?? "—",
                label: "Readiness",
                progress: band.map { $0 == .green ? 1 : ($0 == .amber ? 0.6 : 0.3) } ?? 0,
                color: AppTheme.color(for: band),
                systemImage: "waveform.path.ecg"
            )
            RingStatCard(
                value: sleep.map { "\($0)/5" } ?? "—",
                label: "Sleep",
                progress: Double(sleep ?? 0) / 5,
                color: AppTheme.purple,
                systemImage: "moon.fill"
            )
            RingStatCard(
                value: daysToGame.map { $0 == 0 ? "Today" : "\($0)d" } ?? "—",
                label: "Next game",
                progress: daysToGame.map { max(0.05, 1 - Double($0) / 14) } ?? 0,
                color: AppTheme.brand,
                systemImage: "sportscourt.fill"
            )
        }
    }

    // MARK: - Check-in

    @ViewBuilder
    private var checkInSection: some View {
        if let todaysCheckIn {
            if todaysCheckIn.readinessBand == nil {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppTheme.purple)
                    Text("Checked in. Still learning your baseline — readiness adjustments start after a week of check-ins.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)
            }
        } else {
            CheckInCard(athlete: athlete)
        }
    }

    // MARK: - The selected day

    @ViewBuilder
    private var daySection: some View {
        if let game = gameOnSelectedDay {
            gameDayCard(game)
        } else if let session = displayedSession {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(isSelectedToday ? "Today's session" : selectedDate.formatted(.dateTime.weekday(.wide)))
                    Text("\(session.items.count) exercises")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                if let reason = readinessAdjustment?.reason {
                    readinessBanner(reason: reason)
                } else if isSelectedToday, readinessOverridden {
                    Button("Use the readiness-adjusted session") { readinessOverridden = false }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
                ForEach(session.items, id: \.order) { item in
                    plannedItemRow(item)
                }
                if isSelectedToday {
                    if loggedOnSelectedDay.isEmpty {
                        Button("Start session") { liveLaunch = LiveSessionLaunch(planned: session) }
                            .buttonStyle(.primary)
                            .padding(.top, 4)
                    } else {
                        completedRow
                    }
                }
            }
        } else {
            restDayCard
        }
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

    private func readinessBanner(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.color(for: todaysCheckIn?.readinessBand))
                    .frame(width: 10, height: 10)
                Text("Adjusted for your readiness")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
            }
            Text(reason)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            Button("Use the original session instead") { readinessOverridden = true }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private var completedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Done for today")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text("Nice work. Logged \(loggedOnSelectedDay.count) session\(loggedOnSelectedDay.count == 1 ? "" : "s").")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Button("Log more") { liveLaunch = LiveSessionLaunch(planned: nil) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .cardStyle(padding: 16)
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

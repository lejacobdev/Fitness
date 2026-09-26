import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Home: a simple overview of everything, explaining itself as it goes.
/// Top to bottom: what kind of day it is (top left) and the streak, today's
/// quote, the morning check-in, today's workout — built around practice,
/// games and the day's status — the daily mobility, and the athlete's four
/// levels (body, sport, knowledge, mindset).
struct HomeView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let week: GeneratedWeek?
    @Binding var selectedTab: AppTab
    let onPlanInputsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var allSessions: [Session]
    @AppStorage("home.introSeen") private var introSeen = false
    @AppStorage(CampusProgress.learnedKey) private var campusLearnedRaw = ""
    @State private var catalogue = Catalogue()
    @State private var status: DayStatus = DayStatusStore.status()
    @State private var practiceDays: Set<Int> = PracticeSchedule.weekdays
    @State private var scheduleIsSet = PracticeSchedule.isSet
    @State private var readinessOverridden = false
    @State private var liveLaunch: LiveSessionLaunch?
    @State private var activeSheet: HomeSheet?
    @State private var pendingAction: QuickAction?
    @State private var detailItem: CatalogueItem?
    @State private var preview: PreviewBox?
    @State private var loaded = false
    @State private var checkInAppeared = false
    @State private var routine: MindsetRoutine?
    @State private var lowEnergySnoozed = LowEnergyCheck.isSnoozed
    @State private var layout = HomeLayout.load()
    @State private var editingLayout = false
    @State private var wiggle = false
    /// The widget being held while arranging, and where the board is in reordering it.
    @State private var drag = HomeDragState()
    /// Bumped when a Mindset sheet closes, so the level redraws.
    @State private var mindsetRevision = 0

    enum HomeSheet: String, Identifiable {
        case quickActions, checkIn, addGame, history, fuel, dayStatus, schedule, mindset, reflection, tests, concussion
        var id: String { rawValue }
    }

    private var calendar: Calendar { .current }
    private var todaysCheckIn: CheckIn? { AthleteStats.todaysCheckIn(athlete) }
    private var sportInfo: SportInfo? { athlete.activeSport.flatMap { allSportsBySlug[$0.sportSlug] } }
    private var gameToday: Competition? { athlete.competitions.first { calendar.isDateInToday($0.date) } }
    /// The team calendar decides when there is one (practice days otherwise).
    /// `practiceDays` is read so a change there redraws this.
    private var practiceToday: Bool { _ = practiceDays; return PracticeSchedule.hasPractice(on: .now) }
    private var practicesToday: [ScheduleEvent] { ScheduleStore.imported.practices(on: .now) }
    private var examWeek: Bool { _ = practiceDays; return ScheduleStore.isExamWeek(.now) }
    private var loggedToday: Bool { allSessions.contains { calendar.isDateInToday($0.startedAt) } }

    private var modeContext: WorkoutModeContext {
        WorkoutModeContext(
            catalogue: catalogue, sport: sportInfo, positionSlug: athlete.activeSport?.positionSlug,
            formatSlug: athlete.activeSport?.formatSlug, equipment: Set(athlete.equipmentAvailable),
            trainsUnderCoach: athlete.trainsUnderCoach, age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now),
            struggles: Struggles.selected
        )
    }

    /// Today's workout and why: the heart of Home.
    private var todaysWorkout: (mode: WorkoutMode, session: GeneratedSession)? {
        switch status {
        case .sick, .concussion: return nil
        case .travel, .holiday:
            return WorkoutModeBuilder.build(.travel, modeContext).map { (mode: WorkoutMode.travel, session: $0) }
        case .active:
            if gameToday != nil { return nil }
            if practiceToday {
                return WorkoutModeBuilder.build(.afterPractice, modeContext).map { (mode: WorkoutMode.afterPractice, session: adjusted($0)) }
            }
            if let planned = week?.sessions.first(where: { calendar.isDateInToday($0.date) }) {
                return (mode: WorkoutMode.gymDay, session: adjusted(planned))
            }
            return nil
        }
    }

    private var readinessResult: ReadinessApplier.Result? {
        guard !readinessOverridden, let band = todaysCheckIn?.readinessBand,
              let planned = week?.sessions.first(where: { calendar.isDateInToday($0.date) }) else { return nil }
        return ReadinessApplier.apply(to: planned, band: band)
    }

    /// The check-in lightens the workout on a low-readiness day (the athlete can undo it).
    private func adjusted(_ session: GeneratedSession) -> GeneratedSession {
        guard !readinessOverridden, let band = todaysCheckIn?.readinessBand else { return session }
        return ReadinessApplier.apply(to: session, band: band).session
    }

    private var mobility: GeneratedSession? {
        status == .sick || status == .concussion ? nil : WorkoutModeBuilder.build(.mobility, modeContext)
    }

    private var streak: Int {
        AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: allSessions.map(\.startedAt))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        topBar
                        if !introSeen { introCard }
                        if let lowEnergy, !lowEnergySnoozed {
                            LowEnergyCard(warning: lowEnergy) {
                                LowEnergyCheck.snoozeForAWeek()
                                lowEnergySnoozed = true
                            }
                        }
                        widgetBoard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: allSessions.count + athlete.checkIns.count) {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                status = DayStatusStore.status()
                loaded = true
            }
            .sheet(item: $activeSheet, onDismiss: { mindsetRevision += 1; runPendingAction() }) { sheet in
                switch sheet {
                case .quickActions:
                    QuickActionsSheet { action in
                        pendingAction = action
                        activeSheet = nil
                    }
                    .presentationDetents([.height(560)])
                case .checkIn:
                    CheckInSheet(athlete: athlete).presentationDetents([.large])
                case .addGame:
                    AddGameSheet(athlete: athlete, onSaved: onPlanInputsChanged)
                case .history:
                    SessionHistoryView()
                case .fuel:
                    FuelView(athlete: athlete, todaysSession: todaysWorkout?.session)
                case .dayStatus:
                    DayStatusSheet(current: status) { newStatus, days in
                        DayStatusStore.set(newStatus, days: days)
                        status = DayStatusStore.status()
                        activeSheet = nil
                        onPlanInputsChanged()
                    }
                case .concussion:
                    ConcussionGuideView()
                case .tests:
                    BenchmarksView(sportSlug: athlete.activeSport?.sportSlug)
                case .mindset:
                    MindsetView(sportName: AthleteStats.sportName(athlete)) { selectedTab = .campus }
                case .reflection:
                    ReflectionSheet {
                        mindsetRevision += 1
                        activeSheet = nil
                    }
                case .schedule:
                    ScheduleSheet(athlete: athlete) {
                        practiceDays = PracticeSchedule.weekdays
                        scheduleIsSet = PracticeSchedule.isSet
                        onPlanInputsChanged()
                    }
                }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
            .sheet(item: $preview) { box in
                SessionPreviewSheet(session: box.session, catalogue: catalogue) {
                    preview = nil
                    liveLaunch = LiveSessionLaunch(planned: box.session, kind: box.kind)
                }
            }
            .fullScreenCover(item: $routine, onDismiss: { mindsetRevision += 1 }) { routine in
                switch routine {
                case .breathing: BreathingView()
                case .visualization: VisualizationView(sportName: AthleteStats.sportName(athlete))
                }
            }
            .fullScreenCover(item: $liveLaunch) { launch in
                LiveSessionView(athlete: athlete, apiClient: apiClient, planned: launch.planned, kind: launch.kind)
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
        case .improve: selectedTab = .workout
        case .history: activeSheet = .history
        case .fuel: activeSheet = .fuel
        }
    }

    // MARK: - Top bar

    private var greeting: String {
        let hour = calendar.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { activeSheet = .dayStatus } label: {
                    HStack(spacing: 8) {
                        Image(systemName: status.systemImage)
                            .font(.headline)
                        Text(status.title)
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(status == .active ? AppTheme.ink : AppTheme.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(status == .active ? AppTheme.card : AppTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Today is: \(status.title). Change what kind of day it is.")
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(AppTheme.orange)
                    Text("\(streak)").font(.headline).foregroundStyle(AppTheme.ink).contentTransition(.numericText())
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(AppTheme.card, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(streak) day streak: days in a row you checked in or trained")
                // Add: log a workout, check in, add a game, food — in the top
                // bar so it never covers a widget.
                Button { activeSheet = .quickActions } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add: log a workout, check in, add a game, food or past workouts")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Text("Home")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(AppTheme.ink)
            }
        }
    }

    // MARK: - First-time explainer

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How Athlete OS works")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            introStep(1, "Check in every morning", "Four taps about sleep and energy. Your workout adapts to it.")
            introStep(2, "Do today's workout", "Built around your practice and games — short after practice, full on gym days.")
            introStep(3, "Learn in Campus", "A few minutes a day on training, food, sleep and mindset.")
            introStep(4, "Sick, travelling or on holiday?", "Tap the button top left and the app backs off.")
            Button("Got it") { withAnimation { introSeen = true } }
                .buttonStyle(.primary)
        }
        .cardStyle(padding: 20)
    }

    private func introStep(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(AppTheme.ink)
                Text(detail).font(.subheadline).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Morning check-in

    @ViewBuilder
    private var checkInCard: some View {
        if let checkIn = todaysCheckIn {
            Button { activeSheet = .checkIn } label: {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Checked in")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(readinessLine(checkIn))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Text("Edit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .cardStyle(padding: 16)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(AppTheme.orange, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning check-in")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.ink)
                        Text("How did you sleep? How do you feel? 10 seconds — today's workout adapts to your answers.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button { activeSheet = .checkIn } label: { Label("Check in now", systemImage: "hand.tap.fill") }
                    .buttonStyle(.primary)
            }
            .cardStyle(padding: 20)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).strokeBorder(AppTheme.orange, lineWidth: 2))
            .scaleEffect(checkInAppeared ? 1 : 0.92)
            .opacity(checkInAppeared ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) { checkInAppeared = true } }
        }
    }

    private func readinessLine(_ checkIn: CheckIn) -> String {
        switch checkIn.readinessBand {
        case .green: "You're ready to push today."
        case .amber: "Go steady today — the workout is a bit lighter."
        case .red: "Take it easy — today's workout is mostly mobility."
        case nil: "After a week of check-ins, we'll tell you how hard to train."
        }
    }

    // MARK: - Practice days

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("When do you have practice?", systemImage: "calendar.badge.clock")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Connect your team's calendar (TeamSnap, Google or Apple) or just pick your practice days. On practice days you get a short workout for after practice; on the other days, a full gym session.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button { activeSheet = .schedule } label: { Label("Set up my schedule", systemImage: "calendar") }
                .buttonStyle(.primary)
        }
        .cardStyle(padding: 20)
    }

    // MARK: - Today

    @ViewBuilder
    private var todayCard: some View {
        if !loaded {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
                .cardStyle(padding: 20)
        } else if status == .concussion {
            infoCard(icon: "bandage.fill", color: AppTheme.accent, title: "Head knock: no training",
                     text: "Every workout is paused. Follow your doctor's or athletic trainer's return-to-play steps — at least a day each — and switch back to Active once a doctor has cleared you.",
                     action: ("See the return-to-play steps", { activeSheet = .concussion }))
        } else if status == .sick {
            infoCard(icon: "bed.double.fill", color: AppTheme.purple, title: "Rest and recover",
                     text: "No training while you're sick. Drink plenty, eat normally and sleep. When you feel better, ease back in with a lighter day. See a doctor if it's getting worse.")
        } else if let game = gameToday, status == .active {
            infoCard(icon: "sportscourt.fill", color: AppTheme.brand,
                     title: game.kind == .tournament ? "Tournament day" : (game.kind == .meet ? "Meet day" : "Game day"),
                     text: gameDayText(game))
        } else if let workout = todaysWorkout {
            workoutCard(workout.mode, workout.session)
        } else {
            infoCard(icon: "moon.zzz.fill", color: AppTheme.purple, title: "Rest day",
                     text: "No workout today. Rest is when your body gets stronger from training — sleep well tonight.",
                     action: ("Log a workout anyway", { liveLaunch = LiveSessionLaunch(planned: nil) }))
        }
    }

    private func gameDayText(_ game: Competition) -> String {
        let hasTime = calendar.component(.hour, from: game.date) != 0 || calendar.component(.minute, from: game.date) != 0
        let start = hasTime ? "Starts at \(game.date.formatted(date: .omitted, time: .shortened)). " : ""
        let away = game.isHome ? "" : " It's an away game: pack water, snacks and all your kit, and eat before the trip."
        return start + "No workout today — save your energy. Eat a proper meal about 3 hours before, a snack an hour before, warm up well, and play." + away
    }

    /// Today's practice from the team calendar, or why today is a gym day.
    private var practiceLine: (text: String, icon: String)? {
        let held = practicesToday.filter { !$0.cancelled }
        if let practice = held.first {
            let time = practice.allDay ? "" : " " + practice.start.formatted(date: .omitted, time: .shortened)
                + (practice.end.map { " – " + $0.formatted(date: .omitted, time: .shortened) } ?? "")
            return ("Practice today\(time)\(practice.location.map { " · \($0)" } ?? "")", "sportscourt.fill")
        }
        if practicesToday.contains(where: \.cancelled) {
            return ("Practice is cancelled today — so today is a gym day.", "xmark.circle.fill")
        }
        return nil
    }

    /// Home keeps it short: what's on today, how long, Start. The full
    /// choice of workouts is one tap away on the Workout tab.
    private func workoutCard(_ mode: WorkoutMode, _ session: GeneratedSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(status == .active ? "TODAY" : "OPTIONAL TODAY")
                    .font(.caption.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.brand)
                Spacer()
                if loggedToday { Tag("Done", color: AppTheme.green) }
            }
            Text(mode.title)
                .font(.title.bold())
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 16) {
                Label("About \(session.estimatedMinutes) min", systemImage: "clock")
                Label("\(session.items.count) exercises", systemImage: "list.bullet")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            if let practiceLine, mode == .afterPractice || mode == .gymDay {
                Label(practiceLine.text, systemImage: practiceLine.icon)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else if readinessResult != nil {
                Label("Lighter today because of your check-in", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else if examWeek, mode == .gymDay || mode == .afterPractice {
                Label("Exam week: a shorter workout", systemImage: "book.closed.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ButtonRow {
                Button { selectedTab = .workout } label: { Label("All workouts", systemImage: "square.grid.2x2") }
                    .buttonStyle(.secondary)
                Button { liveLaunch = LiveSessionLaunch(planned: session, kind: workoutKind(mode)) } label: {
                    Label(loggedToday ? "Again" : "Start", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    private func workoutKind(_ mode: WorkoutMode) -> WorkoutKind {
        switch mode {
        case .afterPractice: .afterPractice
        case .gymDay: .gym
        case .mobility: .mobility
        case .travel: .travel
        }
    }

    private var practiceDayNames: String {
        guard !practiceDays.isEmpty else { return "none" }
        let symbols = calendar.shortWeekdaySymbols
        return practiceDays.sorted().map { symbols[($0 - 1) % 7] }.joined(separator: ", ")
    }

    private func mobilityCard(_ session: GeneratedSession) -> some View {
        Button { preview = PreviewBox(session: session, kind: .mobility) } label: {
            HStack(spacing: 14) {
                Image(systemName: "figure.flexibility")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily mobility · \(session.estimatedMinutes) min")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("Every day, best in the evening: loosen up and calm down.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 16)
        }
        .buttonStyle(.plain)
    }

    private func thumbnails(_ session: GeneratedSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(session.items, id: \.order) { item in
                    let catalogueItem = catalogue.item(item.itemSlug)
                    Button { detailItem = catalogueItem } label: { ItemThumbnail(item: catalogueItem, size: 60) }
                        .buttonStyle(.plain)
                        .disabled(catalogueItem == nil)
                        .accessibilityLabel(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                }
                Button { preview = PreviewBox(session: session) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "list.bullet").font(.subheadline.weight(.semibold))
                        Text("See all").font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func infoCard(icon: String, color: Color, title: String, text: String, action: (String, () -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(color)
                .frame(width: 66, height: 66)
                .background(color.opacity(0.12), in: Circle())
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.0, action: action.1)
                    .buttonStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }

    // MARK: - Levels

    private var loggedThisWeek: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return allSessions.filter { interval.contains($0.startedAt) }.count
    }

    /// Four ways the athlete gets better: body, sport, knowledge and mindset.
    // MARK: - The widget board

    /// Only widgets that matter right now (in edit mode: all of them).
    private func isRelevant(_ widget: HomeWidget) -> Bool {
        switch widget {
        case .coach: status != .sick && status != .concussion && !CoachAssignments.today().isEmpty
        case .gameDay: gameToday != nil && status == .active
        case .reflection: showEveningReflection
        case .mobility: mobility != nil
        case .schedule: !scheduleIsSet
        default: true
        }
    }

    private var widgetBoard: some View {
        let shown = layout.visible.filter { editingLayout || isRelevant($0) }
        return VStack(spacing: 14) {
            // One container for every widget, so while arranging they glide
            // to their new places instead of jumping between rows.
            WidgetBoardLayout {
                ForEach(shown) { widget in
                    editableWidget(widget)
                        .layoutValue(key: WidgetBoardLayout.IsSmall.self, value: widget.size == .small)
                }
            }
            layoutControls
        }
        #if os(iOS)
        // Letting go anywhere on the board keeps the order it shows.
        .contentShape(Rectangle())
        .onDrop(of: [.text], delegate: HomeWidgetDropDelegate(target: nil, drag: $drag, layout: $layout))
        #endif
    }

    /// While arranging: hold a widget and drag it — the others make room as
    /// it passes over them, so the new order shows before letting go. Tap –
    /// to remove it.
    @ViewBuilder
    private func editableWidget(_ widget: HomeWidget) -> some View {
        if editingLayout {
            let held = drag.widget == widget
            Group {
                if isRelevant(widget) {
                    widgetContent(widget).allowsHitTesting(false)
                } else {
                    placeholder(widget)
                }
            }
            .frame(maxWidth: .infinity)
            // Where the held widget will land: its place stays, faded and outlined.
            .opacity(held ? 0.3 : 1)
            .overlay {
                if held {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.ink.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                }
            }
            // The widget itself ignores taps while arranging; this layer
            // catches the long-press for dragging.
            .overlay { Color.clear.contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)) }
            .rotationEffect(.degrees(wiggle ? 0.6 : -0.6))
            .animation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true), value: wiggle)
            #if os(iOS)
            .onDrag {
                // Marked as held on the next turn, after the lifted copy
                // under the finger has been captured at full strength.
                Task { @MainActor in drag = HomeDragState(widget: widget) }
                return NSItemProvider(object: widget.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: HomeWidgetDropDelegate(target: widget, drag: $drag, layout: $layout))
            #endif
            .overlay(alignment: .topLeading) {
                Button {
                    withAnimation { layout.hidden.insert(widget); layout.save() }
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.red, in: Circle())
                        .overlay(Circle().stroke(AppTheme.background, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .offset(x: -10, y: -10)
                .accessibilityLabel("Remove \(widget.title)")
            }
            .padding(.top, 8)
        } else {
            widgetContent(widget)
                .frame(maxWidth: .infinity)
        }
    }

    /// A widget that isn't showing right now, while arranging.
    private func placeholder(_ widget: HomeWidget) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(widget.title, systemImage: widget.systemImage)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(widget.whenShown ?? "")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            .strokeBorder(AppTheme.hairline, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
    }

    @ViewBuilder
    private var layoutControls: some View {
        if editingLayout {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hold a widget and drag it — the others make room as you move, so you see the new order before you let go. Tap – to remove it.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                let hidden = layout.order.filter { layout.hidden.contains($0) }
                if !hidden.isEmpty {
                    SectionHeader("Add widgets")
                    ForEach(hidden) { widget in
                        Button {
                            withAnimation { layout.hidden.remove(widget); layout.save() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: widget.systemImage)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .frame(width: 44, height: 44)
                                    .background(AppTheme.fill, in: Circle())
                                Text(widget.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.green)
                            }
                            .cardStyle(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Back to the standard layout") {
                    withAnimation { layout = .standard; layout.save() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                Button {
                    editingLayout = false
                    wiggle = false
                    drag = HomeDragState()
                    layout.save()
                } label: { Label("Done", systemImage: "checkmark") }
                    .buttonStyle(.primary)
            }
            .padding(.top, 8)
        } else {
            Button {
                editingLayout = true
                wiggle = true
            } label: {
                Label("Edit Home", systemImage: "square.grid.2x2")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func widgetContent(_ widget: HomeWidget) -> some View {
        switch widget {
        case .quote:
            QuoteCard(quote: DailyQuotes.quote())
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 20)
        case .checkIn: checkInCard
        case .today: todayCard
        case .coach:
            VStack(spacing: 14) {
                ForEach(CoachAssignments.today()) { assignment in coachCard(assignment) }
            }
        case .gameDay: gameRoutinesCard
        case .reflection: eveningCard
        case .mobility:
            if let mobility { mobilityCard(mobility) }
        case .schedule: scheduleCard
        case .body, .sport, .knowledge, .mindset, .nextGame, .food, .streak, .tests:
            smallWidget(widget)
        }
    }

    /// The square widgets: one number, what it means, one tap to act on it.
    @ViewBuilder
    private func smallWidget(_ widget: HomeWidget) -> some View {
        switch widget {
        case .body:
            let planned = max(week?.sessions.count ?? 0, 1) + practiceDays.count
            let gain = BenchmarkMath.headline(BenchmarkStore.results, tests: BenchmarkCatalog.body)
            Button { selectedTab = .progress } label: {
                WidgetTile(value: "\(loggedThisWeek) of \(planned)", label: "Body", progress: Double(loggedThisWeek) / Double(planned),
                           color: AppTheme.accent, systemImage: "figure.strengthtraining.traditional", caption: gain ?? "Workouts done this week")
            }
            .buttonStyle(.plain)
        case .sport:
            let skillPlans = athlete.skillBlocks.filter { $0.targetDate >= calendar.startOfDay(for: .now) }.count
            let gain = athlete.activeSport.flatMap { BenchmarkMath.headline(BenchmarkStore.results, tests: [BenchmarkCatalog.sportTest(for: $0.sportSlug)]) }
            Button { selectedTab = .workout } label: {
                WidgetTile(value: skillPlans == 0 ? "Pick a skill" : "\(skillPlans) active", label: "Sport",
                           progress: skillPlans == 0 ? 0 : 1, color: AppTheme.brand, systemImage: "sportscourt.fill",
                           caption: gain ?? (skillPlans == 0 ? "A plan for one skill of your sport" : "Skill plans in progress"))
            }
            .buttonStyle(.plain)
        case .knowledge:
            let learned = CampusProgress.learned(campusLearnedRaw)
            let total = campusTopics.reduce(0) { $0 + $1.lessons.count }
            Button { selectedTab = .campus } label: {
                WidgetTile(value: "\(learned.count) of \(total)", label: "Knowledge", progress: Double(learned.count) / Double(max(1, total)),
                           color: AppTheme.green, systemImage: "graduationcap.fill", caption: "Campus lessons learned")
            }
            .buttonStyle(.plain)
        case .mindset:
            let progress = mindsetProgress
            Button { activeSheet = .mindset } label: {
                WidgetTile(value: "\(progress.done) of \(progress.target)", label: "Mindset", progress: Double(progress.done) / Double(max(1, progress.target)),
                           color: AppTheme.purple, systemImage: "brain.head.profile", caption: "Reflections, goals, game-day routines")
            }
            .buttonStyle(.plain)
        case .nextGame:
            let nextGame = AthleteStats.upcomingCompetitions(athlete).first
            let days = nextGame.map { AthleteStats.daysUntil($0.date) }
            Button { if nextGame == nil { activeSheet = .addGame } else { selectedTab = .progress } } label: {
                WidgetTile(value: days.map { $0 == 0 ? "Today" : ($0 == 1 ? "Tomorrow" : "In \($0) days") } ?? "None yet",
                           label: "Next game", progress: days.map { max(0.05, 1 - Double($0) / 14) } ?? 0,
                           color: AppTheme.brand, systemImage: "sportscourt.fill",
                           caption: nextGame.map { nextGameCaption($0) } ?? "Tap to add one — training eases off before it")
            }
            .buttonStyle(.plain)
        case .food:
            Button { activeSheet = .fuel } label: {
                WidgetTile(value: gameToday != nil ? "Game day" : (todaysWorkout != nil ? "Training day" : "Rest day"),
                           label: "Food & water", progress: 0.5, color: AppTheme.green, systemImage: "fork.knife",
                           caption: "What to eat and drink today")
            }
            .buttonStyle(.plain)
        case .streak:
            Button { selectedTab = .progress } label: {
                WidgetTile(value: "\(streak) \(streak == 1 ? "day" : "days")", label: "Streak", progress: min(1, Double(streak) / 7),
                           color: AppTheme.orange, systemImage: "flame.fill", caption: "Days in a row you checked in or trained")
            }
            .buttonStyle(.plain)
        default:
            let value: String = {
                switch testStatus {
                case .firstTime: return "First tests"
                case .notYet(let days): return "In \(days) days"
                case .due: return "Test week"
                case .overdue: return "Overdue"
                }
            }()
            let headline = BenchmarkMath.headline(BenchmarkStore.results, tests: BenchmarkCatalog.tests(for: athlete.activeSport?.sportSlug))
            Button { activeSheet = .tests } label: {
                WidgetTile(value: value, label: "Tests", progress: showTestsCard ? 1 : 0.3, color: AppTheme.coral,
                           systemImage: "stopwatch.fill", caption: headline ?? "Jump, sprint, strength — every 6–8 weeks")
            }
            .buttonStyle(.plain)
        }
    }

    private var mindsetProgress: (done: Int, target: Int) {
        _ = mindsetRevision
        return MindsetStore.weekProgress()
    }


    /// Constant fatigue while training hard (see Safety.swift).
    private var lowEnergy: LowEnergyWarning? {
        status == .active ? LowEnergyCheck.current(for: athlete) : nil
    }

    // MARK: - From the coach

    private func coachCard(_ assignment: APIClient.Assignment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FROM YOUR COACH\(assignment.teamName.map { " · \($0.uppercased())" } ?? "")")
                .font(.caption.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(AppTheme.accent)
            Text(assignment.title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            if let note = assignment.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label("\(assignment.items.count) exercises", systemImage: "list.bullet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Button { liveLaunch = LiveSessionLaunch(planned: CoachAssignments.session(assignment, catalogue: catalogue), kind: .coach) } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    // MARK: - Tests

    private var testStatus: BenchmarkSchedule.Status {
        _ = mindsetRevision
        return BenchmarkSchedule.status(lastTest: BenchmarkStore.lastTestDate())
    }

    /// Every 6–8 weeks (and the very first time): time to test.
    private var showTestsCard: Bool {
        switch testStatus {
        case .notYet: false
        case .firstTime, .due, .overdue: status == .active
        }
    }

    private var testsCard: some View {
        let (title, text): (String, String) = {
            switch testStatus {
            case .firstTime: return ("Take your first tests", "Jump, sprint, plank, push-ups and one test for your sport — about 20 minutes. They're your starting point.")
            case .overdue: return ("Tests are overdue", "It's been over 8 weeks. Test on a fresh day this week and see what changed.")
            default: return ("Test week", "It's been 6 weeks. Do the same tests again and see how much you've improved.")
            }
        }()
        return Button { activeSheet = .tests } label: {
            HStack(spacing: 14) {
                Image(systemName: "stopwatch.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mindset

    /// After 6 pm, until tonight's reflection is written.
    private var showEveningReflection: Bool {
        _ = mindsetRevision
        return calendar.component(.hour, from: .now) >= 18 && status != .sick && MindsetStore.reflection(on: .now) == nil
    }

    private var eveningCard: some View {
        Button { activeSheet = .reflection } label: {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.purple)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.purple.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Evening reflection")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text("2 minutes: one win from today, one lesson for tomorrow.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 16)
        }
        .buttonStyle(.plain)
    }

    /// Game day: get the head ready too.
    private var gameRoutinesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get your head ready")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Nerves are normal — they mean you care. Before you leave or in the locker room:")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ButtonRow {
                Button { routine = .breathing } label: {
                    Label("Breathing · 2 min", systemImage: "wind")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                Button { routine = .visualization } label: {
                    Label("Visualize · 5 min", systemImage: "eye.fill")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(AppTheme.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle(padding: 20)
    }

    // MARK: - Coming up

    private func nextGameCaption(_ game: Competition) -> String {
        let hasTime = calendar.component(.hour, from: game.date) != 0 || calendar.component(.minute, from: game.date) != 0
        let when = hasTime ? game.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()) : game.date.formatted(.dateTime.weekday(.abbreviated).month().day())
        return "\(game.isHome ? "Home" : "Away") · \(when)"
    }
}

/// `GeneratedSession` isn't Identifiable; this wraps one for `.sheet(item:)`.
struct PreviewBox: Identifiable {
    let id = UUID()
    let session: GeneratedSession
    var kind: WorkoutKind? = nil
}

/// Today's quote, big and simple.
struct QuoteCard: View {
    let quote: DailyQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(quote.text)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(quote.author), \(quote.who)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// "What kind of day is it?" — each option says what the app does about it.
struct DayStatusSheet: View {
    let current: DayStatus
    let onSave: (DayStatus, Int?) -> Void
    @State private var choice: DayStatus = .active
    @State private var days: Int? = 1
    @Environment(\.dismiss) private var dismiss

    private let lengths: [(String, Int?)] = [("Just today", 1), ("3 days", 3), ("A week", 7), ("Two weeks", 14), ("Until I change it", nil)]

    var body: some View {
        StepScaffold(title: "What kind of day is it?", subtitle: "Your plan and reminders follow this, so the app never nags you when you're ill, travelling or on holiday.",
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: { onSave(choice, choice == .active || choice == .concussion ? nil : days) }) {
            VStack(spacing: 10) {
                ForEach(DayStatus.allCases) { status in
                    Button { choice = status } label: {
                        OptionRow(title: status.title, subtitle: status.explanation, systemImage: status.systemImage, isSelected: choice == status)
                    }
                    .buttonStyle(.plain)
                }
            }
            if choice == .concussion {
                Text("This stays on until you switch back to Active — only after a doctor has cleared you to play.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            } else if choice != .active {
                VStack(alignment: .leading, spacing: 10) {
                    Text("For how long?")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(lengths.indices, id: \.self) { index in
                            Button { days = lengths[index].1 } label: { Chip(lengths[index].0, isSelected: days == lengths[index].1) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear { choice = current }
    }
}

/// The athlete's team-practice days.
struct PracticeDaysSheet: View {
    @State var selection: Set<Int>
    let onSave: (Set<Int>) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StepScaffold(title: "Your practice days", subtitle: "Tap every day you have team practice. Practice days get a short after-practice workout; gym days go on the others.",
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: { onSave(selection) }) {
            let calendar = Calendar.current
            // Monday first.
            let order = [2, 3, 4, 5, 6, 7, 1]
            VStack(spacing: 10) {
                ForEach(order, id: \.self) { weekday in
                    Button {
                        if selection.contains(weekday) { selection.remove(weekday) } else { selection.insert(weekday) }
                    } label: {
                        OptionRow(title: calendar.weekdaySymbols[weekday - 1], subtitle: selection.contains(weekday) ? "Practice" : "No practice",
                                  systemImage: selection.contains(weekday) ? "sportscourt.fill" : "circle", isSelected: selection.contains(weekday))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// A workout's exercises in order, with the Start button.
struct SessionPreviewSheet: View {
    let session: GeneratedSession
    let catalogue: Catalogue
    let onStart: () -> Void
    @State private var detailItem: CatalogueItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Do them in this order. Tap one to watch how it's done.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    ForEach(Array(session.items.enumerated()), id: \.element.order) { index, item in
                        row(item, number: index + 1)
                    }
                    Button { onStart() } label: { Label("Start", systemImage: "play.fill") }
                        .buttonStyle(.primary)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .appScreen()
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
        }
    }

    private func row(_ item: GeneratedPlannedItem, number: Int) -> some View {
        let catalogueItem = catalogue.item(item.itemSlug)
        return Button { detailItem = catalogueItem } label: {
            HStack(spacing: 14) {
                ItemThumbnail(item: catalogueItem)
                    .overlay(alignment: .topLeading) {
                        Text("\(number)")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.onAccent)
                            .frame(width: 22, height: 22)
                            .background(AppTheme.accent, in: Circle())
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
                    if !item.rationale.isEmpty {
                        Text(item.rationale)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
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
}

// MARK: - Arranging the board

/// The Home board: small widgets two to a row, everything else full width,
/// in the athlete's order (HomeLayout.rowIndices).
struct WidgetBoardLayout: Layout {
    var columnSpacing: CGFloat = 12
    var rowSpacing: CGFloat = 14

    struct IsSmall: LayoutValueKey {
        static let defaultValue = false
    }

    private func rows(_ subviews: Subviews) -> [[Int]] {
        HomeLayout.rowIndices(small: subviews.map { $0[IsSmall.self] })
    }

    private func width(_ index: Int, _ subviews: Subviews, total: CGFloat) -> CGFloat {
        subviews[index][IsSmall.self] ? (total - columnSpacing) / 2 : total
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 360
        var height: CGFloat = 0
        for (n, row) in rows(subviews).enumerated() {
            var rowHeight: CGFloat = 0
            for index in row {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: width(index, subviews, total: total), height: nil))
                rowHeight = max(rowHeight, size.height)
            }
            height += rowHeight + (n > 0 ? rowSpacing : 0)
        }
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews) {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for index in row {
                let w = width(index, subviews, total: bounds.width)
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: w, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: w, height: size.height))
                x += w + columnSpacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + rowSpacing
        }
    }
}

/// The widget held while arranging Home.
struct HomeDragState: Equatable {
    var widget: HomeWidget?
    /// The widget the held one just moved over, until the board has made room.
    var pending: HomeWidget?
    var lastMove = Date.distantPast
}

#if os(iOS)
/// Live rearranging: as the held widget passes over another, the board makes
/// room straight away (animated), so the new order is visible while still
/// holding. A short pause between moves keeps big and small widgets from
/// trading places back and forth under the finger. `target` nil is the board
/// itself, which only ends the drag.
struct HomeWidgetDropDelegate: DropDelegate {
    let target: HomeWidget?
    @Binding var drag: HomeDragState
    @Binding var layout: HomeLayout

    func dropEntered(info: DropInfo) {
        guard let target else { return }
        drag.pending = target
        makeRoom()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        makeRoom()
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if let target, drag.pending == target { drag.pending = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        drag = HomeDragState()
        layout.save()
        return true
    }

    private func makeRoom() {
        guard let target, drag.pending == target, let held = drag.widget, held != target,
              Date.now.timeIntervalSince(drag.lastMove) > 0.2 else { return }
        drag.pending = nil
        drag.lastMove = .now
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            layout.move(held, to: target)
        }
    }
}
#endif

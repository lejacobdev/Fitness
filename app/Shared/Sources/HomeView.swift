import SwiftData
import SwiftUI

/// Home — the command center (V3). One calm screen that answers "what do I
/// do today?": the kind of day and the streak, a greeting and a short quote,
/// the morning check-in (then today's readiness), the TODAY list, why the
/// plan looks like this, and in the evening the reflection.
/// PREPARE → PERFORM → LEARN → REFLECT → ADAPT.
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
    @State private var preview: PreviewBox?
    @State private var loaded = false
    @State private var routine: MindsetRoutine?
    @State private var lowEnergySnoozed = LowEnergyCheck.isSnoozed
    /// Bumped when a sheet closes, so what it changed (reflection, pain, day status) redraws.
    @State private var revision = 0

    enum HomeSheet: String, Identifiable {
        case quickActions, checkIn, addGame, history, fuel, dayStatus, schedule, reflection, safety
        var id: String { rawValue }
    }

    private var calendar: Calendar { .current }
    private var todaysCheckIn: CheckIn? { AthleteStats.todaysCheckIn(athlete) }
    private var sportInfo: SportInfo? { athlete.activeSport.flatMap { allSportsBySlug[$0.sportSlug] } }
    private var gameToday: Competition? { athlete.competitions.first { calendar.isDateInToday($0.date) } }
    /// The team calendar decides when there is one (practice days otherwise).
    /// `practiceDays` and `revision` are read so a change there redraws this.
    private var practiceToday: Bool { _ = practiceDays; _ = revision; return PracticeSchedule.hasPractice(on: .now) }
    private var practicesToday: [ScheduleEvent] { ScheduleStore.imported.practices(on: .now) }
    private var examWeek: Bool { _ = practiceDays; return ScheduleStore.isExamWeek(.now) }
    private var loggedToday: Bool { allSessions.contains { calendar.isDateInToday($0.startedAt) } }
    private var isTrainingDay: Bool { status != .sick && status != .concussion }

    private var modeContext: WorkoutModeContext {
        WorkoutModeContext(
            catalogue: catalogue, sport: sportInfo, positionSlug: athlete.activeSport?.positionSlug,
            formatSlug: athlete.activeSport?.formatSlug, equipment: Set(athlete.equipmentAvailable),
            trainsUnderCoach: athlete.trainsUnderCoach, age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now),
            struggles: Struggles.selected
        )
    }

    // MARK: - Today's plan

    /// Today's readiness in words (the check-in, reported pain, last night).
    private var readiness: (level: TodayReadiness, reason: String)? {
        _ = revision
        return DailyLoop.today(athlete)
    }

    private var readinessBand: ReadinessBand? {
        guard !readinessOverridden, let level = readiness?.level, level > .normal else { return nil }
        return level.band
    }

    /// Today's workout: built around practice, games and the day's status.
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

    /// A low-readiness day lightens the workout (the athlete can undo it).
    private func adjusted(_ session: GeneratedSession) -> GeneratedSession {
        guard let readinessBand else { return session }
        return ReadinessApplier.apply(to: session, band: readinessBand).session
    }

    private var movementPrep: GeneratedSession? {
        isTrainingDay ? WorkoutModeBuilder.build(.mobility, modeContext) : nil
    }

    private var streak: Int {
        AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: allSessions.map(\.startedAt))
    }

    private var daysToNextGame: Int? {
        AthleteStats.upcomingCompetitions(athlete).first.map { AthleteStats.daysUntil($0.date) }
    }

    private var whyThisPlan: String {
        DailyLoop.whyThisPlan(status: status, mode: todaysWorkout?.mode, practiceToday: practiceToday, gameToday: gameToday != nil,
                              daysToNextGame: daysToNextGame, readiness: readinessOverridden ? nil : readiness)
    }

    // MARK: - Learning and reflecting

    private var nextLesson: (lesson: CampusLesson, topic: CampusTopic)? {
        let learned = CampusProgress.learned(campusLearnedRaw)
        for topic in campusTopics {
            if let lesson = topic.lessons.first(where: { !learned.contains($0.id) }) { return (lesson, topic) }
        }
        return nil
    }

    private var learnedToday: Bool {
        _ = campusLearnedRaw
        return CampusProgress.newLessonDates().contains { calendar.isDateInToday($0) }
    }

    private var reflectedToday: Bool {
        _ = revision
        return MindsetStore.reflection(on: .now) != nil
    }

    private var completion: DayCompletion {
        DayCompletion(checkedIn: todaysCheckIn != nil, trained: loggedToday, learned: learnedToday, reflected: reflectedToday)
    }

    private var isEvening: Bool { calendar.component(.hour, from: .now) >= 18 }

    /// Constant fatigue while training hard (see Safety.swift).
    private var lowEnergy: LowEnergyWarning? {
        status == .active ? LowEnergyCheck.current(for: athlete) : nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    header
                    if !introSeen { introCard }
                    if let lowEnergy, !lowEnergySnoozed {
                        LowEnergyCard(warning: lowEnergy) {
                            LowEnergyCheck.snoozeForAWeek()
                            lowEnergySnoozed = true
                        }
                    }
                    if isEvening && isTrainingDay && status != .holiday { eveningCard }
                    if isTrainingDay { morningCard }
                    if !scheduleIsSet && status == .active { scheduleCard }
                    todaySection
                    if gameToday != nil && status == .active { gameRoutinesCard }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: allSessions.count + athlete.checkIns.count) {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                status = DayStatusStore.status()
                loaded = true
            }
            .sheet(item: $activeSheet, onDismiss: {
                status = DayStatusStore.status()
                revision += 1
                runPendingAction()
            }) { sheet in
                switch sheet {
                case .quickActions:
                    QuickActionsSheet { action in
                        pendingAction = action
                        activeSheet = nil
                    }
                    .presentationDetents([.height(560)])
                case .checkIn:
                    CheckInSheet(athlete: athlete)
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
                case .safety:
                    SafetyCenterView()
                case .reflection:
                    ReflectionSheet(completion: completion, practiceToday: practiceToday) { revision += 1 }
                case .schedule:
                    ScheduleSheet(athlete: athlete) {
                        practiceDays = PracticeSchedule.weekdays
                        scheduleIsSet = PracticeSchedule.isSet
                        onPlanInputsChanged()
                    }
                }
            }
            .sheet(item: $preview) { box in
                SessionPreviewSheet(session: box.session, catalogue: catalogue) {
                    preview = nil
                    liveLaunch = LiveSessionLaunch(planned: box.session, kind: box.kind)
                }
            }
            .fullScreenCover(item: $routine, onDismiss: { revision += 1 }) { routine in
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

    // MARK: - Top

    /// The kind of day on the left; the streak and "+" on the right.
    private var topBar: some View {
        HStack(spacing: 10) {
            Button { activeSheet = .dayStatus } label: {
                HStack(spacing: 8) {
                    Image(systemName: status.systemImage)
                    Text(status.title)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status == .active ? AppTheme.ink : AppTheme.onAccent)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(status == .active ? AppTheme.card : AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Today is: \(status.title). Change what kind of day it is.")
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(AppTheme.orange)
                Text("\(streak)").foregroundStyle(AppTheme.ink).contentTransition(.numericText())
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AppTheme.card, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
            Button { activeSheet = .quickActions } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add: log a workout, add a game, food or past workouts")
        }
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        guard let name = athlete.displayName?.split(separator: " ").first, !name.isEmpty else { return part }
        return "\(part), \(name)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            QuoteCard(quote: DailyQuotes.short())
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your day in Athlete OS")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text("Check in each morning. Train. Learn a little. Reflect in the evening. Tomorrow's plan adapts.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Got it") { withAnimation { introSeen = true } }
                .buttonStyle(.secondary)
        }
        .cardStyle(padding: 20)
    }

    // MARK: - Morning: check-in, then readiness

    @ViewBuilder
    private var morningCard: some View {
        if todaysCheckIn == nil {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Morning check-in")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("30 seconds")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Text("Sleep, energy, soreness. Today's plan adapts to it.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Check in") { activeSheet = .checkIn }
                    .buttonStyle(.primary)
            }
            .cardStyle(padding: 20)
        } else if let readiness {
            Button { activeSheet = .checkIn } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TODAY'S READINESS")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    ReadinessBlock(level: readiness.level, reason: readiness.reason)
                        .multilineTextAlignment(.leading)
                }
                .cardStyle(padding: 20)
            }
            .buttonStyle(.plain)
            if let pain = PainStore.report() {
                Button { activeSheet = .safety } label: {
                    ListRow(systemImage: "bandage.fill", color: AppTheme.coral, title: "You reported pain",
                            detail: pain.involvesHead ? "Hit your head? Stop training and tell an adult." : "Skip anything that hurts. Safety Center")
                        .cardStyle(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When is practice?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text("Your plan is built around it.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Button("Set up my schedule") { activeSheet = .schedule }
                .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    // MARK: - TODAY

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.secondaryText)
            if status == .concussion {
                pausedCard
            } else {
                VStack(spacing: 0) {
                    let rows = todayRows
                    ForEach(rows.indices, id: \.self) { index in
                        rows[index]
                        if index < rows.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .cardStyle(padding: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why this plan?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(whyThisPlan)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if readinessBand != nil, todaysWorkout != nil {
                        Button("Train as planned instead") { readinessOverridden = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(minHeight: 44)
                    } else if readinessOverridden {
                        Button("Use the lighter plan") { readinessOverridden = false }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// Everything on today, in the order it happens.
    private var todayRows: [AnyView] {
        var rows: [AnyView] = []
        if !loaded {
            rows.append(AnyView(ProgressView().frame(maxWidth: .infinity, minHeight: 56)))
            return rows
        }
        if status == .sick {
            rows.append(AnyView(ListRow(systemImage: "bed.double.fill", color: AppTheme.purple, title: "Rest and recover",
                                        detail: "No training. Drink, eat and sleep.") { EmptyView() }))
        }
        if let game = gameToday, status == .active {
            rows.append(AnyView(Button { activeSheet = .fuel } label: {
                ListRow(systemImage: "sportscourt.fill", color: AppTheme.green,
                        title: game.kind == .tournament ? "Tournament" : (game.kind == .meet ? "Meet" : "Game"),
                        detail: "\(game.isHome ? "Home" : "Away") · What to eat before") {
                    timeText(game.date)
                }
            }.buttonStyle(.plain)))
        }
        if practiceToday, status == .active, gameToday == nil {
            rows.append(AnyView(Button { activeSheet = .schedule } label: {
                ListRow(systemImage: "person.3.fill", color: AppTheme.orange, title: "Team practice", detail: practiceDetail) {
                    if let start = practiceStart { timeText(start) }
                }
            }.buttonStyle(.plain)))
        }
        if isTrainingDay {
            for assignment in CoachAssignments.today() {
                rows.append(AnyView(ListRow(systemImage: "megaphone.fill", color: AppTheme.brand, title: assignment.title,
                                            detail: "From your coach · \(assignment.items.count) exercises") {
                    startButton { liveLaunch = LiveSessionLaunch(planned: CoachAssignments.session(assignment, catalogue: catalogue), kind: .coach) }
                }))
            }
        }
        if let workout = todaysWorkout {
            rows.append(AnyView(Button { preview = PreviewBox(session: workout.session, kind: workoutKind(workout.mode)) } label: {
                ListRow(systemImage: workoutIcon(workout.mode), color: AppTheme.brand,
                        title: status == .active ? workout.mode.title : "\(workout.mode.title) (optional)",
                        detail: workoutDetail(workout.session)) {
                    if loggedToday {
                        doneMark
                    } else {
                        startButton { liveLaunch = LiveSessionLaunch(planned: workout.session, kind: workoutKind(workout.mode)) }
                    }
                }
            }.buttonStyle(.plain)))
        } else if status == .active, gameToday == nil, !practiceToday {
            rows.append(AnyView(ListRow(systemImage: "moon.zzz.fill", color: AppTheme.purple, title: "Rest day",
                                        detail: "Recovery is part of the plan.") { loggedToday ? AnyView(doneMark) : AnyView(EmptyView()) }))
        }
        if let movementPrep {
            rows.append(AnyView(Button { preview = PreviewBox(session: movementPrep, kind: .mobility) } label: {
                ListRow(systemImage: "figure.flexibility", color: AppTheme.water, title: "Movement prep",
                        detail: "\(movementPrep.estimatedMinutes) min · loosen up")
            }.buttonStyle(.plain)))
        }
        if let next = nextLesson {
            rows.append(AnyView(Button { selectedTab = .campus } label: {
                ListRow(systemImage: "graduationcap.fill", color: AppTheme.purple, title: next.lesson.title,
                        detail: "Campus · \(next.lesson.minutes) min") {
                    if learnedToday {
                        doneMark
                    } else {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }.buttonStyle(.plain)))
        }
        return rows
    }

    private var practiceStart: Date? {
        if let event = practicesToday.first(where: { !$0.cancelled }), !event.allDay { return event.start }
        guard let time = PracticeSchedule.time(on: .now) else { return nil }
        return calendar.date(bySettingHour: time.start / 60, minute: time.start % 60, second: 0, of: .now)
    }

    private var practiceDetail: String {
        if let event = practicesToday.first(where: { !$0.cancelled }), let location = event.location, !location.isEmpty { return location }
        return "Your sport's training"
    }

    private func workoutDetail(_ session: GeneratedSession) -> String {
        var parts = ["\(session.estimatedMinutes) min", "\(session.items.count) exercises"]
        if readinessBand != nil { parts.append("lighter") } else if examWeek { parts.append("exam week") }
        return parts.joined(separator: " · ")
    }

    private func timeText(_ date: Date) -> some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
    }

    private var doneMark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title2)
            .foregroundStyle(AppTheme.green)
            .accessibilityLabel("Done")
    }

    private func startButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Start")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.onAccent)
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .background(AppTheme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func workoutIcon(_ mode: WorkoutMode) -> String {
        switch mode {
        case .afterPractice: "bolt.fill"
        case .gymDay: "dumbbell.fill"
        case .mobility: "figure.flexibility"
        case .travel: "suitcase.fill"
        }
    }

    private func workoutKind(_ mode: WorkoutMode) -> WorkoutKind {
        switch mode {
        case .afterPractice: .afterPractice
        case .gymDay: .gym
        case .mobility: .mobility
        case .travel: .travel
        }
    }

    /// A head injury pauses everything until a doctor clears the athlete.
    private var pausedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Training paused", systemImage: "pause.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text("Until a doctor clears you after the head injury.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Button("Safety Center") { activeSheet = .safety }
                .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    // MARK: - Evening

    @ViewBuilder
    private var eveningCard: some View {
        if reflectedToday {
            Button { activeSheet = .reflection } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today completed")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Text("\(completion.doneCount) of \(completion.items.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    HStack(spacing: 8) {
                        ForEach(completion.items) { item in
                            Label(item.title, systemImage: item.done ? "checkmark.circle.fill" : "circle")
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .foregroundStyle(item.done ? AppTheme.green : AppTheme.secondaryText.opacity(0.4))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 20)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Evening reflection")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("1 minute")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Text("How today went. Tomorrow's plan adapts to it.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Button("Reflect") { activeSheet = .reflection }
                    .buttonStyle(.primary)
            }
            .cardStyle(padding: 20)
        }
    }

    /// Game day: get the head ready too.
    private var gameRoutinesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get your head ready")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            ButtonRow {
                Button { routine = .breathing } label: { Label("Breathing · 2 min", systemImage: "wind") }
                    .buttonStyle(.secondary)
                Button { routine = .visualization } label: { Label("Visualize · 5 min", systemImage: "eye.fill") }
                    .buttonStyle(.secondary)
            }
        }
        .cardStyle(padding: 20)
    }
}

/// `GeneratedSession` isn't Identifiable; this wraps one for `.sheet(item:)`.
struct PreviewBox: Identifiable {
    let id = UUID()
    let session: GeneratedSession
    var kind: WorkoutKind? = nil
    /// Where the workout comes from, so it can be edited: a planned workout…
    var slot: PlanSlot? = nil
    /// …or one of the athlete's own.
    var myWorkoutID: UUID? = nil
}

/// Today's quote: small, two lines, never the headline.
struct QuoteCard: View {
    let quote: DailyQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“\(quote.text)”")
                .font(.callout.italic())
                .foregroundStyle(AppTheme.ink.opacity(0.85))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(quote.author)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        StepScaffold(title: "What kind of day is it?", subtitle: "Your plan and reminders follow it.",
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: { onSave(choice, choice == .active ? nil : days) }) {
            VStack(spacing: 10) {
                ForEach(DayStatus.menu) { status in
                    Button { choice = status } label: {
                        OptionRow(title: status.title, subtitle: status.explanation, systemImage: status.systemImage, isSelected: choice == status)
                    }
                    .buttonStyle(.plain)
                }
            }
            if choice != .active {
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
        .onAppear { choice = DayStatus.menu.contains(current) ? current : .active }
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
    /// Offered when the workout can be changed / shared.
    var onEdit: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
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
                    if onEdit != nil || onShare != nil {
                        ButtonRow {
                            if let onEdit {
                                Button { onEdit() } label: { Label("Change it", systemImage: "slider.horizontal.3") }
                                    .buttonStyle(.secondary)
                            }
                            if let onShare {
                                Button { onShare() } label: { Label("Share", systemImage: "qrcode") }
                                    .buttonStyle(.secondary)
                            }
                        }
                    }
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


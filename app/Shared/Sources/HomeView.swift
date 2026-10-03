#if os(iOS)
import StoreKit
#endif
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Home — the command center (V3). One calm screen that answers "what do I
/// do today?": the kind of day and the streak, a greeting and a short quote,
/// the morning check-in (then today's readiness), the TODAY list, why the
/// plan looks like this, and in the evening the reflection.
/// PREPARE → PERFORM → LEARN → REFLECT → ADAPT. Below it, the widgets the
/// athlete added in Edit Home (none by default).
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
    /// Picked in "Today completed": opens once that popup has closed.
    @State private var pendingToDo: DayCompletion.Kind?
    /// Picked in search: opens once the search has closed.
    @State private var pendingSearch: AppSearchTarget?
    @State private var searchDestination: SearchBox?
    @State private var proFeature: ProFeature?
    @State private var showingUpgrade = false
    /// A workout started from a sheet opened by search: starts once it closes.
    @State private var pendingLive: LiveSessionLaunch?
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    /// Now, for the part of the day (morning, day, evening, night).
    @State private var clock = Date.now
    @State private var showingWhy = false
    @State private var preview: PreviewBox?
    @State private var loaded = false
    @State private var routine: MindsetRoutine?
    @State private var lowEnergySnoozed = LowEnergyCheck.isSnoozed
    /// The coach's latest announcement (closed ones stay closed).
    @State private var announcement = TeamAnnouncements.current
    /// Bumped when a sheet closes, so what it changed (reflection, pain, day status) redraws.
    @State private var revision = 0
    #if os(iOS)
    @Environment(\.requestReview) private var requestReview
    #endif
    @State private var layout = HomeLayout.load()
    @State private var editingLayout = false
    @State private var wiggle = false
    /// The widget being held while arranging, and where the board is in reordering it.
    @State private var drag = HomeDragState()

    enum HomeSheet: String, Identifiable {
        case quickActions, checkIn, addGame, history, fuel, dayStatus, schedule, reflection, today, search, safety, mindset, tests, windDown, seasonReview, tournament
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
            struggles: Struggles.selected,
            prepMoment: PrepMoment.at(.now, gameToday: gameToday != nil)
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
    /// Today's decision from the rules (safety first; see KnowledgeSystem.swift).
    private var planning: PlanningEvaluation {
        _ = revision
        return PlanningRules.today(athlete, sessions: allSessions)
    }

    private var todaysWorkout: (mode: WorkoutMode, session: GeneratedSession)? {
        // No added training when the rules say so (game near, illness, pain…).
        guard planning.decision.allowsAddedTraining else { return nil }
        switch status {
        case .sick, .concussion: return nil
        case .travel, .holiday:
            return engine(.travel).map { (mode: WorkoutMode.travel, session: $0) }
        case .active:
            if gameToday != nil { return nil }
            if practiceToday {
                return engine(.afterPractice).map { (mode: WorkoutMode.afterPractice, session: $0) }
            }
            let planned = week?.sessions.first(where: { calendar.isDateInToday($0.date) })
            // The athlete's own version of this gym day stays exactly theirs.
            if let planned, let slot = planned.slot, PlanCustomizationStore.load().workout(for: .gym(slot)) != nil {
                return (mode: WorkoutMode.gymDay, session: adjusted(planned))
            }
            // V6: the engine decides — a development day, a primer before a
            // game, recovery, a programmed conditioning day, or rest.
            if TodayEngine.isAvailable(catalogue) {
                return TodayEngine.session(nil, athlete: athlete, sessions: allSessions, catalogue: catalogue, plannedGymDay: planned != nil)
                    .map { (mode: WorkoutMode.gymDay, session: $0) }
            }
            return planned.map { (mode: WorkoutMode.gymDay, session: adjusted($0)) }
        }
    }

    /// A workout of this kind for today: the athlete's own version, the V6
    /// engine's, or (old packs) the previous builder's with today's adjustments.
    private func engine(_ mode: WorkoutMode) -> GeneratedSession? {
        let plannedGymDay = week?.sessions.contains { calendar.isDateInToday($0.date) } ?? false
        guard let session = TodayEngine.workout(mode, athlete: athlete, sessions: allSessions, catalogue: catalogue,
                                                context: modeContext, plannedGymDay: plannedGymDay) else { return nil }
        if session.decision != nil { return session }
        return mode == .afterPractice ? adjusted(session) : TodaysPain.apply(session, athlete: athlete, catalogue: catalogue)
    }

    /// A low-readiness day lightens the workout (the athlete can undo it).
    /// Today's pain first (nothing that loads a sore area), then readiness.
    private func adjusted(_ session: GeneratedSession) -> GeneratedSession {
        // The V6 engine already took pain, readiness and the day into account.
        if session.decision != nil { return session }
        let safe = TodaysPain.apply(session, athlete: athlete, catalogue: catalogue)
        // Back after illness or a long school day: shorter too.
        let ruleBand: ReadinessBand? = planning.reasonCodes.contains { ["RETURN_AFTER_ILLNESS", "LONG_SCHOOL_DAY"].contains($0) } ? .amber : nil
        guard let band = readinessBand ?? ruleBand else { return safe }
        return ReadinessApplier.apply(to: safe, band: band).session
    }

    private var movementPrep: GeneratedSession? {
        isTrainingDay ? engine(.mobility) : nil
    }

    // MARK: - Food around practice and games

    @AppStorage("gameStartMinutes") private var gameStartMinutes = 17 * 60
    @State private var prePracticeAnswer: Bool?

    /// Game day: the next two fuel steps, timed from the game.
    private var gameFuelTips: [FuelTip]? {
        guard let game = gameToday, status == .active else { return nil }
        let start = FuelEngine.gameStart(game.date, usualMinutes: gameStartMinutes, calendar: calendar)
        return Array(FuelEngine.gameDayTimeline(gameStart: start, isTournament: game.kind == .tournament)
            .filter { ($0.time ?? .distantFuture) > .now.addingTimeInterval(-15 * 60) && $0.time != nil }
            .prefix(2))
    }

    private func gameFuelCard(_ tips: [FuelTip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Game-day fuel").font(.title3.weight(.semibold)).foregroundStyle(AppTheme.ink)
            ForEach(tips) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Text(tip.time?.formatted(date: .omitted, time: .shortened) ?? "")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 64, alignment: .leading)
                    Text(tip.title).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// In the three hours before practice: one question, not a food diary.
    private var askPrePracticeFuel: Bool {
        guard status == .active, practiceToday, prePracticeAnswer != true,
              let time = PracticeSchedule.time(on: .now) else { return false }
        let now = calendar.component(.hour, from: .now) * 60 + calendar.component(.minute, from: .now)
        guard now >= time.start - 180, now <= time.start + 15 else { return false }
        return !MealStore.meals(of: athlete, on: .now).contains { $0.slot == .preTraining }
    }

    private var prePracticeFuelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Did you eat before practice?").font(.title3.weight(.semibold)).foregroundStyle(AppTheme.ink)
            if prePracticeAnswer == false {
                Text("A banana, toast or a cereal bar now gives you energy for practice.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            ButtonRow {
                Button("Yes") {
                    _ = try? MealStore(modelContext: modelContext).logMeal(athlete: athlete, slot: .preTraining, protein: 0, carbs: 1, colour: 0)
                    prePracticeAnswer = true
                }
                .buttonStyle(.primary)
                Button("Not yet") { prePracticeAnswer = false }
                    .buttonStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Sundays: the week in review (what you did, one highlight, next week's focus).
    private var weeklyReview: WeeklyReview? {
        guard calendar.component(.weekday, from: .now) == 1 else { return nil }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let results = BenchmarkStore.results
        let newBests = BenchmarkCatalog.tests(for: athlete.activeSport?.sportSlug).compactMap { test -> String? in
            guard let latest = results.filter({ $0.testID == test.id && $0.date > weekAgo }).last,
                  BenchmarkMath.isPersonalBest(latest.value, test: test, before: results.filter { $0.testID == test.id && $0.date < latest.date })
            else { return nil }
            return "\(test.name) \(test.unit.format(latest.value))"
        }
        let nextWeekEnd = calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: .now)) ?? .now
        let games = athlete.competitions.filter { $0.date > .now && $0.date < nextWeekEnd }.count
        let nextMonday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let phase = athlete.activeSport.map { PhaseCalculator.phase(today: nextMonday, seasonStart: $0.seasonStart, seasonEnd: $0.seasonEnd) }
        let nextWeekStart = calendar.dateInterval(of: .weekOfYear, for: nextMonday)?.start ?? nextMonday
        let goal = BenchmarkGoals.all.first.flatMap { goal -> String? in
            guard let test = BenchmarkCatalog.tests(for: athlete.activeSport?.sportSlug).first(where: { $0.id == goal.testID }) else { return nil }
            return "\(test.name) \(test.unit.format(goal.target))"
        }
        return WeeklyReview.make(WeeklyReview.Input(
            sessionDates: allSessions.map(\.startedAt), sessionMinutes: allSessions.map(\.minutes),
            checkInDates: athlete.checkIns.map(\.date),
            lessonsThisWeek: CampusProgress.newLessonDates().filter { $0 > weekAgo }.count,
            newBests: newBests, streak: streak, gamesNextWeek: games,
            deloadNextWeek: phase.map { Deload.isDeloadWeek(weekStart: nextWeekStart, anchor: athlete.createdAt, phase: $0) } ?? false,
            phase: phase, goal: goal
        ), now: .now)
    }

    /// From 6 pm: tonight's bedtime for 9 hours before tomorrow's start, and
    /// last week's sleep when it's been short.
    private var bedtimeTonight: (minutes: Int, detail: String)? {
        guard calendar.component(.hour, from: .now) >= 18, status != .sick else { return nil }
        let settings = ReminderScheduler.settings
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) else { return nil }
        let early = Bedtime.firstSessionStart(on: tomorrow, games: athlete.competitions.map(\.date), calendar: calendar)
        let wake = ReminderScheduler.nextWake(after: .now, settings: settings, calendar: calendar)
        let minutes = Bedtime.suggested(wakeMinutes: wake, firstSessionTomorrow: early)
        let week = athlete.checkIns.filter { $0.date > calendar.date(byAdding: .day, value: -7, to: .now) ?? .now }.compactMap(\.sleepHours)
        let average = week.isEmpty ? nil : week.reduce(0, +) / Double(week.count)
        if let average, average < 8 {
            return (minutes, "You've averaged \(average.formatted(.number.precision(.fractionLength(1)))) h this week")
        }
        return (minutes, early != nil ? "Early start tomorrow: 9 h of sleep" : "9 h before tomorrow")
    }

    private var streak: Int {
        AthleteStats.streak(checkInDates: athlete.checkIns.map(\.date), sessionDates: allSessions.map(\.startedAt))
    }

    private var daysToNextGame: Int? {
        AthleteStats.upcomingCompetitions(athlete).first.map { AthleteStats.daysUntil($0.date) }
    }

    private var whyThisPlan: String {
        if let explanation = planning.explanation, planning.decision > .modifyOptionalWork { return explanation }
        // V6: the engine's own reason for today's session.
        if let summary = todaysWorkout?.session.explanation?.summary { return summary }
        return DailyLoop.whyThisPlan(status: status, mode: todaysWorkout?.mode, practiceToday: practiceToday, gameToday: gameToday != nil,
                              daysToNextGame: daysToNextGame, readiness: readinessOverridden ? nil : readiness)
    }

    // MARK: - Learning and reflecting

    private var nextLesson: (lesson: CampusLesson, topic: CampusTopic)? {
        let learned = CampusProgress.learned(campusLearnedRaw)
        // A lesson for today's situation first (a short night, a game…).
        let context = LessonPicker.Context(
            sleepHours: todaysCheckIn?.sleepHours, sleepQuality: todaysCheckIn?.sleepQuality, soreness: todaysCheckIn?.soreness,
            energy: todaysCheckIn?.energy, daysToGame: daysToNextGame, pain: PainStore.report() != nil, examWeek: examWeek,
            gameYesterday: LessonSignals.gameYesterday(athlete), hardDayYesterday: LessonSignals.hardDayYesterday(),
            shortNights: LessonSignals.shortNights(athlete), lowConfidence: LessonSignals.lowConfidence(),
            trainingToday: todaysWorkout?.session.decision?.primaryTargets.map(\.rawValue) ?? [],
            inSeason: LessonSignals.inSeason(athlete), learned: learned
        )
        if let pick = LessonPicker.forToday(context), !(learnedToday && learned.contains(pick.id)),
           let found = LessonPicker.lesson(pick.id) { return found }
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


    /// Constant fatigue while training hard (see Safety.swift).
    private var lowEnergy: LowEnergyWarning? {
        status == .active ? LowEnergyCheck.current(for: athlete) : nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                // V4: centred and open — the part of the day decides what
                // Home is for (prepare, perform, reflect); details stay compact.
                VStack(spacing: 56) {
                    VStack(spacing: 22) {
                        topBar
                        header
                    }
                    if !introSeen { introCard }
                    if SeasonReviewStore.due(athlete) != nil {
                        Button { activeSheet = .seasonReview } label: {
                            ListRow(systemImage: "flag.checkered", color: AppTheme.ink, title: "Your season review",
                                    detail: "What you learned, enjoyed, and want next · 3 min")
                                .padding(.horizontal, 16)
                                .glassSurface()
                        }
                        .buttonStyle(.plain)
                    }
                    if let announcement {
                        AnnouncementCard(announcement: announcement) {
                            TeamAnnouncements.markSeen(announcement.id)
                            withAnimation { self.announcement = nil }
                        }
                    }
                    if let lowEnergy, !lowEnergySnoozed {
                        LowEnergyCard(warning: lowEnergy) {
                            LowEnergyCheck.snoozeForAWeek()
                            lowEnergySnoozed = true
                        }
                    }
                    VStack(spacing: 56) { dayContent }
                        .id(contentKey)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity))
                    if !scheduleIsSet && status == .active { scheduleCard }
                    if status == .travel {
                        Button { activeSheet = .tournament } label: {
                            ListRow(systemImage: "airplane", color: AppTheme.ink, title: "Tournament & travel",
                                    detail: "Time difference, between games, sleep away")
                                .padding(.horizontal, 16)
                                .glassSurface()
                        }
                        .buttonStyle(.plain)
                    }
                    if gameToday != nil && status == .active && phase != .night { gameRoutinesCard }
                    if let tips = gameFuelTips, !tips.isEmpty { gameFuelCard(tips) }
                    if askPrePracticeFuel { prePracticeFuelCard }
                    if loaded { HomeWeekBlock(week: weekSummary, accent: phase.red) }
                    widgetsSection
                }
                .animation(.easeInOut(duration: 0.45), value: contentKey)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            // Home's own backdrop: the hour's light at the top (other tabs stay plain).
            .background(HomeAmbientBackground(sportSlug: athlete.activeSport?.sportSlug))
            .contentMargins(.bottom, 24, for: .scrollContent)
            .modifier(ReadableWidth())
            .task {
                // Follows the day: a new part of the day shows up within a minute.
                for _ in 0..<1440 {
                    try? await Task.sleep(for: .seconds(60))
                    if Task.isCancelled { break }
                    clock = .now
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    clock = .now
                    revision += 1
                    announcement = TeamAnnouncements.current
                    switch IntentRoute.take([.checkIn, .reflection]) {
                    case .checkIn?: activeSheet = .checkIn
                    case .reflection?: activeSheet = .reflection
                    default: break
                    }
                }
            }
            // A push or the quiet check: the coach's new workout or note shows up now.
            .onChange(of: LiveUpdates.shared.tick) {
                revision += 1
                announcement = TeamAnnouncements.current
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: allSessions.count + athlete.checkIns.count) {
                switch IntentRoute.take([.checkIn, .reflection]) {
                case .checkIn?: activeSheet = .checkIn
                case .reflection?: activeSheet = .reflection
                default: break
                }
                // No prompts tied to streaks (Backend Knowledge System §18):
                // ratings are only asked after a new test best.
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                // The record of today's decision (Me → How AthleteOS decides).
                let planningContext = PlanningRules.context(athlete, sessions: allSessions)
                let evaluation = PlanningRules.evaluate(planningContext, disabled: Set(KnowledgeReleaseStore.current.disabledRules))
                DecisionTraceStore.record(evaluation, context: planningContext,
                                          selected: todaysWorkout.map { "\($0.mode.title) · \($0.session.estimatedMinutes) min" }
                                              ?? (evaluation.decision.allowsAddedTraining ? "No workout planned" : "No added workout"))
                status = DayStatusStore.status()
                if !loaded, DemoData.initialTab == .today, let name = DemoData.initialSheet { activeSheet = HomeSheet(rawValue: name) }
                loaded = true
            }
            .sheet(item: $activeSheet, onDismiss: {
                status = DayStatusStore.status()
                revision += 1
                runPendingAction()
                runPendingToDo()
                runPendingSearch()
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
                case .tournament:
                    TournamentModeView(onHotelWorkout: { selectedTab = .workout },
                                       onFood: { Task { @MainActor in try? await Task.sleep(for: .milliseconds(600)); activeSheet = .fuel } })
                case .windDown:
                    WindDownView(bedtime: bedtimeTonight.map { Bedtime.label($0.minutes) },
                                 gameTomorrow: athlete.competitions.contains { calendar.isDateInTomorrow($0.date) })
                case .seasonReview:
                    if let sport = athlete.activeSport {
                        SeasonReviewSheet(athlete: athlete, sport: sport, sessions: allSessions)
                    }
                case .safety:
                    SafetyCenterView()
                case .mindset:
                    MindsetView(sportName: AthleteStats.sportName(athlete)) { selectedTab = .campus }
                case .tests:
                    BenchmarksView(sportSlug: athlete.activeSport?.sportSlug)
                case .reflection:
                    ReflectionSheet(completion: completion, practiceToday: practiceToday,
                                    restDay: !loggedToday && !practiceToday && gameToday == nil) { revision += 1 }
                case .today:
                    TodayChecklistSheet(completion: completion,
                                        details: Dictionary(uniqueKeysWithValues: completion.items.map { ($0.kind, toDoDetail($0)) })) { kind in
                        pendingToDo = kind
                        activeSheet = nil
                    }
                    .presentationDetents([.medium, .large])
                case .search:
                    AppSearchSheet(entries: searchEntries, exercises: searchableExercises) { target in
                        pendingSearch = target
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
            .sheet(item: $searchDestination, onDismiss: {
                revision += 1
                if let launch = pendingLive {
                    pendingLive = nil
                    liveLaunch = launch
                }
            }) { box in
                searchView(box.target)
            }
            .proFeature(item: $proFeature, athlete: athlete)
            .proPaywall(isPresented: $showingUpgrade, athlete: athlete, feature: .multipleSports)
        }
    }

    // MARK: - Search

    struct SearchBox: Identifiable {
        let id = UUID()
        let target: AppSearchTarget
    }

    /// Everything search can find right now.
    private var searchEntries: [AppSearchEntry] {
        AppSearch.functions + AppSearch.skills(sportInfo) + AppSearch.workoutModes() + AppSearch.gymDays(week)
            + AppSearch.myWorkouts(MyWorkoutsStore.load()) + AppSearch.lessons(learned: CampusProgress.learned(campusLearnedRaw))
    }

    /// General exercises and the drills of the athlete's own sport(s) only.
    private var searchableExercises: [CatalogueItem] {
        let sports = SportVisibility.sports(for: athlete)
        return catalogue.itemsBySlug.values
            .filter { SportVisibility.isVisible($0, sports: sports) }
            .sorted { $0.name < $1.name }
    }

    private func runPendingSearch() {
        guard let target = pendingSearch else { return }
        pendingSearch = nil
        switch target {
        case .checkIn: activeSheet = .checkIn
        case .addGame: activeSheet = .addGame
        case .history: activeSheet = .history
        case .fuel: activeSheet = .fuel
        case .dayStatus: activeSheet = .dayStatus
        case .schedule: activeSheet = .schedule
        case .reflection: activeSheet = .reflection
        case .today: activeSheet = .today
        case .safety: activeSheet = .safety
        case .mindset: activeSheet = .mindset
        case .tests: activeSheet = .tests
        case .logWorkout: liveLaunch = LiveSessionLaunch(planned: nil)
        case .breathing: routine = .breathing
        case .visualization: routine = .visualization
        case .tab(let tab): selectedTab = tab
        case .lesson(let id):
            CampusLaunch.shared.pendingLessonID = id
            selectedTab = .campus
        case .workoutMode(let mode):
            if let session = searchSession(mode) {
                preview = PreviewBox(session: session, kind: workoutKind(mode))
            } else {
                selectedTab = .workout
            }
        case .gymDay(let index):
            if let sessions = week?.sessions, sessions.indices.contains(index) {
                preview = PreviewBox(session: adjusted(sessions[index]), kind: .gym)
            }
        case .myWorkout(let id):
            if let workout = MyWorkoutsStore.load().first(where: { $0.id == id }) {
                preview = PreviewBox(session: TodaysPain.apply(workout.session(date: .now, catalogue: catalogue), athlete: athlete, catalogue: catalogue),
                                     kind: .gym)
            }
        case .exerciseProgress:
            if ProAccess.isPro { searchDestination = SearchBox(target: target) } else { proFeature = .exerciseProgress }
        case .upgrade: showingUpgrade = true
        case .link(let path): openURL(AppConfig.backendBaseURL.appending(path: path))
        case .editHome:
            editingLayout = true
            wiggle = true
        case .newWorkout:
            if ProGate.canKeepAnotherWorkout(isPro: ProAccess.isPro, myWorkoutCount: MyWorkoutsStore.load().count) {
                searchDestination = SearchBox(target: target)
            } else {
                proFeature = .myWorkouts
            }
        default: searchDestination = SearchBox(target: target)
        }
    }

    /// A workout type found in search, built for today like Home's own.
    private func searchSession(_ mode: WorkoutMode) -> GeneratedSession? {
        if mode == .gymDay {
            let planned = week?.sessions.first { calendar.isDateInToday($0.date) } ?? week?.sessions.first
            return planned.map { adjusted($0) }
        }
        return engine(mode)
    }

    @ViewBuilder
    private func searchView(_ target: AppSearchTarget) -> some View {
        switch target {
        case .practiceLog: PracticeLogSheet(athlete: athlete, date: .now)
        case .sports: SportsManagerSheet(athlete: athlete, onChanged: onPlanInputsChanged)
        case .season: SeasonEditorSheet(athlete: athlete, onSaved: onPlanInputsChanged)
        case .equipment: EquipmentEditorSheet(athlete: athlete, onSaved: onPlanInputsChanged)
        case .experience: ExperienceEditorSheet(onSaved: onPlanInputsChanged)
        case .name: NameEditorSheet(athlete: athlete)
        case .reports:
            #if os(iOS)
            ReportsSheet(athlete: athlete, sessions: allSessions, catalogue: catalogue)
            #else
            EmptyView()
            #endif
        case .checkIns: CheckInHistoryView(checkIns: athlete.checkIns)
        case .exerciseProgress: ExerciseProgressListView(sessions: allSessions, catalogue: catalogue)
        case .dataExport: DataExportView(athlete: athlete, sessions: allSessions)
        case .reminders: RemindersSheet(athlete: athlete)
        case .downloads: DownloadsSheet(athlete: athlete)
        case .health: HealthPermissionView()
        case .help: HelpCenterView()
        case .team: MyTeamView()
        case .coach: CoachView()
        case .parent: ParentSummaryView()
        case .goals: StrugglesSheet(onSaved: onPlanInputsChanged)
        case .trends:
            TrendsSheet(athlete: athlete, sessions: allSessions, balance: CoachEngine.muscleBalance(sessions: allSessions.map { session in
                CoachSession(date: session.startedAt, minutes: session.minutes, rpe: session.sessionRPE,
                             sets: session.sets.map { CoachSet(itemSlug: $0.itemSlug, reps: $0.reps, weightKg: $0.weightKg) })
            }, catalogue: catalogue))
        case .library: LibraryView(athlete: athlete)
        case .sportGuide: SportGuideView(athlete: athlete)
        case .leagues: LeaguesView(stats: CampusProgress.stats())
        case .badges: BadgesView()
        case .newGymPlan: NewGymPlanSheet(athlete: athlete, gymDays: week?.sessions.count ?? 3, onChanged: onPlanInputsChanged)
        case .skillPlans: ImproveView(athlete: athlete, apiClient: apiClient, onPlanInputsChanged: onPlanInputsChanged)
        case .skill(let slug):
            ImproveView(athlete: athlete, apiClient: apiClient, onPlanInputsChanged: onPlanInputsChanged, initialSkillSlug: slug)
        case .muscleWorkouts:
            ImproveView(athlete: athlete, apiClient: apiClient, onPlanInputsChanged: onPlanInputsChanged, initialMode: .muscles)
        case .planSettings: PlanSettingsSheet(onChanged: onPlanInputsChanged)
        case .newWorkout:
            WorkoutEditorView(heading: "New workout", workout: CustomWorkout(title: "My workout", items: []),
                              sportSlug: athlete.activeSport?.sportSlug) { saved in
                MyWorkoutsStore.upsert(saved)
            }
        case .addWithCode:
            SharedWorkoutSheet(onSaved: { MyWorkoutsStore.upsert($0) }, onStart: { workout in
                pendingLive = LiveSessionLaunch(planned: workout.session(date: .now, catalogue: catalogue), kind: .gym)
            })
        case .addTraining: ExtraPracticeSheet { onPlanInputsChanged() }
        case .calendars: ScheduleSheet(athlete: athlete, onChanged: onPlanInputsChanged)
        case .sportPosition: SportEditorSheet(athlete: athlete, onSaved: onPlanInputsChanged)
        default: EmptyView()
        }
    }

    private func runPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .logWorkout: liveLaunch = LiveSessionLaunch(planned: nil)
        case .checkIn: activeSheet = .checkIn
        case .addGame: activeSheet = .addGame
        case .improve: searchDestination = SearchBox(target: .skillPlans)
        case .history: activeSheet = .history
        case .fuel: activeSheet = .fuel
        }
    }

    /// "Today completed": finish what's open, or change what's done.
    private func runPendingToDo() {
        guard let kind = pendingToDo else { return }
        pendingToDo = nil
        switch kind {
        case .checkIn: activeSheet = .checkIn
        case .reflection: activeSheet = .reflection
        case .lesson: selectedTab = .campus
        case .training:
            if loggedToday {
                activeSheet = .history
            } else if let workout = todaysWorkout {
                preview = PreviewBox(session: workout.session, kind: workoutKind(workout.mode))
            } else {
                selectedTab = .workout
            }
        }
    }

    /// One line under each item in "Today completed".
    private func toDoDetail(_ item: DayCompletion.Item) -> String {
        switch item.kind {
        case .checkIn:
            return item.done ? readiness.map { "Readiness: \($0.level.title)" } ?? "Done" : "30 seconds"
        case .training:
            if item.done { return "Logged · see or change it" }
            return todaysWorkout.map { "\($0.mode.title) · \($0.session.estimatedMinutes) min" } ?? "Pick a workout"
        case .lesson:
            if item.done { return "Learned today · open Campus" }
            return nextLesson.map { "\($0.lesson.title) · \($0.lesson.minutes) min" } ?? "Open Campus"
        case .reflection:
            return item.done ? "Done" : "1 minute"
        }
    }

    // MARK: - Top

    /// Small floating glass controls: the kind of day, search, "+".
    private var topBar: some View {
        HStack(spacing: 8) {
            Button { activeSheet = .dayStatus } label: {
                HStack(spacing: 7) {
                    Image(systemName: status.systemImage)
                        .foregroundStyle(status == .active ? AppTheme.secondaryText : phase.red)
                    Text(status.title)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .glassCapsule()
            }
            .buttonStyle(.plain)
            // Always readable in full: search gives way (down to its icon).
            .fixedSize()
            .layoutPriority(1)
            .accessibilityLabel("Today is: \(status.title). Change what kind of day it is.")
            searchButton
            Button { activeSheet = .quickActions } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .glassCapsule()
                    .overlay { Circle().strokeBorder(phase.red.opacity(0.5), lineWidth: 1) }
                    .shadow(color: phase.red.opacity(0.35), radius: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add: log a workout, add a game, food or past workouts")
        }
    }

    /// Search everything: fills the space between the day and the "+".
    private var searchButton: some View {
        Button { activeSheet = .search } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Image(systemName: "magnifyingglass")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .glassCapsule()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
        .accessibilityHint("Find any part of the app, a workout, a lesson or an exercise")
    }

    private var firstName: String? {
        guard let name = athlete.displayName?.split(separator: " ").first, !name.isEmpty else { return nil }
        return String(name)
    }

    private var greeting: String {
        firstName.map { "\(phase.greeting), \($0)" } ?? phase.greeting
    }

    // MARK: - The part of the day (V4)

    /// Refreshed every minute and when the app comes back, so Home follows the day.
    private var phase: DayPhase { DayPhase.at(clock) }

    private var todaysSessions: [Session] { allSessions.filter { calendar.isDateInToday($0.startedAt) } }
    private var workoutDoneToday: Bool { todaysSessions.contains { SessionKinds.kind(of: $0.clientId) != .mobility } }
    private var mobilityDoneToday: Bool { todaysSessions.contains { SessionKinds.kind(of: $0.clientId) == .mobility } }
    private var practiceLogToday: PracticeLog? {
        _ = revision
        return PracticeLogStore.log(on: DayKey.of(.now), sportSlug: athlete.activeSport?.sportSlug)
    }

    private var dayProgress: DayProgress {
        DayProgress(practiceToday: practiceToday && status == .active && gameToday == nil, practiceLogged: practiceLogToday != nil,
                    workoutPlanned: todaysWorkout != nil && status == .active, workoutDone: workoutDoneToday,
                    mobilityDone: mobilityDoneToday, reflected: reflectedToday,
                    restDay: todaysWorkout == nil && status == .active && gameToday == nil)
    }

    private var weekSummary: WeekSummary {
        _ = revision
        return WeekSummary.make(
            now: clock,
            sessions: allSessions.map { (date: $0.startedAt, mobility: SessionKinds.kind(of: $0.clientId) == .mobility) },
            practiceDays: PracticeLogStore.logs.map(\.day),
            checkInDates: athlete.checkIns.map(\.date)
        )
    }

    /// What's on screen, so a change (a check-in, a reflection, the evening)
    /// animates in instead of jumping.
    private var contentKey: String {
        "\(phase.rawValue)-\(todaysCheckIn != nil)-\(reflectedToday)-\(workoutDoneToday)-\(status.rawValue)"
    }

    /// The season the active sport is in ("IN SEASON").
    private var seasonLine: String? {
        guard let sport = athlete.activeSport else { return nil }
        let phase = PhaseCalculator.phase(today: clock, seasonStart: sport.seasonStart, seasonEnd: sport.seasonEnd)
        switch phase {
        case .offSeason: return "Off-season"
        case .preSeason: return "Pre-season"
        case .inSeason: return "In season"
        case .postSeason: return "Post-season"
        }
    }

    /// An editorial opening: the greeting small, the name huge, the season,
    /// a short quote. No box around any of it.
    private var header: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: phase.systemImage)
                        .foregroundStyle(phase.red)
                        .symbolRenderingMode(.hierarchical)
                    Text(phase.greeting)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .font(.footnote.weight(.semibold))
                Text(firstName ?? clock.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 46, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                Text(clock.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
            }
            // Streaks live on Progress and Me now (V6 §21: secondary).
            HStack(spacing: 10) {
                SportSwitcher(athlete: athlete, onChanged: onPlanInputsChanged)
                if let seasonLine {
                    Text(seasonLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(phase.red.opacity(0.9))
                }
            }
            let quote = DailyQuotes.short(for: phase, date: clock)
            VStack(spacing: 4) {
                Text("“\(quote.text)”")
                    .font(.callout.italic())
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(quote.author)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your day in AthleteOS")
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

    // MARK: - The day, by its part: prepare, perform, reflect

    @ViewBuilder
    private var dayContent: some View {
        if !loaded {
            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
        } else if status == .concussion {
            pausedCard
        } else {
            switch phase {
            case .morning:
                if todaysCheckIn == nil {
                    checkInHero
                    scheduleList
                } else {
                    readinessHero
                    focusHero
                    supportingList(title: nil)
                    whySection
                }
            case .day:
                if todaysCheckIn == nil { checkInReminder }
                focusHero
                if todaysCheckIn != nil { readinessLine }
                supportingList(title: "Later today")
                whySection
            case .evening:
                if reflectedToday {
                    dayCompleteView
                } else {
                    todayCompleteHero
                    reflectionHero
                }
            case .night:
                if reflectedToday || workoutDoneToday { dayCompleteView } else { nightView }
            }
        }
    }

    // Morning, before the check-in: the check-in is the one thing to do.

    private var checkInHero: some View {
        VStack(spacing: 12) {
            HomeEyebrow("Morning check-in")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("30")
                    .font(.system(size: 82, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                Text("SEC")
                    .font(.title3.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .background(HeroBloom(color: phase.red))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("30 seconds")
            Text("Sleep · Energy · Body · Mood")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Button { activeSheet = .checkIn } label: { HeroCTALabel("Check in") }
                .buttonStyle(.primary)
                .padding(.top, 10)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
    }

    /// The day's fixed points, without a workout the check-in could still change.
    @ViewBuilder
    private var scheduleList: some View {
        let rows = scheduleRows
        if !rows.isEmpty {
            VStack(spacing: 6) {
                HomeEyebrow("Today's schedule")
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        rows[index]
                        if index < rows.count - 1 { Divider().opacity(0.5) }
                    }
                }
            }
        }
    }

    private var scheduleRows: [AnyView] {
        var rows: [AnyView] = []
        if let game = gameToday, status == .active {
            rows.append(AnyView(HomeDetailRow(systemImage: "sportscourt.fill", color: AppTheme.green, title: gameTitle(game)) {
                Text(game.date.formatted(date: .omitted, time: .shortened))
            }))
        }
        if practiceToday, status == .active, gameToday == nil {
            rows.append(AnyView(HomeDetailRow(systemImage: "person.3.fill", color: AppTheme.orange, title: "Practice") {
                if let start = practiceStart { Text(start.formatted(date: .omitted, time: .shortened)) }
            }))
        }
        if let workout = todaysWorkout {
            rows.append(AnyView(HomeDetailRow(systemImage: workoutIcon(workout.mode), color: phase.red, title: "Planned \(workout.mode.title.lowercased())") {
                Text("\(workout.session.estimatedMinutes) min")
            }))
        }
        return rows
    }

    /// In the day, when the morning check-in was skipped: a quiet reminder.
    private var checkInReminder: some View {
        Button { activeSheet = .checkIn } label: {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill").foregroundStyle(phase.red)
                Text("Not checked in yet · 30 seconds").foregroundStyle(AppTheme.ink)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AppTheme.secondaryText)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(AppTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // Readiness, centred: a state, never a score.

    /// Readiness as an instrument: one word, a short context, the three
    /// inputs, a quiet scale. Never a percentage.
    @ViewBuilder
    private var readinessHero: some View {
        if let readiness {
            VStack(spacing: 14) {
                HomeEyebrow("Today's readiness")
                Circle()
                    .fill(AppTheme.color(for: readiness.level.band))
                    .frame(width: 10, height: 10)
                    .shadow(color: AppTheme.color(for: readiness.level.band).opacity(0.8), radius: 8)
                    .accessibilityHidden(true)
                Text(readiness.level.title.uppercased())
                    .font(.system(size: 52, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(readinessContext(readiness.level))
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.secondaryText)
                if let checkIn = todaysCheckIn {
                    HStack(spacing: 0) {
                        readinessInput("Sleep", CheckInOptions.nearest(Double(checkIn.sleepQuality), in: CheckInOptions.sleepQuality)?.title)
                        readinessInput("Energy", CheckInOptions.nearest(Double(checkIn.energy), in: CheckInOptions.energy)?.title)
                        readinessInput("Body", CheckInOptions.nearest(Double(checkIn.soreness), in: CheckInOptions.soreness)?.title)
                    }
                    .padding(.top, 6)
                    .frame(maxWidth: 360)
                }
                ReadinessScale(level: readiness.level)
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
                HStack(spacing: 22) {
                    Button { withAnimation(.easeInOut(duration: 0.35)) { showingWhy.toggle() } } label: {
                        Label("Why?", systemImage: "arrow.right").labelStyle(TrailingIconLabel())
                    }
                    Button("Edit check-in") { activeSheet = .checkIn }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(minHeight: 44)
                if showingWhy {
                    Text(readiness.reason)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }
                painNote
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Level 2 of the answer: a few words of context.
    private func readinessContext(_ level: TodayReadiness) -> String {
        if PainFollowUp.pending(reports: PainStore.all(), resolvedDays: PainFollowUp.resolvedDays(), today: clock) != nil,
           AthleteStats.todaysCheckIn(athlete) == nil {
            return "PAIN REPORTED RECENTLY · CHECK IN"
        }
        switch level {
        case .normal: return "TRAIN AS PLANNED"
        case .reduced: return "LIGHTER TODAY"
        case .recovery: return "RECOVERY FOCUS"
        }
    }

    private func readinessInput(_ label: String, _ value: String?) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.mutedText)
            Text((value ?? "—").uppercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// In the day, readiness is one line under what's next.
    @ViewBuilder
    private var readinessLine: some View {
        if let readiness {
            Button { activeSheet = .checkIn } label: {
                HStack(spacing: 8) {
                    Circle().fill(AppTheme.color(for: readiness.level.band)).frame(width: 9, height: 9)
                    Text("Readiness: \(readiness.level.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(minHeight: 36)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            painNote
        }
    }

    @ViewBuilder
    private var painNote: some View {
        if let pain = PainStore.report() {
            Button { activeSheet = .safety } label: {
                Label(pain.involvesHead ? "Hit your head? Stop training and tell an adult."
                      : pain.areas.contains(.other) ? "Pain reported · only gentle mobility today"
                      : "Pain reported · today's workout leaves it alone",
                      systemImage: "bandage.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.coral)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(AppTheme.coral.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    // Today's focus: the one recommendation, centred and big.

    // Today's session: the title and the number dominate.

    @ViewBuilder
    private var focusHero: some View {
        VStack(spacing: 14) {
            if let game = gameToday, status == .active {
                HomeEyebrow("Game day")
                heroTitle(gameTitle(game))
                bigNumber(game.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()),
                          unit: game.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).filter(\.isLetter).uppercased())
                heroMeta(game.isHome ? "Home" : "Away")
                Button { activeSheet = .fuel } label: { HeroCTALabel("What to eat before") }
                    .buttonStyle(.primary)
                    .padding(.top, 6)
                    .frame(maxWidth: 300)
            } else if status == .sick {
                HomeEyebrow("Today")
                heroTitle("Rest and recover")
                heroMeta("No training today. Drink, eat, sleep.")
            } else if let workout = todaysWorkout {
                let session = workout.session
                HomeEyebrow(workoutDoneToday ? "Today's training" : (phase == .day ? "Next session" : "Today's session"))
                Button { preview = PreviewBox(session: session, kind: workoutKind(workout.mode)) } label: {
                    heroTitle(focusTitle(session, mode: workout.mode))
                }
                .buttonStyle(.plain)
                bigNumber("\(session.estimatedMinutes)", unit: "MIN")
                if let qualities = qualityLine(session) {
                    heroMeta(qualities)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    if session.decision == nil {
                        GlassMetric(value: "\(session.items.count)", label: "Exercises", height: 86)
                    }
                    GlassMetric(value: loadWord, label: "Load", height: 70, accent: readinessBand == nil ? nil : phase.red)
                    if let tag = focusTag, tag != "LIGHTER TODAY" {
                        GlassMetric(value: tag.capitalized, label: "Note", height: 70)
                    }
                }
                .frame(maxWidth: 380)
                .padding(.top, 4)
                if workoutDoneToday {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.green)
                        .padding(.top, 4)
                    Text("You're done for today.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Button { liveLaunch = LiveSessionLaunch(planned: session, kind: workoutKind(workout.mode)) } label: {
                        HeroCTALabel("Start training")
                    }
                    .buttonStyle(.primary)
                    .padding(.top, 8)
                    .frame(maxWidth: 300)
                }
            } else if practiceToday, status == .active {
                HomeEyebrow("Today's session")
                heroTitle("Team practice")
                if let start = practiceStart {
                    bigNumber(start.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()),
                              unit: start.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).filter(\.isLetter).uppercased())
                } else {
                    heroMeta("Your sport's training")
                }
            } else {
                HomeEyebrow("Today")
                heroTitle("Rest day")
                Text("Recovery is part of the plan.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var loadWord: String {
        if readinessBand != nil { return "Lighter" }
        if status != .active { return "Optional" }
        return "Normal"
    }

    private func heroTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 42, weight: .bold))
            .tracking(-0.6)
            .foregroundStyle(AppTheme.ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .background(HeroBloom(color: phase.red))
    }

    /// The big number: 60–82 pt, its unit small beside it.
    private func bigNumber(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 76, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.ink)
                .contentTransition(.numericText())
            if !unit.isEmpty {
                Text(unit)
                    .font(.title3.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func heroMeta(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.center)
    }

    /// The workout's focus in words: its main quality ("Rotational power").
    private func focusTitle(_ session: GeneratedSession, mode: WorkoutMode) -> String {
        if session.decision != nil { return session.title }
        return session.focusQualities.first.flatMap { qualitiesBySlug[$0]?.name } ?? mode.title
    }

    private func qualityLine(_ session: GeneratedSession) -> String? {
        if let decision = session.decision {
            let line = decision.primaryTargets.prefix(3).map(\.title).joined(separator: " · ")
            return line.isEmpty ? nil : line.prefix(1).uppercased() + line.dropFirst()
        }
        var seen: Set<String> = []
        let names = session.focusQualities.compactMap { qualitiesBySlug[$0]?.shortName }.filter { seen.insert($0).inserted }
        return names.count > 1 ? names.prefix(3).joined(separator: " · ") : nil
    }

    private var focusTag: String? {
        if readinessBand != nil { return "LIGHTER TODAY" }
        if examWeek { return "EXAM WEEK" }
        if status != .active { return "OPTIONAL" }
        return nil
    }

    private func gameTitle(_ game: Competition) -> String {
        game.kind == .tournament ? "Tournament" : (game.kind == .meet ? "Meet" : "Game")
    }

    // Supporting activities: compact, readable, not centred.

    @ViewBuilder
    private func supportingList(title: String?) -> some View {
        let rows = supportingRows
        if !rows.isEmpty {
            VStack(spacing: 6) {
                if let title { HomeEyebrow(title) }
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        rows[index]
                        if index < rows.count - 1 { Divider().opacity(0.5) }
                    }
                }
            }
        }
    }

    private var supportingRows: [AnyView] {
        var rows: [AnyView] = []
        if practiceToday, status == .active, gameToday == nil, todaysWorkout != nil {
            rows.append(AnyView(Button { activeSheet = .schedule } label: {
                HomeDetailRow(systemImage: "person.3.fill", color: AppTheme.orange, title: "Practice") {
                    if let start = practiceStart { Text(start.formatted(date: .omitted, time: .shortened)) }
                }
            }.buttonStyle(.plain)))
        }
        if isTrainingDay {
            for assignment in CoachAssignments.today() {
                rows.append(AnyView(HomeDetailRow(systemImage: "megaphone.fill", color: AppTheme.brand, title: assignment.title) {
                    startButton { liveLaunch = LiveSessionLaunch(planned: CoachAssignments.session(assignment, catalogue: catalogue), kind: .coach) }
                }))
            }
        }
        // V6 §20: learn, then reflect — then the supporting work.
        if let next = nextLesson {
            rows.append(AnyView(Button { selectedTab = .campus } label: {
                HomeDetailRow(systemImage: "graduationcap.fill", color: AppTheme.purple, title: next.lesson.title) {
                    if learnedToday { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.green) } else { Text("\(next.lesson.minutes) min") }
                }
            }.buttonStyle(.plain)))
        }
        rows.append(AnyView(Button { activeSheet = .reflection } label: {
            HomeDetailRow(systemImage: "moon.stars.fill", color: AppTheme.purple, title: "Reflection") {
                if reflectedToday { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.green) } else { Text("Tonight · 45 sec") }
            }
        }.buttonStyle(.plain)))
        if let movementPrep {
            rows.append(AnyView(Button { preview = PreviewBox(session: movementPrep, kind: .mobility) } label: {
                HomeDetailRow(systemImage: "figure.flexibility", color: AppTheme.cyan, title: movementPrep.title) {
                    if mobilityDoneToday { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.green) } else { Text("\(movementPrep.estimatedMinutes) min") }
                }
            }.buttonStyle(.plain)))
        }
        return rows
    }

    /// The short reason stays one tap away; the plan speaks for itself.
    @ViewBuilder
    private var whySection: some View {
        if todaysWorkout != nil || readinessBand != nil || gameToday != nil {
            VStack(spacing: 8) {
                Button { withAnimation { showingWhy.toggle() } } label: {
                    HStack(spacing: 6) {
                        Text("Why this plan?")
                        Image(systemName: showingWhy ? "chevron.up" : "chevron.down").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                if showingWhy {
                    Text(whyThisPlan)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
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
            }
            .frame(maxWidth: .infinity)
        }
    }

    // Evening: what happened today, and what did I learn?

    private var todayCompleteHero: some View {
        let progress = dayProgress
        return VStack(spacing: 14) {
            DailyPerformanceTrack(progress: progress, evening: phase == .evening || phase == .night) { open($0) }
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
    }

    /// A tap on a part of the day finishes or opens it.
    private func open(_ part: DayProgress.Part) {
        switch part {
        case .practice: searchDestination = SearchBox(target: .practiceLog)
        case .rest: activeSheet = .today
        case .reflection: activeSheet = .reflection
        case .mobility:
            if let movementPrep { preview = PreviewBox(session: movementPrep, kind: .mobility) }
        case .workout:
            if workoutDoneToday { activeSheet = .history } else if let workout = todaysWorkout {
                preview = PreviewBox(session: workout.session, kind: workoutKind(workout.mode))
            }
        }
    }

    private var reflectionHero: some View {
        VStack(spacing: 12) {
            HomeEyebrow("Evening reflection")
            Text("How did today actually feel?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("45")
                    .font(.system(size: 60, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                Text("SEC")
                    .font(.headline)
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Button { activeSheet = .reflection } label: { HeroCTALabel("Reflect") }
                .buttonStyle(.primary)
                .padding(.top, 6)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
    }

    /// After the reflection: a poster, not a dashboard. Done, one note,
    /// tomorrow, sleep.
    private var dayCompleteView: some View {
        VStack(spacing: 44) {
            VStack(spacing: 14) {
                Text("Day complete")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .background(HeroBloom(color: phase.red))
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(phase.red)
                    .frame(width: 60, height: 60)
                    .glassCapsule()
                    .overlay { Circle().strokeBorder(phase.red.opacity(0.55), lineWidth: 1) }
                    .shadow(color: phase.red.opacity(0.4), radius: 14)
                    .accessibilityHidden(true)
                let rows = doneRows
                if !rows.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(rows, id: \.title) { row in
                            GlassMetric(value: row.value.replacingOccurrences(of: " min", with: ""), label: row.title,
                                        height: 70, accent: row.color)
                        }
                    }
                    .frame(maxWidth: 400)
                    .padding(.top, 8)
                }
            }
            if let note = todaysNote {
                VStack(spacing: 8) {
                    HomeEyebrow("Today's note")
                    Text(note)
                        .font(.title3)
                        .foregroundStyle(AppTheme.ink.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }
            }
            if let tomorrow = tomorrowLine {
                VStack(spacing: 6) {
                    HomeEyebrow("Tomorrow")
                    Text(tomorrow.title.uppercased())
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                    if let detail = tomorrow.detail {
                        Text(detail.uppercased())
                            .font(.footnote.weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            VStack(spacing: 14) {
                Text(firstName.map { "Sleep well, \($0)." } ?? "Sleep well.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                if let bedtime = bedtimeTonight {
                    Text("Bed by \(Bedtime.label(bedtime.minutes))")
                        .font(.caption.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Button { activeSheet = .windDown } label: { HeroCTALabel("Wind down") }
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// After midnight without a finished day: nothing to do but sleep.
    private var nightView: some View {
        VStack(spacing: 12) {
            HomeEyebrow("It's late")
            Text("Sleep is training too.")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
            Text("Everything else can wait until morning.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Button { activeSheet = .windDown } label: { Label("Wind down", systemImage: "wind") }
                .buttonStyle(.secondary)
                .frame(maxWidth: 260)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private struct DoneRow {
        let icon: String
        let color: Color
        let title: String
        let value: String
    }

    private var doneRows: [DoneRow] {
        var rows: [DoneRow] = []
        if let log = practiceLogToday {
            rows.append(DoneRow(icon: "person.3.fill", color: AppTheme.orange, title: "Practice", value: log.minutes.map { "\($0) min" } ?? "Logged"))
        }
        let workoutMinutes = todaysSessions.filter { SessionKinds.kind(of: $0.clientId) != .mobility }.reduce(0) { $0 + $1.minutes }
        if workoutDoneToday { rows.append(DoneRow(icon: "dumbbell.fill", color: AppTheme.red, title: "Workout", value: "\(workoutMinutes) min")) }
        let mobilityMinutes = todaysSessions.filter { SessionKinds.kind(of: $0.clientId) == .mobility }.reduce(0) { $0 + $1.minutes }
        if mobilityDoneToday { rows.append(DoneRow(icon: "figure.flexibility", color: AppTheme.water, title: "Mobility", value: "\(mobilityMinutes) min")) }
        if learnedToday { rows.append(DoneRow(icon: "graduationcap.fill", color: AppTheme.purple, title: "Campus", value: "Lesson done")) }
        return rows
    }

    /// One sentence from tonight's reflection — what tomorrow's plan takes from it.
    private var todaysNote: String? {
        _ = revision
        guard let reflection = MindsetStore.reflection(on: .now) else { return nil }
        if (reflection.body ?? 0) >= 4 { return "Something hurt today. Tell a coach or parent, and add it in tomorrow's check-in." }
        if (reflection.hardness ?? 0) >= 3 || (reflection.body ?? 0) >= 3 {
            return "Today felt harder than usual. Tomorrow's plan will account for it."
        }
        if let practice = reflection.practice, practice >= 3 { return "A good practice. Tomorrow builds on it." }
        return "A steady day. Tomorrow builds on it."
    }

    /// Tomorrow's first thing: a game, practice, a gym day or rest.
    private var tomorrowLine: (title: String, detail: String?)? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: clock) else { return nil }
        if let game = athlete.competitions.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrow) }) {
            return (gameTitle(game), game.date.formatted(date: .omitted, time: .shortened))
        }
        if PracticeSchedule.hasPractice(on: tomorrow) {
            return ("Team practice", PracticeSchedule.time(on: tomorrow).map(\.label))
        }
        if let gym = week?.sessions.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrow) }) {
            return ("Gym day", "\(gym.estimatedMinutes) min")
        }
        return ("Rest day", "Recovery is part of the plan.")
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

    // MARK: - Widgets (Edit Home)

    /// The widgets the athlete added, and Edit Home.
    @ViewBuilder
    private var widgetsSection: some View {
        if !layout.widgets.isEmpty {
            // One container for every widget, so while arranging they glide
            // to their new places instead of jumping.
            WidgetGridLayout {
                ForEach(layout.widgets) { widget in
                    editableWidget(widget)
                }
            }
            #if os(iOS)
            // Letting go anywhere on the board keeps the order it shows.
            .contentShape(Rectangle())
            .onDrop(of: [.text], delegate: HomeWidgetDropDelegate(target: nil, drag: $drag, layout: $layout))
            #endif
        }
        layoutControls
    }

    /// While arranging: hold a widget and drag it — the others make room as
    /// it passes over them, so the new order shows before letting go. Tap –
    /// to remove it.
    @ViewBuilder
    private func editableWidget(_ widget: HomeWidget) -> some View {
        if editingLayout {
            let held = drag.widget == widget
            widgetContent(widget)
                .allowsHitTesting(false)
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
                .rotationEffect(.degrees(wiggle ? 0.8 : -0.8))
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
                        withAnimation { layout.remove(widget); layout.save() }
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.red, in: Circle())
                            .overlay(Circle().stroke(AppTheme.background, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .offset(x: -8, y: -8)
                    .accessibilityLabel("Remove \(widget.title)")
                }
                .padding(.top, 8)
        } else {
            widgetContent(widget)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var layoutControls: some View {
        if editingLayout {
            VStack(alignment: .leading, spacing: 12) {
                if !layout.widgets.isEmpty {
                    Text("Hold a widget and drag it to move it. Tap – to remove it.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                if !layout.available.isEmpty {
                    SectionHeader("Add widgets")
                    VStack(spacing: 0) {
                        ForEach(layout.available) { widget in
                            Button {
                                withAnimation { layout.add(widget); layout.save() }
                            } label: {
                                ListRow(systemImage: widget.systemImage, color: AppTheme.ink, title: widget.title, detail: widget.detail) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.green)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(widget.title)")
                            if widget != layout.available.last {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .cardStyle(padding: 12)
                }
                Button {
                    editingLayout = false
                    wiggle = false
                    drag = HomeDragState()
                    layout.save()
                } label: {
                    Label("Save Home", systemImage: "checkmark")
                }
                .buttonStyle(.primary)
            }
            .padding(.top, 4)
        } else {
            Button {
                editingLayout = true
                wiggle = true
            } label: {
                Label("Edit Home", systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var loggedThisWeek: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return allSessions.filter { interval.contains($0.startedAt) }.count
    }

    private var mindsetProgress: (done: Int, target: Int) {
        _ = revision
        return MindsetStore.weekProgress()
    }

    private var testStatus: BenchmarkSchedule.Status {
        _ = revision
        return BenchmarkSchedule.status(lastTest: BenchmarkStore.lastTestDate())
    }

    private func nextGameCaption(_ game: Competition) -> String {
        let hasTime = calendar.component(.hour, from: game.date) != 0 || calendar.component(.minute, from: game.date) != 0
        let when = hasTime ? game.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()) : game.date.formatted(.dateTime.weekday(.abbreviated).month().day())
        return "\(game.isHome ? "Home" : "Away") · \(when)"
    }

    private var testsValue: (value: String, due: Bool) {
        switch testStatus {
        case .firstTime: ("First tests", true)
        case .notYet(let days): ("In \(days) days", false)
        case .due: ("Test week", true)
        case .overdue: ("Overdue", true)
        }
    }

    /// The square widgets: one number, what it means, one tap to act on it.
    @ViewBuilder
    private func widgetContent(_ widget: HomeWidget) -> some View {
        switch widget {
        case .body:
            let planned = max(week?.sessions.count ?? 0, 1) + practiceDays.count
            let gain = BenchmarkMath.headline(BenchmarkStore.results, tests: BenchmarkCatalog.body)
            Button { selectedTab = .progress } label: {
                WidgetTile(value: "\(loggedThisWeek) of \(planned)", label: "Body", progress: Double(loggedThisWeek) / Double(planned),
                           color: AppTheme.accent, systemImage: widget.systemImage, caption: gain ?? "Workouts this week")
            }
            .buttonStyle(.plain)
        case .sport:
            let skillPlans = athlete.skillBlocks.filter { $0.targetDate >= calendar.startOfDay(for: .now) }.count
            let gain = athlete.activeSport.flatMap { BenchmarkMath.headline(BenchmarkStore.results, tests: [BenchmarkCatalog.sportTest(for: $0.sportSlug)]) }
            Button { selectedTab = .workout } label: {
                WidgetTile(value: skillPlans == 0 ? "No plan" : "\(skillPlans) active", label: "Sport",
                           progress: skillPlans == 0 ? 0 : 1, color: AppTheme.brand, systemImage: widget.systemImage,
                           caption: gain ?? (skillPlans == 0 ? "Skill plans in Workout" : "Skill plans in progress"))
            }
            .buttonStyle(.plain)
        case .knowledge:
            let learned = CampusProgress.learned(campusLearnedRaw)
            let total = campusTopics.reduce(0) { $0 + $1.lessons.count }
            Button { selectedTab = .campus } label: {
                WidgetTile(value: "\(learned.count) of \(total)", label: "Knowledge", progress: Double(learned.count) / Double(max(1, total)),
                           color: AppTheme.green, systemImage: widget.systemImage, caption: "Campus lessons")
            }
            .buttonStyle(.plain)
        case .mindset:
            let progress = mindsetProgress
            Button { activeSheet = .mindset } label: {
                WidgetTile(value: "\(progress.done) of \(progress.target)", label: "Mindset", progress: Double(progress.done) / Double(max(1, progress.target)),
                           color: AppTheme.purple, systemImage: widget.systemImage, caption: "This week")
            }
            .buttonStyle(.plain)
        case .nextGame:
            let nextGame = AthleteStats.upcomingCompetitions(athlete).first
            let days = nextGame.map { AthleteStats.daysUntil($0.date) }
            Button { if nextGame == nil { activeSheet = .addGame } else { selectedTab = .progress } } label: {
                WidgetTile(value: days.map { $0 == 0 ? "Today" : ($0 == 1 ? "Tomorrow" : "In \($0) days") } ?? "None yet",
                           label: "Next game", progress: days.map { max(0.05, 1 - Double($0) / 14) } ?? 0,
                           color: ProgressColors.game, systemImage: widget.systemImage,
                           caption: nextGame.map { nextGameCaption($0) } ?? "Tap to add one")
            }
            .buttonStyle(.plain)
        case .food:
            Button { activeSheet = .fuel } label: {
                WidgetTile(value: gameToday != nil ? "Game day" : (todaysWorkout != nil ? "Training day" : "Rest day"),
                           label: "Food & water", progress: 0.5, color: AppTheme.green, systemImage: widget.systemImage,
                           caption: "What to eat today")
            }
            .buttonStyle(.plain)
        case .streak:
            Button { selectedTab = .progress } label: {
                WidgetTile(value: "\(streak) \(streak == 1 ? "day" : "days")", label: "Streak", progress: min(1, Double(streak) / 7),
                           color: AppTheme.orange, systemImage: widget.systemImage, caption: "Checked in or trained")
            }
            .buttonStyle(.plain)
        case .tests:
            let tests = testsValue
            let headline = BenchmarkMath.headline(BenchmarkStore.results, tests: BenchmarkCatalog.tests(for: athlete.activeSport?.sportSlug))
            Button { activeSheet = .tests } label: {
                WidgetTile(value: tests.value, label: "Tests", progress: tests.due ? 1 : 0.3, color: AppTheme.coral,
                           systemImage: widget.systemImage, caption: headline ?? "Every 6–8 weeks")
            }
            .buttonStyle(.plain)
        }
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
                     onClose: { dismiss() }, onConfirm: { onSave(choice, choice == .active ? nil : days) }) {
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
                     onClose: { dismiss() }, onConfirm: { onSave(selection) }) {
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
                    if let explanation = session.explanation {
                        PlanHero(session: session, explanation: explanation)
                        BlockedSessionList(session: session, catalogue: catalogue) { detailItem = $0 }
                        WhyThisPlanPanel(explanation: explanation)
                    } else {
                        Text("Do them in this order. Tap one to watch how it's done.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        ForEach(Array(session.items.enumerated()), id: \.element.order) { index, item in
                            row(item, number: index + 1)
                        }
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
                CloseToolbarItem { dismiss() }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item, closes: true) }
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

// MARK: - Arranging the widgets

/// Home's widgets: two to a row, in the athlete's order. One layout for all
/// of them, so while arranging they glide to their new places.
struct WidgetGridLayout: Layout {
    var columnSpacing: CGFloat = 12
    var rowSpacing: CGFloat = 12

    private func columnWidth(_ total: CGFloat) -> CGFloat { (total - columnSpacing) / 2 }

    private func rowHeights(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: 2).map { start in
            (start..<min(start + 2, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }.max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 360
        let heights = rowHeights(subviews, width: columnWidth(total))
        return CGSize(width: total, height: heights.reduce(0, +) + rowSpacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = columnWidth(bounds.width)
        let heights = rowHeights(subviews, width: width)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<2 {
                let index = row * 2 + column
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(column) * (width + columnSpacing)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
            }
            y += height + rowSpacing
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
/// holding. A short pause between moves keeps widgets from trading places
/// back and forth under the finger. `target` nil is the board itself, which
/// only ends the drag.
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


/// A one-way message from the coach, until the athlete closes it.
struct AnnouncementCard: View {
    let announcement: APIClient.Announcement
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("From your coach\(announcement.teamName.map { " · \($0)" } ?? "")")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close the announcement")
            }
            Text(announcement.text)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }
}

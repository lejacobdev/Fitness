import SwiftData
import SwiftUI

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

    enum HomeSheet: String, Identifiable {
        case quickActions, checkIn, addGame, history, fuel, dayStatus, schedule
        var id: String { rawValue }
    }

    private var calendar: Calendar { .current }
    private var todaysCheckIn: CheckIn? { AthleteStats.todaysCheckIn(athlete) }
    private var sportInfo: SportInfo? { athlete.activeSport.flatMap { allSportsBySlug[$0.sportSlug] } }
    private var gameToday: Competition? { athlete.competitions.first { calendar.isDateInToday($0.date) } }
    private var practiceToday: Bool { practiceDays.contains(calendar.component(.weekday, from: .now)) }
    private var loggedToday: Bool { allSessions.contains { calendar.isDateInToday($0.startedAt) } }

    private var modeContext: WorkoutModeContext {
        WorkoutModeContext(
            catalogue: catalogue, sport: sportInfo, positionSlug: athlete.activeSport?.positionSlug,
            formatSlug: athlete.activeSport?.formatSlug, equipment: Set(athlete.equipmentAvailable),
            trainsUnderCoach: athlete.trainsUnderCoach, age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now)
        )
    }

    /// Today's workout and why: the heart of Home.
    private var todaysWorkout: (mode: WorkoutMode, session: GeneratedSession)? {
        switch status {
        case .sick: return nil
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
        status == .sick ? nil : WorkoutModeBuilder.build(.mobility, modeContext)
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
                        QuoteCard(quote: DailyQuotes.quote())
                        checkInCard
                        if !scheduleIsSet { scheduleCard }
                        todayCard
                        if let mobility { mobilityCard(mobility) }
                        levels
                        upcoming
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
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
                status = DayStatusStore.status()
                loaded = true
            }
            .sheet(item: $activeSheet, onDismiss: runPendingAction) { sheet in
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
                case .schedule:
                    PracticeDaysSheet(selection: practiceDays) { days in
                        PracticeSchedule.weekdays = days
                        practiceDays = days
                        scheduleIsSet = true
                        activeSheet = nil
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
                    liveLaunch = LiveSessionLaunch(planned: box.session)
                }
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
            Text("Tell us once. On practice days you get a short workout for after practice; on the other days, a full gym session.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button { activeSheet = .schedule } label: { Label("Set my practice days", systemImage: "calendar") }
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
        } else if status == .sick {
            infoCard(icon: "bed.double.fill", color: AppTheme.purple, title: "Rest and recover",
                     text: "No training while you're sick. Drink plenty, eat normally and sleep. When you feel better, ease back in with a lighter day. See a doctor if it's getting worse.")
        } else if let game = gameToday, status == .active {
            infoCard(icon: "sportscourt.fill", color: AppTheme.brand,
                     title: game.kind == .tournament ? "Tournament day" : (game.kind == .meet ? "Meet day" : "Game day"),
                     text: "No workout today — save your energy. Eat a proper meal about 3 hours before, a snack an hour before, warm up well, and play.")
        } else if let workout = todaysWorkout {
            workoutCard(workout.mode, workout.session)
        } else {
            infoCard(icon: "moon.zzz.fill", color: AppTheme.purple, title: "Rest day",
                     text: "No workout today. Rest is when your body gets stronger from training — sleep well tonight.",
                     action: ("Log a workout anyway", { liveLaunch = LiveSessionLaunch(planned: nil) }))
        }
    }

    private func workoutCard(_ mode: WorkoutMode, _ session: GeneratedSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(status == .active ? "TODAY" : "OPTIONAL TODAY")
                    .font(.caption.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                if loggedToday { Tag("Done", color: AppTheme.green) }
            }
            Text(mode.title)
                .font(.title.bold())
                .foregroundStyle(AppTheme.ink)
            Text(mode.explanation)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Label("About \(session.estimatedMinutes) min", systemImage: "clock")
                Label("\(session.items.count) exercises", systemImage: "list.bullet")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            if readinessResult != nil || (readinessOverridden && todaysCheckIn?.readinessBand != nil) {
                Button(readinessOverridden ? "Use the lighter version from my check-in" : "Lighter because of your check-in — I feel fine, give me the full one") {
                    readinessOverridden.toggle()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
            thumbnails(session)
            if mode == .afterPractice || mode == .gymDay {
                Button { activeSheet = .schedule } label: {
                    Label("Practice days: \(practiceDayNames)", systemImage: "calendar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            Button { liveLaunch = LiveSessionLaunch(planned: session) } label: {
                Label(loggedToday ? "Do it again" : "Start", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    private var practiceDayNames: String {
        guard !practiceDays.isEmpty else { return "none" }
        let symbols = calendar.shortWeekdaySymbols
        return practiceDays.sorted().map { symbols[($0 - 1) % 7] }.joined(separator: ", ")
    }

    private func mobilityCard(_ session: GeneratedSession) -> some View {
        Button { preview = PreviewBox(session: session) } label: {
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
    private var levels: some View {
        let learned = CampusProgress.learned(campusLearnedRaw)
        let totalLessons = campusTopics.reduce(0) { $0 + $1.lessons.count }
        let mindsetLessons = campusTopics.filter { ["psychology", "teamwork"].contains($0.id) }.flatMap(\.lessons)
        let mindsetDone = mindsetLessons.filter { learned.contains($0.id) }.count
        let planned = max(week?.sessions.count ?? 0, 1) + practiceDays.count
        let skillPlans = athlete.skillBlocks.filter { $0.targetDate >= calendar.startOfDay(for: .now) }.count
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your levels", subtitle: "Four ways you get better. Tap one to work on it.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                Button { selectedTab = .plan } label: {
                    WidgetTile(value: "\(loggedThisWeek) of \(planned)", label: "Body", progress: Double(loggedThisWeek) / Double(planned),
                               color: AppTheme.accent, systemImage: "figure.strengthtraining.traditional", caption: "Workouts done this week")
                }
                .buttonStyle(.plain)
                Button { selectedTab = .improve } label: {
                    WidgetTile(value: skillPlans == 0 ? "Pick a skill" : "\(skillPlans) active", label: "Sport",
                               progress: skillPlans == 0 ? 0 : 1, color: AppTheme.blue, systemImage: "sportscourt.fill",
                               caption: skillPlans == 0 ? "A plan for one skill of your sport" : "Skill plans in progress")
                }
                .buttonStyle(.plain)
                Button { selectedTab = .campus } label: {
                    WidgetTile(value: "\(learned.count) of \(totalLessons)", label: "Knowledge", progress: Double(learned.count) / Double(max(1, totalLessons)),
                               color: AppTheme.green, systemImage: "graduationcap.fill", caption: "Campus lessons learned")
                }
                .buttonStyle(.plain)
                Button { selectedTab = .campus } label: {
                    WidgetTile(value: "\(mindsetDone) of \(mindsetLessons.count)", label: "Mindset", progress: Double(mindsetDone) / Double(max(1, mindsetLessons.count)),
                               color: AppTheme.purple, systemImage: "brain.head.profile", caption: "Confidence, focus, teamwork")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Coming up

    private var upcoming: some View {
        let nextGame = AthleteStats.upcomingCompetitions(athlete).first
        let daysToGame = nextGame.map { AthleteStats.daysUntil($0.date) }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Coming up")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                Button { if nextGame == nil { activeSheet = .addGame } else { selectedTab = .plan } } label: {
                    WidgetTile(value: daysToGame.map { $0 == 0 ? "Today" : ($0 == 1 ? "Tomorrow" : "In \($0) days") } ?? "None yet",
                               label: "Next game", progress: daysToGame.map { max(0.05, 1 - Double($0) / 14) } ?? 0,
                               color: AppTheme.brand, systemImage: "sportscourt.fill",
                               caption: nextGame == nil ? "Tap to add one — training eases off before it" : "Training eases off before it")
                }
                .buttonStyle(.plain)
                Button { activeSheet = .fuel } label: {
                    WidgetTile(value: gameToday != nil ? "Game day" : (todaysWorkout != nil ? "Training day" : "Rest day"),
                               label: "Food & water", progress: 0.5, color: AppTheme.green, systemImage: "fork.knife",
                               caption: "What to eat and drink today")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// `GeneratedSession` isn't Identifiable; this wraps one for `.sheet(item:)`.
private struct PreviewBox: Identifiable {
    let id = UUID()
    let session: GeneratedSession
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
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: { onSave(choice, choice == .active ? nil : days) }) {
            VStack(spacing: 10) {
                ForEach(DayStatus.allCases) { status in
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

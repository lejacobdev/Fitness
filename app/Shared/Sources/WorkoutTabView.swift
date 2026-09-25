import SwiftData
import SwiftUI

/// The Workout section: the three kinds of workout — after practice, a gym
/// day, stretching and mobility — each built for the athlete's sport,
/// schedule and struggles, plus this week's gym plan and the other ways to
/// train (a skill, a muscle group).
struct WorkoutTabView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let week: GeneratedWeek?
    let onPlanInputsChanged: () -> Void

    @State private var catalogue = Catalogue()
    @State private var status: DayStatus = DayStatusStore.status()
    @State private var liveLaunch: LiveSessionLaunch?
    @State private var preview: PreviewBox?
    @State private var detailItem: CatalogueItem?
    @State private var showingImprove = false
    @State private var confirmingNewPlan = false
    @State private var readinessOverridden = false
    @AppStorage(PlanVariant.key) private var planVariant = 0

    private var calendar: Calendar { .current }
    private var sportInfo: SportInfo? { athlete.activeSport.flatMap { allSportsBySlug[$0.sportSlug] } }
    private var gameToday: Competition? { athlete.competitions.first { calendar.isDateInToday($0.date) } }
    private var practiceToday: Bool { PracticeSchedule.hasPractice(on: .now) }
    private var band: ReadinessBand? { readinessOverridden ? nil : AthleteStats.todaysCheckIn(athlete)?.readinessBand }

    private var context: WorkoutModeContext {
        WorkoutModeContext(
            catalogue: catalogue, sport: sportInfo, positionSlug: athlete.activeSport?.positionSlug,
            formatSlug: athlete.activeSport?.formatSlug, equipment: Set(athlete.equipmentAvailable),
            trainsUnderCoach: athlete.trainsUnderCoach, age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now),
            struggles: Struggles.selected
        )
    }

    private func adjusted(_ session: GeneratedSession) -> GeneratedSession {
        guard let band else { return session }
        return ReadinessApplier.apply(to: session, band: band).session
    }

    /// Today's gym session, or the next one this week.
    private var gymSession: (session: GeneratedSession, isToday: Bool)? {
        let sessions = week?.sessions ?? []
        if let today = sessions.first(where: { calendar.isDateInToday($0.date) }) { return (adjusted(today), true) }
        let start = calendar.startOfDay(for: .now)
        if let next = sessions.first(where: { $0.date > start }) ?? sessions.first { return (adjusted(next), false) }
        return nil
    }

    /// What to do today, and why.
    private var recommendation: (mode: WorkoutMode?, reason: String) {
        switch status {
        case .sick: return (nil, "You're marked as sick — rest today. Everything is here when you're back.")
        case .concussion: return (nil, "Head knock: no training until a doctor clears you.")
        case .travel, .holiday: return (.travel, "\(status.title): a short workout you can do anywhere, if you feel like it.")
        case .active:
            if gameToday != nil { return (.mobility, "Game day: no workout — just loosen up with mobility.") }
            if practiceToday {
                let time = PracticeSchedule.time(on: .now).map { " (\($0.label))" } ?? ""
                return (.afterPractice, "You have team practice today\(time), so a short workout afterwards.")
            }
            if gymSession?.isToday == true { return (.gymDay, "No team practice today: your full gym session.") }
            return (.mobility, "A rest day in your plan — 10 minutes of mobility keeps you moving well.")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Workout", subtitle: "Three kinds of workout, each built for your sport, your schedule and what you want to fix. Pick one and press Start.")
                    recommendationCard
                    if band != nil || readinessOverridden {
                        Button(readinessOverridden ? "Use the lighter versions from my check-in" : "Lighter because of your check-in — I feel fine, give me the full ones") {
                            readinessOverridden.toggle()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    }
                    modeCard(.afterPractice, session: WorkoutModeBuilder.build(.afterPractice, context).map { adjusted($0) },
                             note: practiceToday ? "You have practice today." : "Use it on days with team practice.")
                    gymCard
                    modeCard(.mobility, session: WorkoutModeBuilder.build(.mobility, context), note: "Good every day — even game days.")
                    modeCard(.travel, session: WorkoutModeBuilder.build(.travel, context), note: "No equipment: hotel room, bus stop, holiday.")
                    personalization
                    weekSection
                    moreSection
                    planOptions
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.bottom, 20)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                status = DayStatusStore.status()
            }
            .sheet(item: $preview) { box in
                SessionPreviewSheet(session: box.session, catalogue: catalogue) {
                    preview = nil
                    liveLaunch = LiveSessionLaunch(planned: box.session, kind: box.kind)
                }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
            .sheet(isPresented: $showingImprove) {
                ImproveView(athlete: athlete, apiClient: apiClient, onPlanInputsChanged: onPlanInputsChanged)
            }
            .fullScreenCover(item: $liveLaunch) { launch in
                LiveSessionView(athlete: athlete, apiClient: apiClient, planned: launch.planned, kind: launch.kind)
            }
            .confirmationDialog("Delete this plan?", isPresented: $confirmingNewPlan, titleVisibility: .visible) {
                Button("Delete and build a new one", role: .destructive) {
                    PlanVariant.buildNew()
                    onPlanInputsChanged()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your gym days get new exercises. Workouts you already logged stay.")
            }
        }
    }

    // MARK: - Today

    private var recommendationCard: some View {
        let rec = recommendation
        return VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.caption.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(AppTheme.brand)
            Text(rec.mode.map { "We recommend: \($0.title)" } ?? "Rest today")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Text(rec.reason)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 18)
    }

    private func kind(_ mode: WorkoutMode) -> WorkoutKind {
        switch mode {
        case .afterPractice: .afterPractice
        case .gymDay: .gym
        case .mobility: .mobility
        case .travel: .travel
        }
    }

    private func color(_ mode: WorkoutMode) -> Color {
        switch mode {
        case .afterPractice: ProgressColors.afterPractice
        case .gymDay: ProgressColors.workout
        case .mobility: ProgressColors.mobility
        case .travel: AppTheme.purple
        }
    }

    private func modeCard(_ mode: WorkoutMode, session: GeneratedSession?, note: String, titleOverride: String? = nil) -> some View {
        let recommended = recommendation.mode == mode
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(color(mode)).frame(width: 14, height: 14)
                Text(titleOverride ?? mode.title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if recommended { Tag("For today", color: AppTheme.brand) }
            }
            Text(mode.explanation)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let session {
                HStack(spacing: 16) {
                    Label("About \(session.estimatedMinutes) min", systemImage: "clock")
                    Label("\(session.items.count) exercises", systemImage: "list.bullet")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                thumbnails(session)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                ButtonRow {
                    Button { preview = PreviewBox(session: session, kind: kind(mode)) } label: {
                        Label("See it", systemImage: "list.bullet")
                    }
                        .buttonStyle(.secondary)
                    Button { liveLaunch = LiveSessionLaunch(planned: session, kind: kind(mode)) } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.primary)
                }
            } else {
                Text(catalogue.itemsBySlug.isEmpty ? "Loading your exercise library…" : "Nothing fits your equipment yet — add some in Me → Equipment.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .cardStyle(padding: 18)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            .strokeBorder(recommended ? AppTheme.accent : Color.clear, lineWidth: 2))
    }

    @ViewBuilder
    private var gymCard: some View {
        if let gym = gymSession {
            modeCard(.gymDay, session: gym.session,
                     note: gym.isToday ? "Planned for today." : "Planned for \(gym.session.date.formatted(.dateTime.weekday(.wide))) — you can do it now.",
                     titleOverride: "Gym day: \(gym.session.title)")
        } else {
            modeCard(.gymDay, session: nil, note: "")
        }
    }

    private func thumbnails(_ session: GeneratedSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(session.items, id: \.order) { item in
                    let catalogueItem = catalogue.item(item.itemSlug)
                    Button { detailItem = catalogueItem } label: { ItemThumbnail(item: catalogueItem, size: 56) }
                        .buttonStyle(.plain)
                        .disabled(catalogueItem == nil)
                        .accessibilityLabel(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                }
            }
        }
    }

    // MARK: - Personal, week, more

    private var personalization: some View {
        let struggles = Struggles.selected
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title2)
                .foregroundStyle(AppTheme.ink)
            Text(struggles.isEmpty
                 ? "Tell us what you want to fix — speed, strength, stamina… — in Me → What you want to fix, and your workouts lean towards it."
                 : "Built around what you want to fix: \(struggles.map { $0.title.lowercased() }.joined(separator: ", ")). Change it in Me.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    @ViewBuilder
    private var weekSection: some View {
        if let week, !week.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Your gym days this week", subtitle: "Placed on days without team practice or games. Tap one to see it.")
                VStack(spacing: 0) {
                    ForEach(Array(week.sessions.enumerated()), id: \.offset) { index, session in
                        Button { preview = PreviewBox(session: adjusted(session), kind: .gym) } label: {
                            HStack(spacing: 12) {
                                Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.headline)
                                    .foregroundStyle(calendar.isDateInToday(session.date) ? AppTheme.onAccent : AppTheme.ink)
                                    .frame(width: 52, height: 40)
                                    .background(calendar.isDateInToday(session.date) ? AppTheme.accent : AppTheme.fill, in: Capsule())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title).font(.headline).foregroundStyle(AppTheme.ink)
                                    Text("About \(session.estimatedMinutes) min · \(session.items.count) exercises")
                                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if index < week.sessions.count - 1 { Divider().overlay(AppTheme.hairline) }
                    }
                }
                .cardStyle(padding: 14)
            }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("More ways to train", subtitle: "Go after one skill before a game, or train the muscles you choose.")
            Button { showingImprove = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "target")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Skill plans & muscle workouts").font(.headline).foregroundStyle(AppTheme.ink)
                        Text("\"I want to get better at…\" or pick body parts").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
                }
                .cardStyle(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var planOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Don't like your gym plan?", subtitle: "Delete it and get a new one: same rules for your sport and season, different exercises.")
            Button { confirmingNewPlan = true } label: {
                Label("Delete plan and build a new one", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(AppTheme.red)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.red.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            if planVariant > 0 {
                Button {
                    PlanVariant.backToOriginal()
                    onPlanInputsChanged()
                } label: {
                    Label("Back to my first plan", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(AppTheme.fill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

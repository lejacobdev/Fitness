import SwiftData
import SwiftUI

/// §15's five-tab navigation, for real. Improve (§8/M9) and a Coach headline
/// (§12/M10) aren't built yet — Improve shows an honest, on-brand "not yet"
/// state rather than either faking content or being missing entirely, since
/// a tab bar with a tab that goes nowhere looks broken in a different way.
@MainActor
public struct MainTabView: View {
    let athlete: Athlete
    let apiClient: APIClient

    @Environment(\.modelContext) private var modelContext
    @State private var week: GeneratedWeek?

    public init(athlete: Athlete, apiClient: APIClient) {
        self.athlete = athlete
        self.apiClient = apiClient
    }

    public var body: some View {
        TabView {
            TodayTabView(athlete: athlete, apiClient: apiClient, week: week)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            PlanTabView(athlete: athlete, week: week, onGameAdded: regenerate)
                .tabItem { Label("Plan", systemImage: "calendar") }

            ImproveTabView()
                .tabItem { Label("Improve", systemImage: "arrow.up.forward.circle.fill") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            MeTabView(athlete: athlete)
                .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
        }
        .tint(AppTheme.accent)
        .toolbarColorScheme(.dark, for: .tabBar)
        .task {
            regenerate()
            // Best-effort, silent (matches the old placeholder screen's own
            // behaviour): a fresh launch with connectivity drains anything
            // logged offline since the last one.
            await SyncQueue(
                apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext
            ).drainPendingSessions()
        }
    }

    private func regenerate() {
        week = WeeklyPlan.generate(for: athlete)
    }
}

/// Shared by the Today and Plan tabs so the two can never disagree about
/// what "this week" is.
enum WeeklyPlan {
    @MainActor
    static func generate(for athlete: Athlete) -> GeneratedWeek? {
        guard
            let athleteSport = athlete.sports.first,
            let sportInfo = allSportsBySlug[athleteSport.sportSlug]
        else { return nil }

        let calendar = Calendar.current
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        ) ?? .now

        let positionProfile = athleteSport.positionSlug.flatMap { slug in
            sportInfo.positions.first { $0.slug == slug }?.qualityProfile
        }

        let input = PlanGeneratorInput(
            sportProfile: sportInfo.qualityProfile, positionProfile: positionProfile,
            seasonStart: athleteSport.seasonStart, seasonEnd: athleteSport.seasonEnd,
            weekStart: weekStart, birthDate: athlete.birthDate,
            trainsUnderCoach: athlete.trainsUnderCoach,
            equipmentAvailable: Set(athlete.equipmentAvailable),
            catalogue: CatalogueLoader.load(from: AppConfig.packsDirectory()),
            seed: "\(athlete.id)-\(Int(weekStart.timeIntervalSince1970))"
        )
        let generated = PlanGenerator.generate(input)
        let competitions = athlete.competitions
            .filter { $0.sportSlug == athleteSport.sportSlug }
            .map(\.date)
        return TaperApplier.apply(to: generated, competitions: competitions, contactLevel: sportInfo.contactLevel)
    }
}

private struct TodayTabView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let week: GeneratedWeek?

    @State private var showingLiveSession = false
    @State private var showingHistory = false

    private var todaysSession: GeneratedSession? {
        let calendar = Calendar.current
        return week?.sessions.first { calendar.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let session = todaysSession {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today's session")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(session.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(session.estimatedMinutes) min · \(session.items.count) items")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    } else {
                        VStack(spacing: 8) {
                            Text("No training session today")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Rest, recovery, or check the Plan tab for the rest of the week.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .cardStyle()
                    }

                    VStack(spacing: 12) {
                        Button("Start training session") { showingLiveSession = true }
                            .buttonStyle(.accentFilled)
                        Button("History") { showingHistory = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .cardStyle()
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Today")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingLiveSession) {
                LiveSessionView(athlete: athlete, apiClient: apiClient)
            }
            .sheet(isPresented: $showingHistory) {
                SessionHistoryView()
            }
        }
    }
}

private struct PlanTabView: View {
    let athlete: Athlete
    let week: GeneratedWeek?
    let onGameAdded: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddGame = false
    @State private var newGameDate = Date.now

    private var phaseLabel: String {
        switch week?.phase {
        case .offSeason: "Off-season"
        case .preSeason: "Pre-season"
        case .inSeason: "In-season"
        case .postSeason: "Post-season"
        case nil: "This week"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phaseLabel)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let sportSlug = athlete.sports.first?.sportSlug {
                            Text(allSportsBySlug[sportSlug]?.name ?? sportSlug)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let week {
                        if week.sessions.isEmpty {
                            Text("No training days generated for this week.")
                                .foregroundStyle(.white.opacity(0.6))
                                .cardStyle()
                        }
                        ForEach(week.sessions.indices, id: \.self) { index in
                            sessionCard(week.sessions[index])
                        }
                    } else {
                        ProgressView().tint(.white)
                    }

                    // §10: "a prominent 'Add a game' button... this is the
                    // action that makes the app smart, so it should never be
                    // more than one tap away."
                    Button("Add a game") { showingAddGame = true }
                        .buttonStyle(.accentFilled)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Plan")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingAddGame) {
                addGameSheet
            }
        }
    }

    private func sessionCard(_ session: GeneratedSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.date.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(session.title)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("\(session.estimatedMinutes) min")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)

            ForEach(session.items, id: \.order) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.itemSlug.replacingOccurrences(of: "-", with: " ").capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(item.rationale)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var addGameSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Game date", selection: $newGameDate, displayedComponents: .date)
                    .colorScheme(.dark)
                    .cardStyle()
                Button("Add") { addGame() }
                    .buttonStyle(.accentFilled)
            }
            .padding(24)
            .background(AppBackground())
            .navigationTitle("Add a game")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func addGame() {
        guard let sportSlug = athlete.sports.first?.sportSlug else { return }
        let competition = Competition(sportSlug: sportSlug, date: newGameDate, kind: .game, athlete: athlete)
        modelContext.insert(competition)
        try? modelContext.save()
        showingAddGame = false
        onGameAdded()
    }
}

private struct ImproveTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Improve is on the way", systemImage: "arrow.up.forward.circle",
                description: Text("The skill menu — pick a sport, a skill, and a deadline — is coming in a future update.")
            )
            .foregroundStyle(.white)
            .background(AppBackground())
            .navigationTitle("Improve")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct MeTabView: View {
    let athlete: Athlete
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let athleteSport = athlete.sports.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(allSportsBySlug[athleteSport.sportSlug]?.name ?? athleteSport.sportSlug)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("\(athleteSport.seasonStart.formatted(date: .abbreviated, time: .omitted)) – \(athleteSport.seasonEnd.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not a medical device.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Student Athlete never predicts injury, diagnoses, or advises return to play. It supplements your coach and athletic trainer; it never replaces them.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    // §20/§4: account deletion must never sit behind a
                    // paywall or be hard to find — it's a plain button here,
                    // not buried in a sub-menu.
                    Button(isDeleting ? "Deleting…" : "Delete account") {
                        showingDeleteConfirmation = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .disabled(isDeleting)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Me")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "Delete your account?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and everything stored on our server. This device's local copy is deleted too. This cannot be undone.")
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            let token = try? KeychainTokenStore().read()
            if let token {
                var request = URLRequest(url: AppConfig.backendBaseURL.appending(path: "athlete/me"))
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
            try? KeychainTokenStore().delete()
            modelContext.delete(athlete)
            try? modelContext.save()
            isDeleting = false
        }
    }
}

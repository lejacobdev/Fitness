import SwiftUI

/// Sends this week's Campus XP to the leagues (quietly; offline is fine).
@MainActor
enum LeagueSync {
    static func report(apiClient: APIClient = APIClient(baseURL: AppConfig.backendBaseURL)) async {
        guard !DemoData.isEnabled, let token = try? KeychainTokenStore().read() else { return }
        try? await apiClient.reportWeeklyXP(week: CampusLog.weekKey(), xp: CampusLog.xp(inWeekOf: .now), sessionToken: token)
    }
}

/// Newly earned badges, for the celebration sheet.
struct BadgeCelebration: Identifiable {
    let id = UUID()
    let badges: [CampusBadge]
}

// MARK: - Leagues

/// Leagues with teammates: a private group, joined with a code, ranked by
/// the Campus XP everyone earned this week.
struct LeaguesView: View {
    let stats: CampusStats

    @Environment(\.dismiss) private var dismiss
    @AppStorage("league.nickname") private var nickname = ""
    @State private var table: APIClient.LeagueTable?
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var mode: Mode?
    @State private var leagueName = ""
    @State private var code = ""
    @State private var working = false
    @State private var leagueToLeave: APIClient.LeagueTable.League?

    enum Mode { case create, join }

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Leagues", subtitle: "Learn with your teammates: everyone's Campus XP this week, in one table. A new week starts every Monday.")
                    if let errorMessage {
                        Label(errorMessage, systemImage: "wifi.exclamationmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.red)
                    }
                    if loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let table {
                        ForEach(table.leagues) { league in leagueCard(league) }
                        if table.leagues.isEmpty {
                            Text("You're not in a league yet. Start one and send the code to your teammates, or join theirs.")
                                .font(.body)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    actions
                    Text("People in your league only see your nickname and this week's XP.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .task { await load() }
            .confirmationDialog("Leave this league?", isPresented: Binding(
                get: { leagueToLeave != nil }, set: { if !$0 { leagueToLeave = nil } }
            ), titleVisibility: .visible) {
                Button("Leave", role: .destructive) {
                    if let league = leagueToLeave { Task { await leave(league) } }
                    leagueToLeave = nil
                }
                Button("Cancel", role: .cancel) { leagueToLeave = nil }
            }
        }
    }

    private func leagueCard(_ league: APIClient.LeagueTable.League) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(league.name)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Button { leagueToLeave = league } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave \(league.name)")
            }
            ForEach(Array(league.members.enumerated()), id: \.offset) { index, member in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(index == 0 ? Duo.goldLip : AppTheme.secondaryText)
                        .frame(width: 28)
                    Text(member.nickname + (member.isMe ? " (you)" : ""))
                        .font(member.isMe ? .headline : .body)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("\(member.xp) XP")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(member.isMe ? AppTheme.accent : AppTheme.ink)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(member.isMe ? AppTheme.accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            HStack {
                Label("Code: \(league.code)", systemImage: "number")
                    .font(.headline.monospaced())
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                #if os(iOS)
                ShareLink(item: "Join my Athlete OS league \"\(league.name)\" — in Campus tap the trophy, then Join, and enter the code \(league.code).") {
                    Label("Invite", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
                #endif
            }
        }
        .cardStyle(padding: 16)
    }

    @ViewBuilder
    private var actions: some View {
        switch mode {
        case nil:
            HStack(spacing: 12) {
                Button { mode = .create } label: { Label("Start a league", systemImage: "plus") }
                    .buttonStyle(.primary)
                Button { mode = .join } label: { Label("Join", systemImage: "person.badge.plus") }
                    .buttonStyle(.secondary)
            }
        case .create?:
            form(title: "Start a league", field: TextField("League name, e.g. U17 Girls", text: $leagueName), button: "Start") {
                try await apiClient.createLeague(name: leagueName, nickname: nickname, sessionToken: $0)
            }
        case .join?:
            form(title: "Join a league", field: TextField("6-letter code", text: $code), button: "Join") {
                try await apiClient.joinLeague(code: code.uppercased(), nickname: nickname, sessionToken: $0)
            }
        }
    }

    private func form(title: String, field: TextField<Text>, button: String,
                      action: @escaping (String) async throws -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            field
                .font(.title3)
                .padding(16)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            TextField("Your nickname (what others see)", text: $nickname)
                .font(.title3)
                .padding(16)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(spacing: 12) {
                Button("Cancel") { mode = nil }
                    .buttonStyle(.secondary)
                Button(working ? "…" : button) {
                    Task {
                        guard let token = try? KeychainTokenStore().read() else {
                            errorMessage = "Sign in again to use leagues."
                            return
                        }
                        working = true
                        do {
                            try await action(token)
                            mode = nil
                            leagueName = ""
                            code = ""
                            await load()
                        } catch {
                            errorMessage = message(for: error)
                        }
                        working = false
                    }
                }
                .buttonStyle(.primary)
                .disabled(working || nickname.trimmingCharacters(in: .whitespaces).count < 2)
            }
        }
        .cardStyle(padding: 16)
    }

    private func message(for error: Error) -> String {
        guard case APIClient.APIError.http(_, let code?) = error else { return "Couldn't reach the server — check your connection." }
        switch code {
        case "no_such_league": return "No league has that code. Check it with your teammate."
        case "invalid_nickname": return "Nicknames are 2–20 letters or numbers."
        case "invalid_name": return "Give the league a name (2–40 characters)."
        case "league_full": return "That league is full (50 people)."
        case "too_many_leagues": return "You're already in 5 leagues."
        default: return "Something went wrong — try again."
        }
    }

    private func load() async {
        await LeagueSync.report(apiClient: apiClient)
        guard let token = try? KeychainTokenStore().read() else {
            loading = false
            errorMessage = "Sign in to use leagues."
            return
        }
        do {
            let result = try await apiClient.leagues(week: CampusLog.weekKey(), sessionToken: token)
            table = result
            errorMessage = nil
            // First in any league with a teammate who played this week.
            let top = result.leagues.contains { league in
                league.members.count >= 2 && league.members.first?.isMe == true && (league.members.first?.xp ?? 0) > 0
                    && league.members.dropFirst().contains { $0.xp > 0 }
            }
            if top {
                var withTop = stats
                withTop.topOfLeague = true
                CampusBadges.award(withTop)
            }
        } catch {
            errorMessage = "Couldn't load your leagues — check your connection."
        }
        loading = false
    }

    private func leave(_ league: APIClient.LeagueTable.League) async {
        guard let token = try? KeychainTokenStore().read() else { return }
        try? await apiClient.leaveLeague(id: league.id, sessionToken: token)
        await load()
    }
}

// MARK: - Badges

struct BadgesView: View {
    @Environment(\.dismiss) private var dismiss
    private let earned = CampusBadges.earned()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Badges", subtitle: "\(earned.count) of \(CampusBadges.all.count) earned. Each one says how to get it.")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(CampusBadges.all) { badge in
                            tile(badge, earnedOn: earned[badge.id])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func tile(_ badge: CampusBadge, earnedOn: String?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(earnedOn != nil ? .white : Duo.lockedGlyph)
                .frame(width: 64, height: 64)
                .background(earnedOn != nil ? Duo.gold : Duo.lockedFill, in: Circle())
            Text(badge.title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
            Text(earnedOn.map { "Earned \($0)" } ?? badge.detail)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct BadgeCelebrationView: View {
    let badges: [CampusBadge]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text(badges.count == 1 ? "New badge!" : "\(badges.count) new badges!")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
            ForEach(badges) { badge in
                HStack(spacing: 14) {
                    Image(systemName: badge.systemImage)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Duo.gold, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(badge.detail)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
            }
            Button("Nice!") { dismiss() }
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(24)
        .sensoryFeedback(.success, trigger: badges.count)
    }
}

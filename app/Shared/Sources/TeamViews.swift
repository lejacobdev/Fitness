import SwiftUI

/// Workouts a coach assigned, kept on this phone so Home can show today's
/// even offline (refreshed with every backup; not backed up itself).
enum CoachAssignments {
    static let cacheKey = "teamsCache.assignments"

    static var cached: [APIClient.Assignment] {
        get { UserDefaults.standard.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode([APIClient.Assignment].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: cacheKey) }
    }

    static func today(calendar: Calendar = .current) -> [APIClient.Assignment] {
        let key = CampusReview.dayKey(.now, calendar: calendar)
        return cached.filter { $0.date == key }
    }

    @MainActor
    static func refresh(apiClient: APIClient) async {
        guard !DemoData.isEnabled, let token = try? KeychainTokenStore().read() else { return }
        let from = CampusReview.dayKey(.now, calendar: .current)
        if let assignments = try? await apiClient.myAssignments(from: from, sessionToken: token) {
            cached = assignments
        }
    }

    /// An assignment as a session the live workout screen can run.
    static func session(_ assignment: APIClient.Assignment, catalogue: Catalogue) -> GeneratedSession {
        let items = assignment.items.enumerated().map { index, item in
            let known = catalogue.item(item.itemSlug)
            let dose = Dose(kind: item.seconds != nil ? "time" : "reps", sets: item.sets, reps: item.reps, seconds: item.seconds)
            return GeneratedPlannedItem(
                itemSlug: item.itemSlug, order: index, dose: dose, restSec: known?.restSeconds ?? 60,
                rationale: "Assigned by your coach.", quality: known?.qualities.max { $0.value < $1.value }?.key ?? ""
            )
        }
        return GeneratedSession(date: .now, title: assignment.title, focusQualities: [],
                                estimatedMinutes: max(10, items.reduce(0) { $0 + $1.dose.sets * 2 }), items: items)
    }
}

/// Pain and training pauses, sent to the server — which keeps them only
/// while the athlete shares health with a team (My team → Share health).
/// Silently does nothing offline, signed out or in demo mode.
enum HealthShare {
    @MainActor
    static func send(kind: String, areas: [PainArea] = [], level: PainLevel? = nil, day: Date = .now) {
        guard !DemoData.isEnabled, let token = try? KeychainTokenStore().read() else { return }
        let key = DayKey.of(day)
        let areaNames = areas.map(\.rawValue)
        let levelName = level?.rawValue
        Task {
            try? await APIClient(baseURL: AppConfig.backendBaseURL)
                .postHealthNote(day: key, kind: kind, areas: areaNames, level: levelName, sessionToken: token)
        }
    }
}

/// Coach announcements, kept on this phone so Home can show them offline.
enum TeamAnnouncements {
    static let cacheKey = "teamsCache.announcements"
    static let seenKey = "teamsCache.announcementsSeen"

    static var cached: [APIClient.Announcement] {
        get { UserDefaults.standard.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode([APIClient.Announcement].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: cacheKey) }
    }

    /// The newest one from the last three days the athlete hasn't closed.
    static var current: APIClient.Announcement? {
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        let cutoff = Date.now.addingTimeInterval(-3 * 86_400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return cached.first { announcement in
            guard !seen.contains(announcement.id) else { return false }
            guard let date = formatter.date(from: announcement.createdAt) else { return true }
            return date >= cutoff
        }
    }

    static func markSeen(_ id: String) {
        let seen = (UserDefaults.standard.stringArray(forKey: seenKey) ?? []) + [id]
        UserDefaults.standard.set(Array(seen.suffix(50)), forKey: seenKey)
    }

    @MainActor
    static func refresh(apiClient: APIClient) async {
        guard !DemoData.isEnabled, let token = try? KeychainTokenStore().read() else { return }
        if let announcements = try? await apiClient.myAnnouncements(sessionToken: token) {
            // A coach's private shout-out shows the same way, marked as just for you.
            let shoutouts = ((try? await apiClient.myShoutouts(sessionToken: token)) ?? [])
                .map { APIClient.Announcement(id: "s-" + $0.id, teamId: "", teamName: ($0.teamName.map { $0 + " · " } ?? "") + "JUST FOR YOU", text: $0.text, createdAt: $0.createdAt) }
            cached = (shoutouts + announcements).sorted { $0.createdAt > $1.createdAt }
        }
    }
}

// MARK: - Athlete: my team

/// Join your coach's team with the code they give you.
struct MyTeamView: View {
    /// From a team link or QR code: already filled in.
    var initialCode: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var teams: APIClient.Teams?
    @State private var code = ""
    @State private var nickname = ""
    @State private var working = false
    @State private var message: String?
    @State private var teamToLeave: APIClient.Teams.Joined?
    @State private var trainerCode = ""
    @State private var trainerTeam: APIClient.Teams.Staffed?

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("My team", subtitle: "Join with your coach's code. They see your readiness and training, never what you write.")
                    if let message {
                        Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.red)
                    }
                    ForEach(teams?.member ?? []) { team in
                        HStack(spacing: 14) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(AppTheme.brand)
                                .frame(width: 48, height: 48)
                                .background(AppTheme.brand.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(team.name).font(.headline).foregroundStyle(AppTheme.ink)
                                Text("You're \(team.nickname)").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Button("Report") {
                                Task {
                                    try? await apiClient.report(kind: "team", target: team.id, sessionToken: try? KeychainTokenStore().read())
                                    message = "Thanks — we'll look at \(team.name) within 24 hours. You can also leave the team."
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            Button("Leave") { teamToLeave = team }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.red)
                        }
                        .cardStyle(padding: 14)
                        ShareHealthToggle(team: team)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a team").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                        CodeField(placeholder: "Team code from your coach", text: $code)
                        TextField("Your name on the team", text: $nickname)
                            .font(.title3)
                            .padding(16)
                            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button(working ? "Joining…" : "Join") { Task { await join() } }
                            .buttonStyle(.primary)
                            .disabled(working || code.count < 6 || nickname.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                    .cardStyle(padding: 16)
                    ForEach(teams?.trainer ?? []) { team in
                        Button { trainerTeam = team } label: {
                            ListRow(systemImage: "cross.case.fill", color: AppTheme.red, title: team.name, detail: "You're the athletic trainer")
                                .cardStyle(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Athletic trainer").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                        Text("Enter the trainer code the coach gave you. You'll see the pain reports and training pauses athletes choose to share.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        CodeField(placeholder: "Trainer code", text: $trainerCode)
                        Button("Join as athletic trainer") { Task { await joinAsTrainer() } }
                            .buttonStyle(.secondary)
                            .disabled(working || trainerCode.count < 6)
                    }
                    .cardStyle(padding: 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
            .liveReload { await load() }
            .onAppear { if let initialCode, code.isEmpty { code = initialCode } }
            .sheet(item: $trainerTeam) { team in
                TrainerHealthView(teamID: team.id, teamName: team.name)
            }
            .confirmationDialog("Leave this team?", isPresented: Binding(
                get: { teamToLeave != nil }, set: { if !$0 { teamToLeave = nil } }
            ), titleVisibility: .visible) {
                Button("Leave", role: .destructive) {
                    if let team = teamToLeave {
                        Task {
                            if let token = try? KeychainTokenStore().read() { try? await apiClient.leaveTeam(id: team.id, sessionToken: token) }
                            await load()
                        }
                    }
                    teamToLeave = nil
                }
                Button("Cancel", role: .cancel) { teamToLeave = nil }
            } message: {
                Text("Your coach stops seeing your readiness and training.")
            }
        }
    }

    private func joinAsTrainer() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        working = true
        do {
            try await apiClient.joinAsTrainer(code: trainerCode.uppercased(), sessionToken: token)
            Task { await PushSettings.enable() }
            trainerCode = ""
            message = nil
            await load()
        } catch {
            message = Self.joinMessage(for: error)
        }
        working = false
    }

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else {
            message = "Teams need an account — sign in with Apple in Me → Account."
            return
        }
        if let fresh = try? await apiClient.teams(sessionToken: token) {
            teams = fresh
            PushSettings.noteTeams(fresh)
        } else if teams == nil {
            message = "Couldn't reach the server — check your connection."
        }
    }

    /// What went wrong, and what to do about it.
    static func joinMessage(for error: Error) -> String {
        guard case APIClient.APIError.http(let status, let code) = error else {
            return "Couldn't reach the server — check your connection and try again."
        }
        switch (status, code) {
        case (_, "no_such_team"?): return "No team has that code. Check it with your coach — it's 6 letters and numbers."
        case (_, "invalid_code"?): return "A team code is 6 letters and numbers, like QA5P5Y."
        case (_, "invalid_nickname"?): return "Use 2–20 letters or numbers for your name on the team."
        case (_, "team_full"?): return "That team is full (80 athletes). Ask your coach."
        case (_, "you_coach_this_team"?): return "You're this team's coach on this account. Update the app to also join it as an athlete."
        case (401, _): return "You're signed out on this phone. Log out and sign in with Apple again, then join."
        default: return "Something went wrong on our side (error \(status)). Try again in a minute."
        }
    }

    private func join() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        working = true
        do {
            try await apiClient.joinTeam(code: code.trimmingCharacters(in: .whitespaces).uppercased(), nickname: nickname, sessionToken: token)
            code = ""
            message = nil
            Task { await PushSettings.enable() }
            await load()
            await CoachAssignments.refresh(apiClient: apiClient)
        } catch {
            message = Self.joinMessage(for: error)
        }
        working = false
    }
}

// MARK: - Coach mode

/// For coaches: make a team, share its code, see the team's readiness and
/// assign workouts.
struct CoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teams: APIClient.Teams?
    @State private var newTeamName = ""
    @State private var working = false
    @State private var message: String?
    @State private var openTeam: APIClient.Teams.Coached?

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Coach mode", subtitle: "Create a team and share the code. See check-ins and training, and send workouts.")
                    if let message {
                        Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.red)
                    }
                    ForEach(teams?.coaching ?? []) { team in
                        Button { openTeam = team } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "sportscourt.fill")
                                    .foregroundStyle(AppTheme.brand)
                                    .frame(width: 48, height: 48)
                                    .background(AppTheme.brand.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(team.name).font(.headline).foregroundStyle(AppTheme.ink)
                                    Text("\(team.memberCount) athletes · code \(team.code)").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
                            }
                            .cardStyle(padding: 14)
                        }
                        .buttonStyle(.plain)
                    }
                    if !(teams?.coaching ?? []).isEmpty || !(teams?.trainer ?? []).isEmpty {
                        CoachDashboardCard()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New team").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                        TextField("Team name, e.g. Varsity Soccer", text: $newTeamName)
                            .font(.title3)
                            .padding(16)
                            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button(working ? "Creating…" : "Create team") {
                            Task {
                                guard let token = try? KeychainTokenStore().read() else { return }
                                working = true
                                do {
                                    try await apiClient.createTeam(name: newTeamName, sessionToken: token)
                                    newTeamName = ""
                                    Task { await PushSettings.enable() }
                                    await load()
                                } catch {
                                    message = "Couldn't create the team — check your connection."
                                }
                                working = false
                            }
                        }
                        .buttonStyle(.primary)
                        .disabled(working || newTeamName.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                    .cardStyle(padding: 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
            .liveReload { await load() }
            .sheet(item: $openTeam, onDismiss: { Task { await load() } }) { team in
                TeamBoardView(team: team)
            }
        }
    }

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else {
            message = "Sign in to use coach mode."
            return
        }
        if let fresh = try? await apiClient.teams(sessionToken: token) {
            teams = fresh
            PushSettings.noteTeams(fresh)
        } else if teams == nil {
            message = "Couldn't reach the server — check your connection."
        }
    }
}

/// One team, for the coach: readiness today, training this week, workouts sent.
struct TeamBoardView: View {
    let team: APIClient.Teams.Coached

    @Environment(\.dismiss) private var dismiss
    @State private var board: APIClient.TeamReadiness?
    @State private var assignments: [APIClient.Assignment] = []
    @State private var assigning = false
    @State private var confirmDelete = false
    @State private var failed = false
    @State private var inviting = false
    @State private var showingPaywall = false
    @State private var announcements: [APIClient.Announcement] = []
    @State private var newAnnouncement = ""
    @State private var posting = false
    @State private var trainerCode: String?
    @State private var noteFor: NoteTarget?
    @State private var sideline = false
    @Environment(\.workoutContext) private var context
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }
    #else
    private let isWide = false
    #endif

    struct NoteTarget: Identifiable {
        let memberId: String
        let nickname: String
        var id: String { memberId }
        init(_ memberId: String, _ nickname: String) { self.memberId = memberId; self.nickname = nickname }
    }

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(team.name, subtitle: "Code \(team.code) — give it to your athletes to join.")
                    Button { inviting = true } label: {
                        Label("Invite athletes: code, link or QR code", systemImage: "qrcode")
                    }
                    .buttonStyle(.secondary)
                    if failed {
                        Text("Couldn't load the team — check your connection.").foregroundStyle(AppTheme.red)
                    }
                    readinessSection
                    announcementsSection
                    assignmentsSection
                    trainerSection
                    Button("Delete this team", role: .destructive) { confirmDelete = true }
                        .font(.headline)
                        .foregroundStyle(AppTheme.red)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
            .liveReload { await load() }
            .proFeature(isPresented: $showingPaywall, athlete: context?.athlete, feature: .coachWorkouts)
            .sheet(isPresented: $inviting) {
                CodeShareSheet(title: "Invite athletes", subtitle: "They scan the QR code, open the link, or enter the code in Me → My team.",
                               link: .team(team.code), message: "Join our team “\(team.name)” in AthleteOS")
            }
            .sheet(isPresented: $assigning, onDismiss: { Task { await load() } }) {
                AssignWorkoutSheet(teamID: team.id)
            }
            .sheet(item: $noteFor) { target in
                ShoutoutSheet(teamID: team.id, memberId: target.memberId, nickname: target.nickname)
            }
            #if os(iOS) && !APP_EXTENSION
            .fullScreenCover(isPresented: $sideline, onDismiss: { Task { await load() } }) {
                SidelineView(team: team)
            }
            #endif
            .confirmationDialog("Delete \(team.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete team", role: .destructive) {
                    Task {
                        if let token = try? KeychainTokenStore().read() { try? await apiClient.deleteOrLeaveTeam(id: team.id, sessionToken: token) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Athletes are removed from it and its workouts disappear. Their own data stays theirs.")
            }
        }
    }

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Today", subtitle: "From morning check-ins. Green: ready. Amber: a bit tired. Red: go easy.")
            #if os(iOS) && !APP_EXTENSION
            Button { sideline = true } label: {
                Label("Sideline mode — full screen, refreshes itself", systemImage: "rectangle.grid.2x2.fill")
            }
            .buttonStyle(.secondary)
            #endif
            if isWide, let members = board?.members, !members.isEmpty {
                ReadinessGrid(members: members)
            } else if let members = board?.members, !members.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.offset) { index, member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color(member.readiness))
                                .frame(width: 16, height: 16)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.nickname).font(.headline).foregroundStyle(AppTheme.ink)
                                Text(member.checkedInToday ? label(member.readiness) : "Not checked in yet")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                if let trend = member.trend {
                                    TrendDots(trend: trend, color: color)
                                }
                                if let missed = member.missedThisWeek, missed > 0 {
                                    Text("\(missed) check-in\(missed == 1 ? "" : "s") missed this week")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                if let health = member.health {
                                    HealthLine(health: health)
                                }
                                if let memberId = member.memberId {
                                    Button("Send a note") { noteFor = NoteTarget(memberId, member.nickname) }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .frame(minHeight: 32)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(member.sessionsThisWeek) workouts · \(member.minutesThisWeek) min")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("\(member.checkInsThisWeek) check-ins this week")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 10)
                        if index < members.count - 1 { Divider().overlay(AppTheme.hairline) }
                    }
                }
                .cardStyle(padding: 14)
            } else if board != nil {
                Text("No athletes yet. Send them the code.").foregroundStyle(AppTheme.secondaryText)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Workouts you sent", subtitle: "They show on each athlete's Home screen on that day, ready to start.")
            ForEach(assignments) { assignment in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.title).font(.headline).foregroundStyle(AppTheme.ink)
                        Text("\(assignment.date) · \(assignment.items.count) exercises").font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        Task {
                            if let token = try? KeychainTokenStore().read() {
                                try? await apiClient.deleteAssignment(teamID: team.id, id: assignment.id, sessionToken: token)
                            }
                            await load()
                        }
                    } label: {
                        Image(systemName: "trash").foregroundStyle(AppTheme.secondaryText).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(assignment.title)")
                }
                .cardStyle(padding: 12)
            }
            // The readiness board is free for coaches; sending workouts is Pro.
            Button { if ProAccess.isPro { assigning = true } else { showingPaywall = true } } label: {
                Label("Send a workout", systemImage: "paperplane.fill")
            }
            .buttonStyle(.primary)
        }
    }

    private func color(_ band: String?) -> Color {
        switch band {
        case "GREEN": AppTheme.green
        case "AMBER": AppTheme.amber
        case "RED": AppTheme.red
        default: AppTheme.fill
        }
    }

    private func label(_ band: String?) -> String {
        switch band {
        case "GREEN": "Ready"
        case "AMBER": "A bit tired"
        case "RED": "Tired — go easy"
        default: "Checked in"
        }
    }

    /// One-way messages to the team: they show on every athlete's Home.
    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Announcements", subtitle: "One-way: the team reads them on Home. No replies.")
            HStack(spacing: 10) {
                TextField("e.g. Practice moves to 5 pm tomorrow", text: $newAnnouncement, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(14)
                    .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                Button(posting ? "…" : "Send") { Task { await postAnnouncement() } }
                    .font(.headline)
                    .frame(minWidth: 52, minHeight: 48)
                    .disabled(posting || newAnnouncement.trimmingCharacters(in: .whitespaces).count < 2 || newAnnouncement.count > 300)
            }
            ForEach(announcements) { announcement in
                HStack(alignment: .top, spacing: 12) {
                    Text(announcement.text)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        Task {
                            if let token = try? KeychainTokenStore().read() {
                                try? await apiClient.deleteAnnouncement(teamID: team.id, id: announcement.id, sessionToken: token)
                            }
                            await load()
                        }
                    } label: {
                        Image(systemName: "trash").foregroundStyle(AppTheme.secondaryText).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete the announcement")
                }
                .cardStyle(padding: 12)
            }
        }
    }

    /// The athletic trainer's code: they see shared pain reports and training pauses only.
    private var trainerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Athletic trainer", subtitle: "With this code a trainer sees the pain reports and training pauses athletes choose to share. Nothing else.")
            if let trainerCode {
                Text(trainerCode)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                    #if os(iOS)
                    .textSelection(.enabled)
                    #endif
                Text("They enter it in Me → My team → Athletic trainer.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Button("Switch it off and remove trainers", role: .destructive) {
                    Task {
                        if let token = try? KeychainTokenStore().read() {
                            try? await apiClient.deleteTrainerCode(teamID: team.id, sessionToken: token)
                            self.trainerCode = nil
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.red)
            } else {
                Button("Make a trainer code") {
                    Task {
                        if let token = try? KeychainTokenStore().read() {
                            trainerCode = try? await apiClient.makeTrainerCode(teamID: team.id, sessionToken: token)
                        }
                    }
                }
                .buttonStyle(.secondary)
            }
        }
    }

    private func postAnnouncement() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        posting = true
        do {
            try await apiClient.postAnnouncement(teamID: team.id, text: newAnnouncement, sessionToken: token)
            newAnnouncement = ""
            await load()
        } catch APIClient.APIError.http(status: 400, _) {
            failed = true
        } catch {
            failed = true
        }
        posting = false
    }

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        if trainerCode == nil { trainerCode = team.trainerCode }
        let calendar = Calendar.current
        let today = CampusReview.dayKey(.now, calendar: calendar)
        let weekStart = CampusLog.weekKey(.now, calendar: calendar)
        do {
            board = try await apiClient.teamReadiness(teamID: team.id, today: today, weekStart: weekStart, sessionToken: token)
            assignments = try await apiClient.teamAssignments(teamID: team.id, from: today, sessionToken: token)
            announcements = (try? await apiClient.teamAnnouncements(teamID: team.id, sessionToken: token)) ?? []
            failed = false
        } catch {
            failed = true
        }
    }
}

/// Pick a day, a title and exercises from the library; send it to the team.
struct AssignWorkoutSheet: View {
    let teamID: String

    @Environment(\.dismiss) private var dismiss
    @State private var catalogue = Catalogue()
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var title = ""
    @State private var note = ""
    @State private var search = ""
    @State private var chosen: [APIClient.Assignment.Item] = []
    @State private var sending = false
    @State private var failed = false

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    private var results: [CatalogueItem] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return Array(CatalogueSearch.rank(Array(catalogue.itemsBySlug.values), query: search).prefix(12))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle("Send a workout", subtitle: "It appears on your athletes' Home screen on that day.")
                    DatePicker("Day", selection: $date, in: Date.now..., displayedComponents: .date)
                        .font(.headline)
                    field("Title, e.g. Recovery day", text: $title)
                    field("Note for the team (optional)", text: $note)
                    Text("Exercises").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                    ForEach(Array(chosen.enumerated()), id: \.offset) { index, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(catalogue.item(item.itemSlug)?.name ?? item.itemSlug).font(.headline).foregroundStyle(AppTheme.ink)
                                Text(item.seconds.map { "\(item.sets) × \($0) s" } ?? "\(item.sets) × \(item.reps ?? 10)")
                                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Button { chosen.remove(at: index) } label: {
                                Image(systemName: "minus.circle.fill").font(.title3).foregroundStyle(AppTheme.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove")
                        }
                        .cardStyle(padding: 12)
                    }
                    field("Search exercises to add", text: $search)
                    ForEach(results, id: \.slug) { item in
                        Button {
                            let dose = item.defaultDose
                            let seconds = dose.kind == "time" ? (dose.seconds ?? 30) : nil
                            chosen.append(.init(itemSlug: item.slug, sets: max(1, min(dose.sets, 10)), reps: seconds == nil ? (dose.reps ?? 10) : nil, seconds: seconds))
                            search = ""
                        } label: {
                            Label(item.name, systemImage: "plus.circle")
                                .font(.body)
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                    if failed {
                        Text("Couldn't send it — check your connection.").foregroundStyle(AppTheme.red)
                    }
                    Button(sending ? "Sending…" : "Send to the team") { Task { await send() } }
                        .buttonStyle(.primary)
                        .disabled(sending || chosen.isEmpty || title.trimmingCharacters(in: .whitespaces).count < 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.title3)
            .padding(16)
            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func send() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        sending = true
        do {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try await apiClient.assignWorkout(teamID: teamID, date: CampusReview.dayKey(date, calendar: .current),
                                              title: title.trimmingCharacters(in: .whitespaces),
                                              note: trimmedNote.isEmpty ? nil : trimmedNote, items: chosen, sessionToken: token)
            dismiss()
        } catch {
            failed = true
        }
        sending = false
    }
}

// MARK: - Parent summary

/// A private link to this week's summary, for a parent. Only numbers —
/// never anything the athlete wrote. Can be replaced or switched off.
struct ParentSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var link: URL?
    @State private var loading = true
    @State private var failed = false
    @State private var email: APIClient.ParentEmail?
    @State private var emailDraft = ""
    @State private var emailMessage: String?

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Parent summary", subtitle: "A private page for a parent: training, sleep, games and Campus. Never what you write.")
                    if loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let link {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your link is on", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.green)
                            Text(link.absoluteString)
                                .font(.footnote.monospaced())
                                .foregroundStyle(AppTheme.secondaryText)
                                #if os(iOS)
                                .textSelection(.enabled)
                                #endif
                            #if os(iOS) && !APP_EXTENSION
                            ShareLink(item: link, message: Text("My training week in AthleteOS — this page updates every day.")) {
                                Label("Send to a parent", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.primary)
                            #endif
                            Button("Make a new link (the old one stops working)") { Task { await make() } }
                                .buttonStyle(.secondary)
                            Button("Switch it off", role: .destructive) { Task { await switchOff() } }
                                .font(.headline)
                                .foregroundStyle(AppTheme.red)
                                .frame(maxWidth: .infinity)
                        }
                        .cardStyle()
                    } else {
                        Button { Task { await make() } } label: { Label("Create the link", systemImage: "link") }
                            .buttonStyle(.primary)
                    }
                    if !loading { emailSection }
                    if failed {
                        Text("Couldn't reach the server — check your connection.").foregroundStyle(AppTheme.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
            .task { await load() }
        }
    }

    /// The same summary by email every Sunday, once the parent confirms.
    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Every Sunday by email").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            if let email {
                Label(email.confirmed ? "Sent to \(email.email) every Sunday" : "Waiting for \(email.email) to confirm",
                      systemImage: email.confirmed ? "checkmark.circle.fill" : "envelope.badge")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(email.confirmed ? AppTheme.green : AppTheme.ink)
                if !email.confirmed {
                    Text("We sent them an email. Nothing else goes out until they confirm.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Button("Stop the emails", role: .destructive) { Task { await removeEmail() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.red)
            } else {
                Text("A parent gets this week's numbers every Sunday. They confirm first, and every email has a stop link.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Parent's email", text: $emailDraft)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                Button("Send the confirmation") { Task { await saveEmail() } }
                    .buttonStyle(.secondary)
                    .disabled(!emailDraft.contains("@") || !emailDraft.contains("."))
            }
            if let emailMessage {
                Text(emailMessage).font(.caption).foregroundStyle(AppTheme.red)
            }
        }
        .cardStyle()
    }

    private func saveEmail() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do {
            email = try await apiClient.setParentEmail(emailDraft.trimmingCharacters(in: .whitespaces), sessionToken: token)
            emailMessage = nil
        } catch APIClient.APIError.http(status: 400, _) {
            emailMessage = "That doesn't look like an email address."
        } catch APIClient.APIError.http(status: 429, _) {
            emailMessage = "You just changed it — try again in a few minutes."
        } catch {
            emailMessage = "Couldn't reach the server — check your connection."
        }
    }

    private func removeEmail() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do {
            try await apiClient.deleteParentEmail(sessionToken: token)
            email = nil
        } catch {
            emailMessage = "Couldn't reach the server — check your connection."
        }
    }

    private func load() async {
        defer { loading = false }
        guard let token = try? KeychainTokenStore().read() else { failed = true; return }
        do { link = try await apiClient.parentLink(sessionToken: token) } catch { failed = true }
        email = try? await apiClient.parentEmail(sessionToken: token)
    }

    private func make() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do { link = try await apiClient.makeParentLink(sessionToken: token); failed = false } catch { failed = true }
    }

    private func switchOff() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do { try await apiClient.deleteParentLink(sessionToken: token); link = nil } catch { failed = true }
    }
}


/// The last 14 days of a member's readiness, oldest first.
struct TrendDots: View {
    let trend: [String?]
    let color: (String?) -> Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(trend.enumerated()), id: \.offset) { _, band in
                Circle()
                    .fill(band == nil ? AppTheme.fill : color(band))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(trend.compactMap { $0 }.count) check-ins in the last 14 days")
    }
}

/// Shared health, in words: where it hurts and since when; paused training.
struct HealthLine: View {
    let health: APIClient.HealthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if health.paused {
                Label("Training paused\(health.pausedSince.map { " since \(HealthLine.day($0))" } ?? "") — head injury", systemImage: "pause.circle.fill")
                    .foregroundStyle(AppTheme.red)
            }
            if let pain = health.pain {
                Label("Pain: \(pain.areas.joined(separator: ", "))\(pain.level.map { " (\(HealthLine.level($0)))" } ?? "") · \(HealthLine.day(pain.day))", systemImage: "bandage.fill")
                    .foregroundStyle(AppTheme.coral)
            }
        }
        .font(.caption.weight(.semibold))
    }

    static func level(_ raw: String) -> String {
        PainLevel(rawValue: raw)?.title.lowercased() ?? raw
    }

    static func day(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return key }
        if Calendar.current.isDateInToday(date) { return "today" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// For an athletic trainer: the health notes members share with the team.
struct TrainerHealthView: View {
    let teamID: String
    let teamName: String

    @Environment(\.dismiss) private var dismiss
    @State private var health: APIClient.TeamHealth?
    @State private var failed = false
    @State private var recording: RtpTarget?

    struct RtpTarget: Identifiable {
        let memberId: String
        let nickname: String
        let step: Int
        var id: String { memberId }
    }
    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(teamName, subtitle: "Pain reports and training pauses from athletes who share them. Never a diagnosis.")
                    if failed {
                        Text("Couldn't load — check your connection.").foregroundStyle(AppTheme.red)
                    }
                    if let members = health?.members {
                        if members.isEmpty {
                            Text("No athlete shares health with this team yet.").foregroundStyle(AppTheme.secondaryText)
                        }
                        ForEach(members, id: \.nickname) { member in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(member.nickname).font(.headline).foregroundStyle(AppTheme.ink)
                                if !member.paused && member.pain == nil {
                                    Text("Nothing reported in the last 14 days.").font(.caption).foregroundStyle(AppTheme.secondaryText)
                                }
                                HealthLine(health: member)
                                if let step = member.rtpStep {
                                    Text("Return to play: step \(step) — \(ConcussionGuide.steps.first { $0.number == step }?.title ?? "")")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if health?.role == "trainer", (member.paused || member.rtpStep != nil), let memberId = member.memberId {
                                    Button("Record a return-to-play step") { recording = RtpTarget(memberId: memberId, nickname: member.nickname, step: member.rtpStep ?? 1) }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .frame(minHeight: 36)
                                }
                                if member.painDays > 1 {
                                    Text("Pain on \(member.painDays) of the last 14 days").font(.caption).foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(padding: 14)
                        }
                    } else if !failed {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
            .sheet(item: $recording, onDismiss: { Task { await reload() } }) { target in
                RtpRecordSheet(teamID: teamID, target: target)
            }
            .liveReload {
                guard let token = try? KeychainTokenStore().read() else { failed = true; return }
                do {
                    health = try await apiClient.teamHealth(teamID: teamID, sessionToken: token)
                    failed = false
                } catch {
                    if health == nil { failed = true }
                }
            }
        }
    }
}


/// Consent, per team: share pain reports and training pauses with the coach
/// and the team's athletic trainer. Off unless the athlete turns it on.
struct ShareHealthToggle: View {
    let team: APIClient.Teams.Joined
    @State private var isOn: Bool
    @State private var failed = false
    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    init(team: APIClient.Teams.Joined) {
        self.team = team
        _isOn = State(initialValue: team.shareHealth ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { isOn }, set: { newValue in
                isOn = newValue
                Task { await save(newValue) }
            })) {
                Text("Share pain and training pauses")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            .tint(AppTheme.green)
            Text(failed ? "Couldn't save — check your connection." : "With \(team.name)'s coach and athletic trainer: where it hurts and when training was paused after a head injury. Never what you write.")
                .font(.caption)
                .foregroundStyle(failed ? AppTheme.red : AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
    }

    private func save(_ share: Bool) async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do {
            try await apiClient.setShareHealth(teamID: team.id, share: share, sessionToken: token)
            failed = false
            // Today's pain or pause, so the coach doesn't wait for the next one.
            if share {
                if let pain = PainStore.report() { HealthShare.send(kind: "pain", areas: pain.areas, level: pain.level) }
                if DayStatusStore.status() == .concussion { HealthShare.send(kind: "paused") }
            }
        } catch {
            failed = true
            isOn = !share
        }
    }
}


/// A coach's private, positive note to one athlete.
struct ShoutoutSheet: View {
    let teamID: String
    let memberId: String
    let nickname: String
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var message: String?
    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle("A note for \(nickname)", subtitle: "Private, just for them. One a week — make it specific.")
                TextField("e.g. Great call on the switch in the second half", text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(14)
                    .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                if let message { Text(message).font(.caption).foregroundStyle(AppTheme.red) }
                Button("Send") { Task { await send() } }
                    .buttonStyle(.primary)
                    .disabled(text.trimmingCharacters(in: .whitespaces).count < 3 || text.count > 200)
                Spacer()
            }
            .padding(20)
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
        .presentationDetents([.medium])
    }

    private func send() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do {
            try await apiClient.sendShoutout(teamID: teamID, memberId: memberId, text: text, sessionToken: token)
            dismiss()
        } catch APIClient.APIError.http(status: 400, _) {
            message = "Keep it under 200 characters and friendly."
        } catch {
            message = "Couldn't reach the server — check your connection."
        }
    }
}


extension TrainerHealthView {
    func reload() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        if let fresh = try? await APIClient(baseURL: AppConfig.backendBaseURL).teamHealth(teamID: teamID, sessionToken: token) { health = fresh }
    }
}

/// The athletic trainer records which return-to-play step an athlete is on.
struct RtpRecordSheet: View {
    let teamID: String
    let target: TrainerHealthView.RtpTarget
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var note = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(target.nickname, subtitle: "Which return-to-play step are they on? You decide — the app only records it.")
                    ForEach(ConcussionGuide.steps, id: \.number) { item in
                        Button { step = item.number } label: {
                            OptionRow(title: "\(item.number). \(item.title)", subtitle: nil, systemImage: nil, isSelected: step == item.number)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("Note (optional), e.g. 15 min bike, no symptoms", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(14)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    if step >= 5 {
                        Text("Step 5 and up need a doctor's clearance (in writing where your school requires it).")
                            .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.red).fixedSize(horizontal: false, vertical: true)
                    }
                    if failed { Text("Couldn't save — check your connection.").font(.caption).foregroundStyle(AppTheme.red) }
                    Button("Record step \(step)") { Task { await save() } }.buttonStyle(.primary)
                }
                .padding(20)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
        .onAppear { step = target.step }
    }

    private func save() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        do {
            try await APIClient(baseURL: AppConfig.backendBaseURL).recordRtp(teamID: teamID, memberId: target.memberId, step: step,
                                                                          note: note.isEmpty ? nil : note, sessionToken: token)
            dismiss()
        } catch {
            failed = true
        }
    }
}

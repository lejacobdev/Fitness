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

// MARK: - Athlete: my team

/// Join your coach's team with the code they give you.
struct MyTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teams: APIClient.Teams?
    @State private var code = ""
    @State private var nickname = ""
    @State private var working = false
    @State private var message: String?
    @State private var teamToLeave: APIClient.Teams.Joined?

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("My team", subtitle: "Join your coach's team with their code. Your coach then sees how ready you are each day and how much you trained — never anything you wrote — and can send you workouts.")
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
                            Button("Leave") { teamToLeave = team }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.red)
                        }
                        .cardStyle(padding: 14)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a team").font(.title3.bold()).foregroundStyle(AppTheme.ink)
                        TextField("Team code from your coach", text: $code)
                            .font(.title3)
                            .padding(16)
                            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        TextField("Your name on the team", text: $nickname)
                            .font(.title3)
                            .padding(16)
                            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button(working ? "Joining…" : "Join") { Task { await join() } }
                            .buttonStyle(.primary)
                            .disabled(working || code.count < 6 || nickname.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                    .cardStyle(padding: 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .task { await load() }
            .confirmationDialog("Leave this team?", isPresented: Binding(
                get: { teamToLeave != nil }, set: { if !$0 { teamToLeave = nil } }
            ), titleVisibility: .visible) {
                Button("Leave", role: .destructive) {
                    if let team = teamToLeave {
                        Task {
                            if let token = try? KeychainTokenStore().read() { try? await apiClient.deleteOrLeaveTeam(id: team.id, sessionToken: token) }
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

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else {
            message = "Sign in to join a team."
            return
        }
        teams = try? await apiClient.teams(sessionToken: token)
        if teams == nil { message = "Couldn't reach the server — check your connection." }
    }

    private func join() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        working = true
        do {
            try await apiClient.joinTeam(code: code.trimmingCharacters(in: .whitespaces).uppercased(), nickname: nickname, sessionToken: token)
            code = ""
            message = nil
            await load()
            await CoachAssignments.refresh(apiClient: apiClient)
        } catch APIClient.APIError.http(_, let code?) where code == "no_such_team" {
            message = "No team has that code. Check it with your coach."
        } catch APIClient.APIError.http(_, let code?) where code == "invalid_nickname" {
            message = "Use 2–20 letters or numbers for your name."
        } catch {
            message = "Couldn't join — check your connection and try again."
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
                    ScreenTitle("Coach mode", subtitle: "Make a team and give your athletes the code. You'll see who checked in, who's tired and how much everyone trained, and you can send workouts.")
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
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .task { await load() }
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
        teams = try? await apiClient.teams(sessionToken: token)
        if teams == nil { message = "Couldn't reach the server — check your connection." }
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

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(team.name, subtitle: "Code \(team.code) — give it to your athletes to join.")
                    #if os(iOS) && !APP_EXTENSION
                    ShareLink(item: "Join our team \"\(team.name)\" in Athlete OS: Me → My team → enter the code \(team.code).") {
                        Label("Send the code", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.secondary)
                    #endif
                    if failed {
                        Text("Couldn't load the team — check your connection.").foregroundStyle(AppTheme.red)
                    }
                    readinessSection
                    assignmentsSection
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
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .task { await load() }
            .sheet(isPresented: $assigning, onDismiss: { Task { await load() } }) {
                AssignWorkoutSheet(teamID: team.id)
            }
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
            SectionHeader("Today", subtitle: "From each athlete's morning check-in. Green: ready. Amber: a bit tired. Red: go easy today.")
            if let members = board?.members, !members.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.offset) { index, member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color(member.readiness))
                                .frame(width: 16, height: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.nickname).font(.headline).foregroundStyle(AppTheme.ink)
                                Text(member.checkedInToday ? label(member.readiness) : "Not checked in yet")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
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
            Button { assigning = true } label: { Label("Send a workout", systemImage: "paperplane.fill") }
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

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else { return }
        let calendar = Calendar.current
        let today = CampusReview.dayKey(.now, calendar: calendar)
        let weekStart = CampusLog.weekKey(.now, calendar: calendar)
        do {
            board = try await apiClient.teamReadiness(teamID: team.id, today: today, weekStart: weekStart, sessionToken: token)
            assignments = try await apiClient.teamAssignments(teamID: team.id, from: today, sessionToken: token)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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

    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Parent summary", subtitle: "A private web page for a parent: this week's training, sleep, check-ins, upcoming games and Campus progress. Only numbers — never anything you wrote.")
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
                            ShareLink(item: link, message: Text("My training week in Athlete OS — this page updates every day.")) {
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
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .task { await load() }
        }
    }

    private func load() async {
        defer { loading = false }
        guard let token = try? KeychainTokenStore().read() else { failed = true; return }
        do { link = try await apiClient.parentLink(sessionToken: token) } catch { failed = true }
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

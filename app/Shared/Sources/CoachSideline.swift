import SwiftUI
#if os(iOS) && !APP_EXTENSION
import UIKit
#endif

/// iPad coach mode (25): the readiness board as big tiles, and a full-screen
/// "sideline mode" that refreshes itself and keeps the screen on.
enum BoardBand {
    static func color(_ band: String?) -> Color {
        switch band {
        case "GREEN": AppTheme.green
        case "AMBER": AppTheme.amber
        case "RED": AppTheme.red
        default: AppTheme.fill
        }
    }

    static func label(_ band: String?) -> String {
        switch band {
        case "GREEN": "Ready"
        case "AMBER": "A bit tired"
        case "RED": "Go easy"
        default: "Checked in"
        }
    }

    /// Who the coach should look at first: paused, red, amber, no check-in, green.
    static func rank(_ member: APIClient.TeamReadiness.Member) -> Int {
        if member.health?.paused == true { return 0 }
        switch member.checkedInToday ? member.readiness : nil {
        case "RED": return 1
        case "AMBER": return 2
        case nil: return 3
        default: return 4
        }
    }

    static func sorted(_ members: [APIClient.TeamReadiness.Member]) -> [APIClient.TeamReadiness.Member] {
        members.sorted { lhs, rhs in
            let left = rank(lhs), right = rank(rhs)
            return left == right ? lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending : left < right
        }
    }
}

/// One athlete as a big tile.
struct ReadinessTile: View {
    let member: APIClient.TeamReadiness.Member
    var large = false

    var body: some View {
        let paused = member.health?.paused == true
        let band: String? = member.checkedInToday ? member.readiness : nil
        let tint: Color = paused ? AppTheme.red : BoardBand.color(band)
        VStack(alignment: .leading, spacing: large ? 10 : 6) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: large ? 18 : 14, height: large ? 18 : 14)
                Text(paused ? "Paused" : (member.checkedInToday ? BoardBand.label(band) : "No check-in"))
                    .font((large ? Font.headline : Font.subheadline).weight(.bold))
                    .foregroundStyle(member.checkedInToday || paused ? AppTheme.ink : AppTheme.secondaryText)
            }
            Text(member.nickname)
                .font(.system(size: large ? 34 : 24, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(member.sessionsThisWeek) workouts · \(member.minutesThisWeek) min this week")
                .font(large ? .subheadline : .caption)
                .foregroundStyle(AppTheme.secondaryText)
            if let pain = member.health?.pain, !pain.areas.isEmpty {
                Text("Pain: \(pain.areas.joined(separator: ", "))")
                    .font((large ? Font.subheadline : Font.caption).weight(.semibold))
                    .foregroundStyle(AppTheme.amber)
                    .lineLimit(2)
            }
            if let step = member.health?.rtpStep {
                Text("Return to play: step \(step)")
                    .font((large ? Font.subheadline : Font.caption).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, minHeight: large ? 170 : 130, alignment: .topLeading)
        .padding(large ? 20 : 16)
        .background(tint.opacity(member.checkedInToday || paused ? 0.16 : 0.0), in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .cardStyle(padding: 0)
        .accessibilityElement(children: .combine)
    }
}

/// The tiles in a grid that fills the width.
struct ReadinessGrid: View {
    let members: [APIClient.TeamReadiness.Member]
    var large = false

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: large ? 240 : 200), spacing: 14)], spacing: 14) {
            ForEach(Array(BoardBand.sorted(members).enumerated()), id: \.offset) { _, member in
                ReadinessTile(member: member, large: large)
            }
        }
    }
}

#if os(iOS) && !APP_EXTENSION
/// Full screen, for an iPad on the sideline: refreshes every minute and keeps the screen on.
struct SidelineView: View {
    let team: APIClient.Teams.Coached
    @Environment(\.dismiss) private var dismiss
    @State private var board: APIClient.TeamReadiness?
    @State private var updated: Date?
    @State private var failed = false
    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIDELINE").font(.caption.weight(.bold)).tracking(2).foregroundStyle(AppTheme.brand)
                        Text(team.name).font(.system(size: 44, weight: .bold)).foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.title2.weight(.bold)).foregroundStyle(AppTheme.ink)
                            .frame(width: 56, height: 56).background(AppTheme.fill, in: Circle())
                    }
                    .accessibilityLabel("Close sideline mode")
                }
                summary
                if let members = board?.members, !members.isEmpty {
                    ReadinessGrid(members: members, large: true)
                } else if board != nil {
                    Text("No athletes yet.").font(.title3).foregroundStyle(AppTheme.secondaryText)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
                Text(footer).font(.footnote).foregroundStyle(failed ? AppTheme.red : AppTheme.secondaryText)
            }
            .padding(28)
        }
        .appScreen()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var summary: some View {
        let members = board?.members ?? []
        let counts: [(String, Int, Color)] = [
            ("Ready", members.filter { $0.checkedInToday && $0.readiness == "GREEN" }.count, AppTheme.green),
            ("Tired", members.filter { $0.checkedInToday && $0.readiness == "AMBER" }.count, AppTheme.amber),
            ("Go easy", members.filter { $0.checkedInToday && $0.readiness == "RED" }.count, AppTheme.red),
            ("Paused", members.filter { $0.health?.paused == true }.count, AppTheme.red),
            ("No check-in", members.filter { !$0.checkedInToday }.count, AppTheme.secondaryText),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
            ForEach(counts, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.1)").font(.system(size: 40, weight: .bold).monospacedDigit()).foregroundStyle(item.2)
                    Text(item.0).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 14)
            }
        }
    }

    private var footer: String {
        if failed { return "Couldn't refresh — check the connection. Trying again every minute." }
        guard let updated else { return "Loading…" }
        return "Updated \(updated.formatted(date: .omitted, time: .shortened)) · refreshes every minute · screen stays on"
    }

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else { failed = true; return }
        let calendar = Calendar.current
        do {
            board = try await apiClient.teamReadiness(teamID: team.id, today: CampusReview.dayKey(.now, calendar: calendar),
                                                      weekStart: CampusLog.weekKey(.now, calendar: calendar), sessionToken: token)
            updated = .now
            failed = false
        } catch {
            failed = true
        }
    }
}
#endif

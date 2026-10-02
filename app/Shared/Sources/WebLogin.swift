import SwiftUI

/// The coach dashboard signs in without a password: the computer shows a QR
/// code, the coach scans it with the iPhone camera, and approves it here.
enum CoachDashboard {
    static let url = URL(string: "https://api.lejacob.dev/fitness/dashboard/")!
    static let shortURL = "api.lejacob.dev/fitness/dashboard"
}

/// "Sign in on a computer?" — opened by the dashboard's QR code.
struct WebLoginApproveSheet: View {
    let loginID: String
    @Environment(\.dismiss) private var dismiss
    @State private var info: APIClient.WebLoginInfo?
    @State private var message: String?
    @State private var done: Bool?
    @State private var working = false
    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(title, subtitle: subtitle)
                    if let info, done == nil, info.status == "pending" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Computer").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                            Text(info.device ?? "A web browser").font(.title2.bold()).foregroundStyle(AppTheme.ink)
                            Text("Only approve if you're at that computer right now. It stays signed in for 12 hours, or until you sign out there.")
                                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                        Button(working ? "…" : "Sign in on this computer") { Task { await answer(true) } }
                            .buttonStyle(.primary)
                            .disabled(working)
                        Button("That's not me") { Task { await answer(false) } }
                            .buttonStyle(.secondary)
                            .disabled(working)
                    } else if info == nil, message == nil {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                    }
                    if let message {
                        Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if done != nil || message != nil || (info != nil && info?.status != "pending") {
                        Button("Done") { dismiss() }.buttonStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
            .task { await load() }
        }
    }

    private var title: String {
        switch done {
        case true?: "You're signed in"
        case false?: "Sign-in blocked"
        case nil: info.map { $0.status == "pending" ? "Sign in on a computer?" : "This code has expired" } ?? "Sign in on a computer"
        }
    }

    private var subtitle: String {
        switch done {
        case true?: "Look at the computer — the coach dashboard is open."
        case false?: "Nobody was signed in. If you didn't scan a code, you can ignore this."
        case nil: info.map { $0.status == "pending" ? "The coach dashboard asked to sign in as you." : "Reload the page on the computer for a new code." } ?? ""
        }
    }

    private func load() async {
        guard let token = try? KeychainTokenStore().read() else {
            message = "Sign in to AthleteOS on this phone first (Me → Account)."
            return
        }
        do {
            info = try await apiClient.webLoginInfo(id: loginID, sessionToken: token)
        } catch APIClient.APIError.http(status: 404, _) {
            info = APIClient.WebLoginInfo(status: "expired", device: nil, createdAt: "")
        } catch {
            message = "Couldn't reach AthleteOS — check your connection and scan again."
        }
    }

    private func answer(_ approve: Bool) async {
        guard let token = try? KeychainTokenStore().read() else { return }
        working = true
        defer { working = false }
        do {
            try await apiClient.approveWebLogin(id: loginID, approve: approve, sessionToken: token)
            done = approve
        } catch APIClient.APIError.http(status: 404, _) {
            info = APIClient.WebLoginInfo(status: "expired", device: nil, createdAt: "")
        } catch {
            message = "Couldn't reach AthleteOS — check your connection."
        }
    }
}

/// Coach mode → "On a computer": how to open the dashboard.
struct CoachDashboardCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On a computer").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
            Text("The coach dashboard").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            Text("Open \(CoachDashboard.shortURL) and scan the code with your iPhone camera. No password.")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            #if os(iOS) && !APP_EXTENSION
            ShareLink(item: CoachDashboard.url) {
                Label("Send the link to my computer", systemImage: "laptopcomputer")
            }
            .buttonStyle(.secondary)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

import SwiftUI

/// Training together (9): one athlete starts a workout "together" and shares
/// the code; others join on their own phones, and everyone sees how far the
/// others are. Nicknames only; the session is gone after a day.
enum PartnerWorkouts {
    static let nicknameKey = "league.partnerNickname"

    static var nickname: String {
        get { UserDefaults.standard.string(forKey: nicknameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nicknameKey) }
    }

    static func items(_ session: GeneratedSession) -> [APIClient.Assignment.Item] {
        session.items.prefix(20).map {
            APIClient.Assignment.Item(itemSlug: $0.itemSlug, sets: max(1, min(10, $0.dose.sets)), reps: $0.dose.reps, seconds: $0.dose.seconds)
        }
    }

    /// The shared workout as a session the live screen can run.
    static func session(_ shared: APIClient.PartnerSession, catalogue: Catalogue) -> GeneratedSession {
        let items = shared.items.enumerated().map { index, item in
            let known = catalogue.item(item.itemSlug)
            let dose = Dose(kind: item.seconds != nil ? "time" : "reps", sets: item.sets, reps: item.reps, seconds: item.seconds)
            return GeneratedPlannedItem(itemSlug: item.itemSlug, order: index, dose: dose, restSec: known?.restSeconds ?? 60,
                                        rationale: "Training together.", quality: known?.qualities.max { $0.value < $1.value }?.key ?? "")
        }
        return GeneratedSession(date: .now, title: shared.title, focusQualities: [],
                                estimatedMinutes: max(10, items.reduce(0) { $0 + $1.dose.sets * 2 }), items: items)
    }

    static func report(code: String, done: Int, total: Int, finished: Bool) async {
        guard let token = try? KeychainTokenStore().read() else { return }
        try? await APIClient(baseURL: AppConfig.backendBaseURL).reportPartnerProgress(code: code, done: done, total: total, finished: finished, sessionToken: token)
    }
}

/// Everyone's progress, at the top of the live workout (refreshes itself).
struct PartnerStrip: View {
    let code: String
    let done: Int
    let total: Int
    let finished: Bool
    @State private var people: [APIClient.PartnerSession.Person] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training together · \(code)").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
            ForEach(people.filter { !$0.isMe }, id: \.nickname) { person in
                HStack(spacing: 10) {
                    Text(person.nickname).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    ProgressView(value: Double(person.done), total: Double(max(1, person.total))).tint(AppTheme.brand)
                    Text(person.finished ? "Done" : "\(person.done)/\(person.total)").font(.caption.monospacedDigit()).foregroundStyle(AppTheme.secondaryText)
                }
            }
            if people.filter({ !$0.isMe }).isEmpty {
                Text("Waiting for your partner to join with the code.").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .task(id: done) {
            await PartnerWorkouts.report(code: code, done: done, total: total, finished: finished)
            await refresh()
        }
        .task {
            for _ in 0..<240 {
                try? await Task.sleep(for: .seconds(15))
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard let token = try? KeychainTokenStore().read(),
              let session = try? await APIClient(baseURL: AppConfig.backendBaseURL).partnerSession(code: code, sessionToken: token) else { return }
        people = session.people
    }
}

/// Workout → Train together: start one with a partner, or join with a code.
struct TrainTogetherSheet: View {
    let todays: GeneratedSession?
    let onStart: (GeneratedSession, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = PartnerWorkouts.nickname
    @State private var code = ""
    @State private var createdCode: String?
    @State private var message: String?
    @State private var working = false
    private let apiClient = APIClient(baseURL: AppConfig.backendBaseURL)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle("Train together", subtitle: "Same workout, each on your own phone — see how far the others are.")
                    TextField("Your name for your partner", text: $nickname)
                        .padding(14)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    if let message { Text(message).font(.caption).foregroundStyle(AppTheme.red) }
                    if let todays {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Start today's workout together").font(.headline).foregroundStyle(AppTheme.ink)
                            Text("\(todays.title) · \(todays.estimatedMinutes) min").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                            if let createdCode {
                                Text(createdCode).font(.system(size: 36, weight: .bold, design: .monospaced)).foregroundStyle(AppTheme.ink)
                                #if os(iOS) && !APP_EXTENSION
                                ShareLink(item: "Train with me in AthleteOS — join with code \(createdCode) (Workout → Train together).") {
                                    Label("Send the code", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.secondary)
                                #endif
                                Button("Start") { dismiss(); onStart(todays, createdCode) }.buttonStyle(.primary)
                            } else {
                                Button(working ? "…" : "Get a code") { Task { await create(todays) } }
                                    .buttonStyle(.primary)
                                    .disabled(working || nickname.trimmingCharacters(in: .whitespaces).count < 2)
                            }
                        }
                        .cardStyle()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Join with a code").font(.headline).foregroundStyle(AppTheme.ink)
                        CodeField(placeholder: "Code from your partner", text: $code)
                        Button(working ? "…" : "Join and start") { Task { await join() } }
                            .buttonStyle(.secondary)
                            .disabled(working || code.count < 6 || nickname.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                    .cardStyle()
                    Text("Only your name and how many exercises you've done are shared, for one day.")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
    }

    private func create(_ session: GeneratedSession) async {
        guard let token = try? KeychainTokenStore().read() else { message = "Training together needs an account — sign in in Me → Account."; return }
        working = true
        defer { working = false }
        PartnerWorkouts.nickname = nickname
        do {
            createdCode = try await apiClient.startPartnerSession(title: session.title, items: PartnerWorkouts.items(session), nickname: nickname, sessionToken: token)
            message = nil
        } catch {
            message = "Couldn't reach the server — check your connection."
        }
    }

    private func join() async {
        guard let token = try? KeychainTokenStore().read() else { message = "Training together needs an account — sign in in Me → Account."; return }
        working = true
        defer { working = false }
        PartnerWorkouts.nickname = nickname
        do {
            let shared = try await apiClient.joinPartnerSession(code: code.uppercased(), nickname: nickname, sessionToken: token)
            let catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
            dismiss()
            onStart(PartnerWorkouts.session(shared, catalogue: catalogue), shared.code)
        } catch APIClient.APIError.http(status: 404, _) {
            message = "No workout with that code — it may have ended."
        } catch {
            message = "Couldn't join — check the code and your connection."
        }
    }
}

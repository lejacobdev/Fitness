import SwiftData
import SwiftUI

@main
struct StudentAthleteApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try AthleteStore.makeContainer()
        } catch {
            // §14's local store is the device's only copy of everything not
            // yet synced — a container that fails to open is not a state the
            // app can silently paper over with an in-memory fallback.
            fatalError("Could not open the on-device store: \(error)")
        }
        PhoneWatchBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Links and QR codes (aos://…, api.lejacob.dev/fitness/…) open
                // the team, league or workout they point to — after setup, if
                // it isn't done yet.
                .onOpenURL { DeepLinkCenter.shared.open($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { DeepLinkCenter.shared.open(url) }
                }
                .tint(AppTheme.accent)
                // Big by default: one step above the system's standard text
                // size (and everything larger the athlete chooses still works).
                .dynamicTypeSize(.xLarge ... .accessibility3)
        }
        .modelContainer(container)
    }
}

/// §15: onboarding runs once per device. Whether it has already run is
/// decided by whether a local `Athlete` row exists yet, the same signal an
/// offline-first app with no separate "is onboarded" flag would use anywhere
/// else in the store. Once an athlete exists, whether they have a sport
/// picked decides onboarding vs. the real five-tab app.
@MainActor
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @State private var onboardingComplete = false
    /// Log out / delete account in progress: nothing signed-in stays on
    /// screen while its rows are removed.
    @State private var wiping = false
    /// A returning athlete's backup is coming back down after sign-in.
    @State private var restoring = false

    private var apiClient: APIClient {
        APIClient(baseURL: AppConfig.backendBaseURL)
    }

    private var packDownloader: PackDownloader {
        PackDownloader(client: apiClient, packsDirectory: AppConfig.packsDirectory())
    }

    var body: some View {
        content
            .task {
                DemoData.seedIfNeeded(context: modelContext)
                SportAliasMigration.migrate(modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: LocalWipe.willWipe)) { _ in wiping = true }
            .onReceive(NotificationCenter.default.publisher(for: LocalWipe.didWipe)) { _ in
                onboardingComplete = false
                wiping = false
            }
    }

    @ViewBuilder
    private var content: some View {
        if wiping {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appScreen()
        } else if restoring {
            VStack(spacing: 16) {
                ProgressView()
                Text("Getting your account back…")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appScreen()
        } else if let athlete = athletes.first {
            if athlete.sports.isEmpty {
                SetupFlowView(athlete: athlete)
            } else {
                MainTabView(athlete: athlete, apiClient: apiClient)
            }
        } else if onboardingComplete {
            // @Query can lag a `save()` by a run-loop tick; a nil athlete
            // here is that transient race, not a real "needs onboarding"
            // state, so this falls back to a brief loading state rather than
            // flashing back to the age gate.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appScreen()
        } else {
            OnboardingView(apiClient: apiClient, packDownloader: packDownloader, onRestoring: { restoring = $0 }) {
                onboardingComplete = true
            }
        }
    }
}

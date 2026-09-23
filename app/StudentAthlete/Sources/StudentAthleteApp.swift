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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
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
    @Query private var athletes: [Athlete]
    @State private var onboardingComplete = false

    private var apiClient: APIClient {
        APIClient(baseURL: AppConfig.backendBaseURL)
    }

    private var packDownloader: PackDownloader {
        PackDownloader(client: apiClient, packsDirectory: AppConfig.packsDirectory())
    }

    var body: some View {
        if let athlete = athletes.first {
            if athlete.sports.isEmpty {
                SportPickerView(athlete: athlete)
            } else {
                MainTabView(athlete: athlete, apiClient: apiClient)
            }
        } else if onboardingComplete {
            // @Query can lag a `save()` by a run-loop tick; a nil athlete
            // here is that transient race, not a real "needs onboarding"
            // state, so this falls back to a brief loading state rather than
            // flashing back to the age gate.
            ProgressView()
        } else {
            OnboardingView(apiClient: apiClient, packDownloader: packDownloader) {
                onboardingComplete = true
            }
        }
    }
}

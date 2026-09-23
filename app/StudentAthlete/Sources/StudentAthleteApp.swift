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
/// else in the store.
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
            PipelinePlaceholderView(athlete: athlete, apiClient: apiClient)
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

/// Still transitional — the real five-tab navigation (§15) is later work.
/// This screen's job has grown from M0's alone (report what the signed
/// binary can see) to also demonstrating M3's rendering is real, and now M5's
/// session logging is reachable and real too, not just compiled-in.
@MainActor
struct PipelinePlaceholderView: View {
    let athlete: Athlete
    let apiClient: APIClient

    private let evidence = BuildEvidence()
    @Environment(\.modelContext) private var modelContext
    @State private var showingLiveSession = false
    @State private var showingHistory = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Student Athlete")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Pipeline check — M0/M3")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 12) {
                    row("Version", "\(evidence.version) (\(evidence.build))", ok: true)
                    row("App Group container",
                        evidence.appGroupResolved ? "resolved" : "NOT RESOLVED",
                        ok: evidence.appGroupResolved)
                    row("Provisioning profile",
                        evidence.entitlementsPresent ? "embedded" : "none (unsigned build)",
                        ok: evidence.entitlementsPresent)
                }
                .cardStyle()

                trainingSection

                M3RenderingDemo()

                Text("Not a medical device. Student Athlete never predicts injury, "
                     + "diagnoses, or advises return to play. It supplements your "
                     + "coach and athletic trainer; it never replaces them.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .sheet(isPresented: $showingLiveSession) {
            LiveSessionView(athlete: athlete, apiClient: apiClient)
        }
        .sheet(isPresented: $showingHistory) {
            SessionHistoryView()
        }
        .task {
            // Best-effort, silent: a fresh launch with connectivity drains
            // anything logged offline since the last one. Failure here is
            // not surfaced — SyncQueue leaves unsynced rows untouched, so
            // the next launch (or the next call to this) just retries them.
            await SyncQueue(
                apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext
            ).drainPendingSessions()
        }
    }

    private var trainingSection: some View {
        VStack(spacing: 12) {
            Text("Today's training")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Start training session") { showingLiveSession = true }
                .buttonStyle(.accentFilled)
            Button("History") { showingHistory = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)
        }
        .cardStyle()
    }

    private func row(_ label: String, _ value: String, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : AppTheme.accent)
            Text(label)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
        }
        .font(.callout)
    }
}

/// §9's two jobs, both rendering real generated data: the static muscle map
/// (hinge pattern's primary movers) and the animated pose rig with a prop
/// (a soccer instep strike, ball attached to the striking foot).
struct M3RenderingDemo: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("§9 rendering — compiled-in demo data")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                VStack {
                    MuscleMapView(side: .back, weights: [
                        "gluteus-maximus": 1.0, "erector-spinae": 0.7, "biceps-femoris": 0.8,
                    ])
                    .frame(height: 220)
                    Text("Hinge — back").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                VStack {
                    MuscleMapView(side: .front, weights: [
                        "rectus-femoris": 0.8, "gluteus-maximus": 0.6, "tibialis-anterior": 0.4,
                    ])
                    .frame(height: 220)
                    Text("Instep strike — front").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }

            if let pattern = posePatternsBySlug["instep-strike"] {
                RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["ball-round"])
                    .frame(height: 220)
                Text("Instep strike, animated, with ball").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
        }
        .cardStyle()
    }
}

#Preview {
    let container = try! AthleteStore.makeContainer(inMemory: true)
    let athlete = Athlete(appleUserId: "preview-sub", birthDate: .now)
    container.mainContext.insert(athlete)
    return PipelinePlaceholderView(athlete: athlete, apiClient: APIClient(baseURL: AppConfig.backendBaseURL))
        .modelContainer(container)
}

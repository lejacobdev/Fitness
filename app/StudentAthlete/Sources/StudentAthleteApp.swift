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
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appending(path: "packs")) ?? FileManager.default.temporaryDirectory.appending(path: "packs")
        return PackDownloader(client: apiClient, packsDirectory: directory)
    }

    var body: some View {
        if athletes.first != nil || onboardingComplete {
            PipelinePlaceholderView()
        } else {
            OnboardingView(apiClient: apiClient, packDownloader: packDownloader) {
                onboardingComplete = true
            }
        }
    }
}

/// Still transitional — the real five-tab navigation (§15) is later work,
/// built once M4 (accounts and packs) gives the app something to actually
/// browse. This screen's job has grown from M0's alone (report what the
/// signed binary can see) to also demonstrating M3's rendering is real and
/// not just compiled, unused data — every value below is compiled-in content
/// (musclesBySlug, posePatternsBySlug, propsBySlug), not a downloaded pack,
/// since packs don't exist yet.
struct PipelinePlaceholderView: View {
    private let evidence = BuildEvidence()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Student Athlete")
                    .font(.largeTitle.bold())
                Text("Pipeline check — M0/M3")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    row("Version", "\(evidence.version) (\(evidence.build))", ok: true)
                    row("App Group container",
                        evidence.appGroupResolved ? "resolved" : "NOT RESOLVED",
                        ok: evidence.appGroupResolved)
                    row("Provisioning profile",
                        evidence.entitlementsPresent ? "embedded" : "none (unsigned build)",
                        ok: evidence.entitlementsPresent)
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                M3RenderingDemo()

                Text("Not a medical device. Student Athlete never predicts injury, "
                     + "diagnoses, or advises return to play. It supplements your "
                     + "coach and athletic trainer; it never replaces them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func row(_ label: String, _ value: String, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
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

            HStack(spacing: 16) {
                VStack {
                    MuscleMapView(side: .back, weights: [
                        "gluteus-maximus": 1.0, "erector-spinae": 0.7, "biceps-femoris": 0.8,
                    ])
                    .frame(height: 220)
                    Text("Hinge — back").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    MuscleMapView(side: .front, weights: [
                        "rectus-femoris": 0.8, "gluteus-maximus": 0.6, "tibialis-anterior": 0.4,
                    ])
                    .frame(height: 220)
                    Text("Instep strike — front").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let pattern = posePatternsBySlug["instep-strike"] {
                RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["ball-round"])
                    .frame(height: 220)
                Text("Instep strike, animated, with ball").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PipelinePlaceholderView()
}

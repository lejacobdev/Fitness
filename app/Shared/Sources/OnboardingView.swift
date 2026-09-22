import SwiftData
import SwiftUI

/// §15's six onboarding screens, this batch wiring the first two plus the
/// pack download that follows them: age gate (§2) → Sign in with Apple →
/// downloads the core pack, "and the app is usable the moment the pack
/// lands." Sport/position/season/equipment/coach/HealthKit are later work —
/// there is no sport catalogue pack to choose from until M6 generates one.
///
/// Marked `@MainActor` explicitly (redundant with `View`'s own `body`, but
/// not with its other methods) so every method here — including the ones
/// called from async `Task` closures — stays on the same isolation domain as
/// the `ModelContext` and SwiftUI state it touches; `SWIFT_STRICT_CONCURRENCY
/// = complete` (project.yml) enforces this at compile time, not just review.
@MainActor
public struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step: Step = .ageGate
    @State private var birthDate: Date?
    @State private var errorMessage: String?

    private let apiClient: APIClient
    private let packDownloader: PackDownloader
    private let onComplete: () -> Void

    private enum Step {
        case ageGate
        case signIn
        case downloadingCore
    }

    public init(apiClient: APIClient, packDownloader: PackDownloader, onComplete: @escaping () -> Void) {
        self.apiClient = apiClient
        self.packDownloader = packDownloader
        self.onComplete = onComplete
    }

    public var body: some View {
        Group {
            switch step {
            case .ageGate:
                AgeGateView { dob in
                    birthDate = dob
                    step = .signIn
                }
            case .signIn:
                signInStep
            case .downloadingCore:
                downloadingStep
            }
        }
    }

    private var signInStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Student Athlete")
                .font(.largeTitle.bold())
            Text("Sign in with Apple so your training history survives a new phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            AppleSignInButton(
                onSuccess: { identityToken, rawNonce in
                    handleSignIn(identityToken: identityToken, rawNonce: rawNonce)
                },
                onFailure: { error in
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            )
            .frame(height: 50)
            .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .padding(24)
    }

    private var downloadingStep: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Downloading your training library…")
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Continue offline") { onComplete() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }

    private func handleSignIn(identityToken: String, rawNonce: String) {
        errorMessage = nil
        Task {
            do {
                let response = try await apiClient.signInWithApple(
                    identityToken: identityToken, rawNonce: rawNonce, birthDate: birthDate
                )
                persistAthlete(from: response)
                step = .downloadingCore
                await downloadCorePack()
            } catch {
                errorMessage = "Couldn't sign in — check your connection and try again."
            }
        }
    }

    private func persistAthlete(from response: APIClient.AuthResponse) {
        let athlete = Athlete(
            id: response.athlete.id,
            appleUserId: response.athlete.appleUserId,
            birthDate: response.athlete.birthDate
        )
        modelContext.insert(athlete)
        try? modelContext.save()
    }

    private func downloadCorePack() async {
        do {
            let manifest = try await packDownloader.fetchManifest()
            guard let coreEntry = manifest.packs.first(where: { $0.slug == "core" }) else {
                onComplete()
                return
            }
            try await packDownloader.download(slug: "core", manifest: manifest)
            try DownloadedPackRecorder(context: modelContext).record(slug: "core", version: coreEntry.version)
            onComplete()
        } catch {
            // §3: "a free user always has at least one sport downloaded and
            // fully usable offline" is a steady-state guarantee, not a
            // first-launch one — a first launch with zero signal shouldn't
            // strand someone on a spinner forever, so let them continue and
            // retry the download later from Tab 5.
            errorMessage = "No connection — you can finish downloading from Settings later."
        }
    }
}

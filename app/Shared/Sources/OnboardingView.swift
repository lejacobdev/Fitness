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
    private let onRestoring: (Bool) -> Void

    private enum Step {
        case ageGate
        case signIn
        case downloadingCore
    }

    /// `onRestoring(true)` while a returning athlete's backup is brought
    /// back after sign-in, so the root view can hold off deciding between
    /// setup and the app until the restored sports are in.
    public init(apiClient: APIClient, packDownloader: PackDownloader,
                onRestoring: @escaping (Bool) -> Void = { _ in }, onComplete: @escaping () -> Void) {
        self.apiClient = apiClient
        self.packDownloader = packDownloader
        self.onRestoring = onRestoring
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
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") { step = .ageGate }
                StepProgressBar(progress: 0.3)
                    .padding(.leading, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)
                    ScreenTitle("Train smarter for your sport.", subtitle: "A plan built around your season, your position and your next game.")
                    VStack(alignment: .leading, spacing: 18) {
                        feature("calendar", AppTheme.blue, "A weekly plan that knows your season", "Build in the off-season, stay sharp in-season, peak for game day.")
                        feature("figure.run", AppTheme.orange, "1 tap to start, every set logged", "Animated how-tos with the muscles each exercise trains.")
                        feature("sparkles", AppTheme.purple, "A coach that notices", "Readiness, muscle balance and what to train next — every week.")
                        feature("lock.fill", AppTheme.green, "Private by design", "Sign in with Apple only. No email, no ads, no tracking.")
                    }
                }
                .padding(24)
            }

            VStack(spacing: 12) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.brand)
                        .multilineTextAlignment(.center)
                }
                AppleSignInButton(
                    onSuccess: { identityToken, rawNonce, authorizationCode in
                        handleSignIn(identityToken: identityToken, rawNonce: rawNonce, authorizationCode: authorizationCode)
                    },
                    onFailure: { _ in
                        errorMessage = "Sign in didn't finish — try again."
                    }
                )
                .frame(height: 56)
                .clipShape(Capsule())
                Text("By continuing you agree to the Terms and Privacy Policy.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .appScreen()
    }

    private func feature(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var downloadingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            RingView(progress: 0.7, color: AppTheme.ink, lineWidth: 10) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(width: 120, height: 120)
            Text("Getting your library ready")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Exercises, drills and animations — downloaded once, then everything works offline.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Continue offline") { onComplete() }
                    .buttonStyle(.primary)
                    .padding(.horizontal, 40)
            } else {
                ProgressView()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreen()
    }

    private func handleSignIn(identityToken: String, rawNonce: String, authorizationCode: String?) {
        errorMessage = nil
        // Captured while this view is on screen: the root view swaps it out
        // as soon as the athlete exists, and the work below carries on.
        let context = modelContext
        Task {
            do {
                let response = try await apiClient.signInWithApple(
                    identityToken: identityToken, rawNonce: rawNonce, birthDate: birthDate,
                    authorizationCode: authorizationCode
                )
                // Best-effort: a Keychain write failing here shouldn't block
                // onboarding — it only means the very first sync drain after
                // this session has nothing to authenticate with and quietly
                // no-ops (SyncQueue) until the athlete signs in again.
                try? KeychainTokenStore().save(response.sessionToken)
                // A returning athlete (new phone, reinstall) gets everything
                // back before choosing between setup and the app.
                onRestoring(true)
                let athlete = persistAthlete(from: response, in: context)
                await CloudSync.sync(athlete: athlete, context: context, apiClient: apiClient)
                await CloudSync.restoreRows(athlete: athlete, context: context, apiClient: apiClient, full: true)
                onRestoring(false)
                step = .downloadingCore
                await downloadCorePack(into: context)
            } catch {
                errorMessage = "Couldn't sign in — check your connection and try again."
            }
        }
    }

    private func persistAthlete(from response: APIClient.AuthResponse, in context: ModelContext) -> Athlete {
        let athlete = Athlete(
            id: response.athlete.id,
            appleUserId: response.athlete.appleUserId,
            birthDate: response.athlete.birthDate
        )
        context.insert(athlete)
        try? context.save()
        return athlete
    }

    private func downloadCorePack(into context: ModelContext) async {
        do {
            let manifest = try await packDownloader.fetchManifest()
            guard let coreEntry = manifest.packs.first(where: { $0.slug == "core" }) else {
                onComplete()
                return
            }
            try await packDownloader.download(slug: "core", manifest: manifest)
            try DownloadedPackRecorder(context: context).record(slug: "core", version: coreEntry.version)
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

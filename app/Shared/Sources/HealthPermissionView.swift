import SwiftUI

/// §15/§17: "HealthKit permission with the reason stated before the system
/// sheet." Everything here is optional — "Not now" leaves the whole app
/// working, and the check-in simply asks for sleep manually.
struct HealthPermissionView: View {
    var onFinished: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @AppStorage("healthPermissionAsked") private var asked = false
    @State private var isRequesting = false

    var body: some View {
        StepScaffold(
            title: "Connect Apple Health",
            subtitle: "Optional. Everything in Student Athlete works without it.",
            buttonTitle: isRequesting ? "Connecting…" : "Continue",
            buttonEnabled: !isRequesting,
            onBack: { finish() },
            onContinue: request
        ) {
            VStack(alignment: .leading, spacing: 18) {
                reason("moon.zzz.fill", AppTheme.purple, "Sleep",
                       "Reads how long you actually slept, so your morning check-in shows it instead of you guessing.")
                reason("figure.run", AppTheme.orange, "Workouts",
                       "Saves each session you finish to Health, once, so it sits alongside your other activity.")
                reason("lock.fill", AppTheme.green, "Stays private",
                       "Health data is only used inside the app for your training. Never for ads, never shared, never sold.")
            }
            .cardStyle()

            Button("Not now") { finish() }
                .buttonStyle(.secondary)
        }
    }

    private func reason(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func request() {
        isRequesting = true
        Task {
            await HealthKitManager.shared.requestAuthorization()
            isRequesting = false
            finish()
        }
    }

    private func finish() {
        asked = true
        onFinished()
        dismiss()
    }
}

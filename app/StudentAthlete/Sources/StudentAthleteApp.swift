import SwiftUI

@main
struct StudentAthleteApp: App {
    var body: some Scene {
        WindowGroup {
            PipelinePlaceholderView()
        }
    }
}

/// M0 only. The acceptance criterion for M0 is one *signed* build in TestFlight,
/// so this screen's job is to report what the signed binary can see — not to
/// look like the product. M1 onward replaces it; nothing here survives.
struct PipelinePlaceholderView: View {
    private let evidence = BuildEvidence()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Student Athlete")
                .font(.largeTitle.bold())
            Text("Pipeline check — M0")
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

            Spacer()

            Text("Not a medical device. Student Athlete never predicts injury, "
                 + "diagnoses, or advises return to play. It supplements your "
                 + "coach and athletic trainer; it never replaces them.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
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

#Preview {
    PipelinePlaceholderView()
}

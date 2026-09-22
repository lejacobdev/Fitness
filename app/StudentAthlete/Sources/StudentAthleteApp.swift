import SwiftUI

@main
struct StudentAthleteApp: App {
    var body: some Scene {
        WindowGroup {
            PipelinePlaceholderView()
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

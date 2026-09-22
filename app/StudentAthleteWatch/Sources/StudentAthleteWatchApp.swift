import SwiftUI

@main
struct StudentAthleteWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchPipelinePlaceholderView()
        }
    }
}

/// M0 only — see the iOS placeholder. Reports whether the watch binary resolved
/// the shared App Group, because §16's complication depends on it and a missing
/// entitlement fails silently.
struct WatchPipelinePlaceholderView: View {
    private let evidence = BuildEvidence()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pipeline — M0")
                    .font(.headline)
                Text("\(evidence.version) (\(evidence.build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(
                    evidence.appGroupResolved ? "App Group ok" : "App Group missing",
                    systemImage: evidence.appGroupResolved
                        ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(evidence.appGroupResolved ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

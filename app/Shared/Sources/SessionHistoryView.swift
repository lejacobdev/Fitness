import SwiftData
import SwiftUI

/// M5's "history": every logged session, most recent first. §15's Tab 5 gets
/// the fuller trends/charts version of this later — this is the plain list
/// M5's own acceptance criterion asks for.
public struct SessionHistoryView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    public init() {}

    public var body: some View {
        NavigationStack {
            List(sessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text("\(session.minutes) min")
                        if let rpe = session.sessionRPE {
                            Text("· RPE \(rpe)")
                        }
                        Text("· \(session.sets.count) sets")
                        Spacer()
                        Image(systemName: session.syncedAt != nil ? "checkmark.icloud" : "icloud.slash")
                            .foregroundStyle(session.syncedAt != nil ? .green : .secondary)
                            .accessibilityLabel(session.syncedAt != nil ? "Synced" : "Not yet synced")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet", systemImage: "figure.strengthtraining.traditional",
                        description: Text("Start a training session to see it here.")
                    )
                }
            }
            .navigationTitle("History")
        }
    }
}

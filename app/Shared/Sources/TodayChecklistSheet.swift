import SwiftUI

/// Home → "Today completed": what's done today and what's still open. A tap
/// finishes an open item or changes one that's done (the check-in and the
/// reflection open filled in; training opens today's workout or the log).
struct TodayChecklistSheet: View {
    let completion: DayCompletion
    /// One line under each item.
    let details: [DayCompletion.Kind: String]
    let onPick: (DayCompletion.Kind) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle("Today", subtitle: subtitle)
                    VStack(spacing: 0) {
                        ForEach(Array(completion.items.enumerated()), id: \.offset) { index, item in
                            row(item)
                            if index < completion.items.count - 1 {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .cardStyle(padding: 12)
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private var subtitle: String {
        let open = completion.items.count - completion.doneCount
        return open == 0 ? "All done. Tap anything to change it." : "\(completion.doneCount) of \(completion.items.count) done. Tap one to finish it."
    }

    private func row(_ item: DayCompletion.Item) -> some View {
        Button { onPick(item.kind) } label: {
            ListRow(systemImage: item.done ? "checkmark.circle.fill" : "circle",
                    color: item.done ? AppTheme.green : AppTheme.secondaryText,
                    title: item.title, detail: details[item.kind]) {
                Text(item.done ? "Edit" : "Do it")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(item.done ? AppTheme.ink : AppTheme.onAccent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(item.done ? AppTheme.fill : AppTheme.accent, in: Capsule())
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.done ? "done" : "not done yet")")
        .accessibilityHint(item.done ? "Opens it to change" : "Opens it to finish")
    }
}

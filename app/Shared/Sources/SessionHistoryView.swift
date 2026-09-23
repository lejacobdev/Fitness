import SwiftData
import SwiftUI

/// Every logged session, newest first, grouped by week — tap one to see
/// every set it contained.
public struct SessionHistoryView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @Environment(\.dismiss) private var dismiss
    @State private var catalogue = Catalogue()

    public init() {}

    private var weeks: [(start: Date, sessions: [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start ?? $0.startedAt }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("History", subtitle: "\(sessions.count) sessions · \(sessions.reduce(0) { $0 + $1.minutes }) minutes")
                    if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 30))
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("No sessions yet")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text("Start today's session and it lands here the moment you finish.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .cardStyle(padding: 28)
                    }
                    ForEach(weeks, id: \.start) { week in
                        Text("Week of \(week.start.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.top, 8)
                        ForEach(week.sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session, catalogue: catalogue)
                            } label: {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .appScreen()
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }
}

struct SessionDetailView: View {
    let session: Session
    let catalogue: Catalogue

    private var byItem: [(slug: String, sets: [SetLog])] {
        var order: [String] = []
        var grouped: [String: [SetLog]] = [:]
        for set in session.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
            if grouped[set.itemSlug] == nil { order.append(set.itemSlug) }
            grouped[set.itemSlug, default: []].append(set)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    private func setText(_ set: SetLog) -> String {
        var parts: [String] = []
        if let reps = set.reps { parts.append("\(reps) reps") }
        if let weight = set.weightKg { parts.append("\(weight.formatted(.number.precision(.fractionLength(0...1)))) kg") }
        if let seconds = set.seconds { parts.append("\(seconds)s") }
        if let distance = set.distanceM { parts.append("\(Int(distance)) m") }
        if let contacts = set.contacts { parts.append("\(contacts) contacts") }
        return parts.isEmpty ? "Logged" : parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(
                    session.startedAt.formatted(.dateTime.weekday(.wide).month().day()),
                    subtitle: session.startedAt.formatted(date: .omitted, time: .shortened)
                )
                HStack(spacing: 12) {
                    RingStatCard(value: "\(session.minutes)", label: "Minutes", progress: min(1, Double(session.minutes) / 60), color: AppTheme.blue, systemImage: "clock.fill")
                    RingStatCard(value: "\(session.sets.count)", label: "Sets", progress: min(1, Double(session.sets.count) / 20), color: AppTheme.orange, systemImage: "list.bullet")
                    RingStatCard(value: session.sessionRPE.map { "\($0)/10" } ?? "—", label: "Effort", progress: Double(session.sessionRPE ?? 0) / 10, color: AppTheme.brand, systemImage: "flame.fill")
                }
                HStack(spacing: 8) {
                    Image(systemName: session.syncedAt != nil ? "checkmark.icloud.fill" : "icloud.slash")
                    Text(session.syncedAt != nil ? "Backed up" : "Saved on this phone — backs up next time you're online")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(session.syncedAt != nil ? AppTheme.green : AppTheme.secondaryText)

                ForEach(byItem, id: \.slug) { entry in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ItemThumbnail(item: catalogue.item(entry.slug), size: 48)
                            Text(catalogue.item(entry.slug)?.name ?? displayName(forSlug: entry.slug))
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                        }
                        ForEach(Array(entry.sets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(width: 60, alignment: .leading)
                                Text(setText(set))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                            }
                        }
                    }
                    .cardStyle(padding: 16)
                }
            }
            .padding(20)
        }
        .appScreen()
    }
}

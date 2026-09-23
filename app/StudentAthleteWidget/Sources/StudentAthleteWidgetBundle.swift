import SwiftUI
import WidgetKit

@main
struct StudentAthleteWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        StreakWidget()
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Reads the snapshot the app writes into the shared App Group (§16) and
/// refreshes at the next midnight, when "today" changes.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: .now, snapshot: WidgetSnapshot.load())
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

private enum WidgetInk {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let orange = Color(red: 1, green: 0.54, blue: 0.24)
    static let red = Color(red: 0.9, green: 0.22, blue: 0.23)
}

private struct WidgetRing: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(WidgetInk.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    /// A snapshot from a previous day would show yesterday's plan — treat it
    /// as "open the app" rather than stale data.
    private var snapshot: WidgetSnapshot? {
        guard let snapshot = entry.snapshot, snapshot.isCurrent else { return nil }
        return snapshot
    }

    private var headline: String {
        guard let snapshot else { return "Open to plan today" }
        if snapshot.isGameDay { return "Game day" }
        return snapshot.sessionTitle ?? "Rest day"
    }

    private var bigNumber: String {
        guard let snapshot else { return "—" }
        if snapshot.isGameDay { return "Game" }
        return snapshot.sessionMinutes.map { "\($0)" } ?? "Rest"
    }

    private var weekProgress: Double {
        guard let snapshot, snapshot.plannedThisWeek > 0 else { return 0 }
        return Double(snapshot.sessionsThisWeek) / Double(snapshot.plannedThisWeek)
    }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetInk.muted)
                Spacer()
                Label("\(snapshot?.streak ?? 0)", systemImage: "flame.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetInk.orange)
            }
            Spacer(minLength: 0)
            Text(bigNumber)
                .font(.system(size: 38, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(snapshot?.sessionMinutes != nil ? "min · \(headline)" : headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetInk.muted)
                .lineLimit(2)
            if let snapshot, !snapshot.checkedIn {
                Label("Check in", systemImage: "sun.max.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetInk.ink)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot?.sportName.uppercased() ?? "STUDENT ATHLETE")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetInk.muted)
                Text(bigNumber)
                    .font(.system(size: 40, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    if let snapshot {
                        Label(snapshot.checkedIn ? "Checked in" : "Check in", systemImage: snapshot.checkedIn ? "checkmark.circle.fill" : "sun.max.fill")
                        if let next = snapshot.nextGameDate {
                            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: next)).day ?? 0
                            Label(days == 0 ? "Game today" : "Game in \(days)d", systemImage: "sportscourt.fill")
                                .foregroundStyle(WidgetInk.red)
                        }
                    }
                }
                .font(.caption2.bold())
                .foregroundStyle(WidgetInk.muted)
            }
            Spacer(minLength: 0)
            ZStack {
                WidgetRing(progress: weekProgress, lineWidth: 9)
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(WidgetInk.orange)
                    Text("\(snapshot?.sessionsThisWeek ?? 0)/\(snapshot?.plannedThisWeek ?? 0)")
                        .font(.caption.bold())
                }
            }
            .frame(width: 92, height: 92)
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's session, your check-in and your next game.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: TodayProvider()) { entry in
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(WidgetInk.orange)
                Text("\(entry.snapshot?.streak ?? 0)")
                    .font(.system(size: 34, weight: .bold))
                Text("day streak")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetInk.muted)
            }
            .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Days in a row you've checked in or trained.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

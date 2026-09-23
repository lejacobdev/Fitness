import SwiftUI
import WidgetKit

@main
struct StudentAthleteComplicationBundle: WidgetBundle {
    var body: some Widget {
        TodayComplication()
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// §16: "today's session, or the check-in prompt if it is not done, or a
/// countdown to the next game." Reads the snapshot the Watch app writes into
/// the shared App Group container, and refreshes at midnight.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: .now, snapshot: WidgetSnapshot.load())
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

enum ComplicationState {
    case checkIn
    case session(title: String, minutes: Int)
    case gameDay
    case countdown(days: Int)
    case rest

    init(_ snapshot: WidgetSnapshot?) {
        guard let snapshot, snapshot.isCurrent else {
            self = .checkIn
            return
        }
        if snapshot.isGameDay {
            self = .gameDay
        } else if !snapshot.checkedIn {
            self = .checkIn
        } else if let title = snapshot.sessionTitle, let minutes = snapshot.sessionMinutes {
            self = .session(title: title, minutes: minutes)
        } else if let next = snapshot.nextGameDate {
            let days = Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: next)
            ).day ?? 0
            self = days >= 0 ? .countdown(days: days) : .rest
        } else {
            self = .rest
        }
    }

    var icon: String {
        switch self {
        case .checkIn: "sun.max.fill"
        case .session: "figure.run"
        case .gameDay, .countdown: "sportscourt.fill"
        case .rest: "moon.zzz.fill"
        }
    }

    var short: String {
        switch self {
        case .checkIn: "Check in"
        case .session(_, let minutes): "\(minutes)m"
        case .gameDay: "Game"
        case .countdown(let days): "\(days)d"
        case .rest: "Rest"
        }
    }

    var headline: String {
        switch self {
        case .checkIn: "Morning check-in"
        case .session(let title, _): title
        case .gameDay: "Game day"
        case .countdown(let days): days == 1 ? "Game tomorrow" : "Game in \(days) days"
        case .rest: "Rest day"
        }
    }

    var detail: String {
        switch self {
        case .checkIn: "Four taps"
        case .session(_, let minutes): "\(minutes) min planned"
        case .gameDay: "Warm-up only"
        case .countdown: "Stay sharp"
        case .rest: "Recover well"
        }
    }
}

struct ComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    private var state: ComplicationState { ComplicationState(entry.snapshot) }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(state.headline, systemImage: state.icon)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let streak = entry.snapshot?.streak, streak > 0 {
                    Text("\(streak)-day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryCorner:
            Image(systemName: state.icon)
                .font(.title3)
                .widgetAccentable()
                .widgetLabel(state.short)
        case .accessoryInline:
            Label(state.headline, systemImage: state.icon)
        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: state.icon)
                        .font(.body)
                        .widgetAccentable()
                    Text(state.short)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }
}

struct TodayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CheckInComplication", provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Student Athlete")
        .description("Your check-in, today's session, or the countdown to your next game.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

import SwiftUI
import WidgetKit

@main
struct StudentAthleteWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let appGroupResolved: Bool
}

/// M0 placeholder timeline. M8 replaces the entry with the real check-in state
/// read from the shared App Group container.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, appGroupResolved: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now,
                              appGroupResolved: AppIdentifiers.sharedContainer != nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: .now,
                               appGroupResolved: AppIdentifiers.sharedContainer != nil)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            VStack(alignment: .leading, spacing: 2) {
                Text("Student Athlete")
                    .font(.caption.bold())
                Text(entry.appGroupResolved ? "Pipeline ok — M0" : "App Group missing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your check-in and today's session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

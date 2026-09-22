import SwiftUI
import WidgetKit

@main
struct StudentAthleteComplicationBundle: WidgetBundle {
    var body: some Widget {
        CheckInComplication()
    }
}

struct CheckInEntry: TimelineEntry {
    let date: Date
    let checkedInToday: Bool
}

/// M0 placeholder. M8 reads the real check-in state from the shared App Group
/// container — §16 notes this silently shows nothing if the App Group
/// entitlement is absent, which is why the M0 screens report it.
struct CheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckInEntry {
        CheckInEntry(date: .now, checkedInToday: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckInEntry) -> Void) {
        completion(CheckInEntry(date: .now, checkedInToday: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInEntry>) -> Void) {
        let entry = CheckInEntry(date: .now, checkedInToday: false)
        // Refresh at the next local midnight: the check-in is a once-per-day act.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct CheckInComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CheckInComplication", provider: CheckInProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.checkedInToday ? "checkmark" : "sun.horizon.fill")
                    .font(.title3)
            }
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Check-in")
        .description("Your morning check-in, four taps.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

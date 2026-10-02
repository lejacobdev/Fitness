import ActivityKit
import SwiftUI
import WidgetKit

@main
struct StudentAthleteWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        StreakWidget()
        EmergencyWidget()
        WorkoutLiveActivity()
    }
}

/// The running workout on the Lock Screen and in the Dynamic Island.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(context.state.exercise)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let rest = context.state.restEndsAt, rest > .now {
                    Text(timerInterval: Date.now...rest, countsDown: true)
                        .font(.system(size: 32, weight: .bold).monospacedDigit())
                        .frame(width: 96)
                        .multilineTextAlignment(.trailing)
                } else {
                    WidgetRing(progress: context.state.progress, lineWidth: 6)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.exercise, systemImage: "figure.strengthtraining.traditional")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let rest = context.state.restEndsAt, rest > .now {
                        Text(timerInterval: Date.now...rest, countsDown: true)
                            .font(.title3.bold().monospacedDigit())
                            .frame(width: 64)
                    } else {
                        Text("\(context.state.setsDone)/\(context.state.setsTotal)")
                            .font(.title3.bold())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                if let rest = context.state.restEndsAt, rest > .now {
                    Text(timerInterval: Date.now...rest, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 44)
                } else {
                    Text("\(context.state.setsDone)/\(context.state.setsTotal)")
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
        }
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
    static let orange = Color.primary
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

    /// Today's readiness in words (never a score); "Check in" before it.
    private var readinessWord: String {
        guard let snapshot, snapshot.checkedIn else { return "Check in" }
        switch snapshot.readiness {
        case "AMBER": return "Reduced"
        case "RED": return "Recovery focus"
        default: return "Normal"
        }
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
                Text(readinessWord)
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetInk.ink)
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
            if let next = snapshot?.nextGameDate {
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: next)).day ?? 0
                Text(days == 0 ? "Game today" : "Game in \(days)d")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetInk.red)
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
                        Label(readinessWord, systemImage: snapshot.checkedIn ? "checkmark.circle.fill" : "sun.max.fill")
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
                    Text("\(snapshot?.sessionsThisWeek ?? 0)/\(snapshot?.plannedThisWeek ?? 0)")
                        .font(.caption.bold())
                    Text("this week")
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetInk.muted)
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
        .description("Today's readiness and training, and your next game.")
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


/// The emergency card on the Lock Screen (opt-in: it shows only if the
/// athlete adds it). Readable without unlocking, for someone helping.
struct EmergencyEntry: TimelineEntry {
    let date: Date
    let card: EmergencyCard
}

struct EmergencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmergencyEntry {
        var card = EmergencyCard()
        card.allergies = "Peanuts"
        card.contacts = [EmergencyCard.Contact(name: "Alex", relation: "Mom", phone: "555 0100")]
        return EmergencyEntry(date: .now, card: card)
    }

    func getSnapshot(in context: Context, completion: @escaping (EmergencyEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : EmergencyEntry(date: .now, card: EmergencyCard.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmergencyEntry>) -> Void) {
        completion(Timeline(entries: [EmergencyEntry(date: .now, card: EmergencyCard.load())], policy: .never))
    }
}

struct EmergencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EmergencyWidget", provider: EmergencyProvider()) { entry in
            EmergencyWidgetView(card: entry.card)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Emergency")
        .description("Allergies and who to call, for someone helping you. Fill it in at Me → Emergency card.")
        .supportedFamilies([.accessoryRectangular, .systemSmall])
    }
}

struct EmergencyWidgetView: View {
    let card: EmergencyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("EMERGENCY", systemImage: "staroflife.fill")
                .font(.caption2.weight(.bold))
            if card.isEmpty {
                Text("Fill in Me → Emergency card").font(.caption)
            } else {
                if !card.allergies.isEmpty {
                    Text("Allergies: \(card.allergies)").font(.caption).lineLimit(1)
                }
                if let contact = card.contacts.first {
                    Text("\(contact.relation.isEmpty ? contact.name : contact.relation) \(contact.phone)").font(.caption.weight(.semibold)).lineLimit(1)
                }
                if card.allergies.isEmpty, !card.medicalNotes.isEmpty {
                    Text(card.medicalNotes).font(.caption).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

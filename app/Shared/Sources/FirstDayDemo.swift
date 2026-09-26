import SwiftUI

/// "Your first day" in about a minute, before any sign-in: what a day with
/// AthleteOS looks like, one moment at a time. Pages move on by themselves
/// (12 s each); a tap moves on sooner.
struct FirstDayDemo: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    struct Moment: Identifiable {
        let id: Int
        let time: String
        let icon: String
        let title: String
        let body: String
    }

    static let moments: [Moment] = [
        Moment(id: 0, time: "7:15", icon: "sun.max.fill", title: "Morning check-in",
               body: "Two taps: how you slept, how sore you are. Your watch can fill in the rest. Today's readiness, in words."),
        Moment(id: 1, time: "7:16", icon: "list.bullet.rectangle", title: "Today's plan",
               body: "Practice at 3:30, so the gym work is short: strength and injury prevention for your sport. And why."),
        Moment(id: 2, time: "3:00", icon: "figure.run", title: "Movement prep",
               body: "Ten minutes to wake your body up before practice. Every exercise shows you how."),
        Moment(id: 3, time: "12:30", icon: "graduationcap.fill", title: "Campus",
               body: "A three-minute lesson on the bus: sleep, food, nerves, tactics. It picks the one that fits your day."),
        Moment(id: 4, time: "9:00", icon: "moon.stars.fill", title: "Evening reflection",
               body: "How hard was today, how does your body feel? Tomorrow's plan adapts to it."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Your first day").font(.headline).foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Button("Close") { dismiss() }.font(.headline).foregroundStyle(AppTheme.ink)
            }
            TabView(selection: $page) {
                ForEach(Self.moments) { moment in
                    VStack(alignment: .leading, spacing: 18) {
                        Text(moment.time)
                            .font(.system(size: 17, weight: .semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.secondaryText)
                        Image(systemName: moment.icon)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(AppTheme.brand)
                        Text(moment.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(moment.body)
                            .font(.title3)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { next() }
                    .tag(moment.id)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif
            Button(page == Self.moments.count - 1 ? "Start" : "Next") { next() }
                .buttonStyle(.primary)
        }
        .padding(24)
        .appScreen()
        .task(id: page) {
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled, page < Self.moments.count - 1 { withAnimation { page += 1 } }
        }
    }

    private func next() {
        if page < Self.moments.count - 1 { withAnimation { page += 1 } } else { dismiss() }
    }
}

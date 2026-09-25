import SwiftData
import SwiftUI
import WidgetKit

@main
struct StudentAthleteWatchApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try AthleteStore.makeContainer()
        } catch {
            // The Watch's store holds sets logged with no phone and no
            // signal — failing loudly beats silently logging into memory.
            fatalError("Could not open the Watch store: \(error)")
        }
        PhoneWatchBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
    }
}

/// Drains everything logged on the Watch straight to the backend when there
/// is a signal (Wi-Fi/LTE, or the phone's connection) — §16.
@MainActor
enum WatchSync {
    static func drain(context: ModelContext) async {
        let queue = SyncQueue(
            apiClient: APIClient(baseURL: AppConfig.backendBaseURL),
            tokenStore: KeychainTokenStore(), modelContext: context
        )
        await queue.drainPendingSessions()
        await queue.drainPendingCheckIns()
    }
}

/// The Watch keeps its own App Group container, so it writes its own
/// snapshot for its own complication.
@MainActor
enum WatchSnapshotWriter {
    static func write(payload: WatchTodayPayload, athlete: Athlete?) {
        let today = payload.isForToday
        let checkedIn = payload.checkedInOnPhone && today || (athlete.map { AthleteStats.todaysCheckIn($0) != nil } ?? false)
        let sessionsThisWeek: Int = athlete.map { athlete in
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
            return athlete.sessions.filter { interval?.contains($0.startedAt) ?? false }.count
        } ?? 0
        let snapshot = WidgetSnapshot(
            day: .now, sportName: payload.sportName,
            sessionTitle: today ? payload.sessionTitle : nil,
            sessionMinutes: today ? payload.sessionMinutes : nil,
            exerciseCount: today ? payload.items.count : 0,
            isGameDay: today && payload.isGameDay, checkedIn: checkedIn, readiness: nil,
            nextGameDate: payload.nextGameDate,
            streak: athlete.map { AthleteStats.streak(checkInDates: $0.checkIns.map(\.date), sessionDates: $0.sessions.map(\.startedAt)) } ?? 0,
            sessionsThisWeek: sessionsThisWeek, plannedThisWeek: 0
        )
        guard let url = WidgetSnapshot.fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WatchRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var athletes: [Athlete]
    @State private var payload = WatchTodayPayload.loadFromDevice()
    @State private var showingSession = false
    @State private var showingCheckIn = false

    private var athlete: Athlete? {
        guard let payload else { return athletes.first }
        return athletes.first { $0.id == payload.athleteId } ?? athletes.first
    }

    private var checkedInToday: Bool {
        (payload?.checkedInOnPhone == true && payload?.isForToday == true)
            || (athlete.map { AthleteStats.todaysCheckIn($0) != nil } ?? false)
    }

    var body: some View {
        NavigationStack {
            if let payload, let athlete {
                home(payload: payload, athlete: athlete)
            } else {
                setupView
            }
        }
        .task {
            // App Store screenshots: a seeded day, with no phone needed.
            if DemoData.isEnabled { WatchDemo.seed() }
            reload()
            if DemoData.isEnabled, ProcessInfo.processInfo.arguments.contains("-checkIn") { showingCheckIn = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: PhoneWatchBridge.payloadDidChange)) { _ in reload() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                reload()
                Task { await WatchSync.drain(context: modelContext) }
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2)
            Text("Open Athlete OS on your iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Your plan arrives here once, then everything works without your phone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func home(payload: WatchTodayPayload, athlete: Athlete) -> some View {
        let today = payload.isForToday
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(payload.sportName.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                if !checkedInToday {
                    Button {
                        showingCheckIn = true
                    } label: {
                        Label("Morning check-in", systemImage: "sun.max.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                }

                if today && payload.isGameDay {
                    card(big: "Game", label: "Warm-up only today", icon: "sportscourt.fill")
                } else if today, let title = payload.sessionTitle, !payload.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(payload.sessionMinutes ?? 0)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            Text("min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(title)
                            .font(.footnote.weight(.semibold))
                        Text("\(payload.items.count) exercises")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button {
                            showingSession = true
                        } label: {
                            Text("Start").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                    }
                    .padding(10)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    card(big: today ? "Rest" : "—", label: today ? "Recovery day" : "Open the iPhone app to refresh today's plan", icon: "moon.zzz.fill")
                }

                if let next = payload.nextGameDate, next >= Calendar.current.startOfDay(for: .now) {
                    let days = AthleteStats.daysUntil(next)
                    Label(days == 0 ? "Game today" : "Next game in \(days)d", systemImage: "sportscourt.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                let pending = athlete.sessions.filter { $0.syncedAt == nil }.count
                if pending > 0 {
                    Label("\(pending) waiting to sync", systemImage: "icloud.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Today")
        .fullScreenCover(isPresented: $showingSession) {
            WatchSessionView(items: payload.items, title: payload.sessionTitle ?? "Session", athlete: athlete, sportSlug: payload.sportSlug) {
                showingSession = false
                WatchSnapshotWriter.write(payload: payload, athlete: athlete)
            }
        }
        .sheet(isPresented: $showingCheckIn) {
            WatchCheckInView(athlete: athlete) {
                showingCheckIn = false
                WatchSnapshotWriter.write(payload: payload, athlete: athlete)
                Task { await WatchSync.drain(context: modelContext) }
            }
        }
    }

    private func card(big: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(big)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Adopts whatever the phone last sent: the athlete row the Watch's own
    /// sessions and check-ins attach to, and the token for direct syncing.
    private func reload() {
        payload = WatchTodayPayload.loadFromDevice()
        guard let payload else { return }
        let id = payload.athleteId
        let existing = (try? modelContext.fetch(FetchDescriptor<Athlete>(predicate: #Predicate { $0.id == id })))?.first
        let athlete = existing ?? {
            let created = Athlete(id: payload.athleteId, appleUserId: payload.appleUserId, birthDate: payload.birthDate)
            modelContext.insert(created)
            return created
        }()
        try? modelContext.save()
        if let token = payload.sessionToken {
            try? KeychainTokenStore().save(token)
        }
        WatchSnapshotWriter.write(payload: payload, athlete: athlete)
    }
}

/// A believable day for App Store screenshots (`-demoData`), written as if
/// the phone had sent it.
@MainActor
enum WatchDemo {
    static func seed(now: Date = .now) {
        let items = [
            WatchPlanItem(itemSlug: "split-squat", name: "Split squat", doseKind: "reps", sets: 3, reps: 8, seconds: nil,
                          metres: nil, contacts: nil, restSec: 90, isDrill: false),
            WatchPlanItem(itemSlug: "nordic-hamstring-curl", name: "Nordic hamstring curl", doseKind: "reps", sets: 3, reps: 5,
                          seconds: nil, metres: nil, contacts: nil, restSec: 90, isDrill: false),
            WatchPlanItem(itemSlug: "copenhagen-plank", name: "Copenhagen plank", doseKind: "time", sets: 2, reps: nil, seconds: 20,
                          metres: nil, contacts: nil, restSec: 60, isDrill: false),
            WatchPlanItem(itemSlug: "a-skip", name: "A-skip", doseKind: "distance", sets: 3, reps: nil, seconds: nil,
                          metres: 20, contacts: nil, restSec: 60, isDrill: true),
        ]
        WatchTodayPayload(
            athleteId: "demo-athlete", appleUserId: "demo", birthDate: Calendar.current.date(byAdding: .year, value: -16, to: now) ?? now,
            sportSlug: "soccer", sportName: "Soccer", sessionToken: nil, day: now, sessionTitle: "Speed & strength",
            sessionMinutes: 32, items: items, nextGameDate: Calendar.current.date(byAdding: .day, value: 3, to: now),
            isGameDay: false, checkedInOnPhone: false
        ).saveOnDevice()
    }
}

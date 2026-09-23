import Foundation
import SwiftData

/// App Store screenshots and App Review need a believable, lived-in account
/// without anyone signing in. Only ever active when the process is launched
/// with `-demoData` (the screenshots workflow does this in a simulator); a
/// normal launch never passes that argument, so this can't touch real users.
@MainActor
public enum DemoData {
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    /// `-tab plan|improve|library|me` picks the starting tab for a screenshot.
    static var initialTab: AppTab {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-tab"), args.indices.contains(index + 1) else { return .today }
        switch args[index + 1] {
        case "plan": return .plan
        case "improve": return .improve
        case "library": return .library
        case "me": return .me
        default: return .today
        }
    }

    /// Seeds one soccer midfielder with three weeks of check-ins, logged
    /// sessions and two upcoming games — only if the store is empty.
    public static func seedIfNeeded(context: ModelContext, now: Date = .now) {
        guard isEnabled, ((try? context.fetchCount(FetchDescriptor<Athlete>())) ?? 0) == 0 else { return }
        let calendar = Calendar.current

        let athlete = Athlete(
            appleUserId: "demo", birthDate: calendar.date(byAdding: .year, value: -16, to: now) ?? now,
            trainsUnderCoach: true, equipmentAvailable: ["ball", "cones", "band", "med-ball", "box", "dumbbell", "goal"]
        )
        context.insert(athlete)
        let seasonStart = calendar.date(byAdding: .day, value: -20, to: now) ?? now
        let seasonEnd = calendar.date(byAdding: .day, value: 60, to: now) ?? now
        context.insert(AthleteSport(sportSlug: "soccer", positionSlug: "midfielder", seasonStart: seasonStart, seasonEnd: seasonEnd, isPrimary: true, athlete: athlete))

        for days in [3, 10] {
            if let date = calendar.date(byAdding: .day, value: days, to: now) {
                context.insert(Competition(sportSlug: "soccer", date: date, kind: .game, isHome: days == 3, notes: days == 3 ? "vs. Central" : "Away at Westfield", athlete: athlete))
            }
        }

        // Check-ins: a realistic personal baseline, so readiness is live.
        let sleep = [4, 3, 4, 5, 3, 4, 4, 3, 5, 4, 4, 3, 4, 4, 5, 3, 4, 4, 3, 4]
        for (offset, value) in sleep.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: -(offset + 1), to: calendar.startOfDay(for: now)) else { continue }
            let soreness: Int = 2 + offset % 3
            let energy: Int = 3 + (offset + 1) % 3
            let stress: Int = 2 + offset % 2
            let checkIn = CheckIn(
                date: date, sleepQuality: value, soreness: soreness, energy: energy,
                stress: stress, readinessBand: .green, athlete: athlete
            )
            context.insert(checkIn)
        }

        // Logged sessions with sets and a rising squat, for the charts.
        let plan: [DemoSession] = [
            DemoSession(daysAgo: 2, minutes: 48, rpe: 7, sets: [
                DemoSet("goblet-squat", 8, 16), DemoSet("goblet-squat", 8, 16),
                DemoSet("soccer-plant-and-strike", 6), DemoSet("soccer-plant-and-strike", 6),
            ]),
            DemoSession(daysAgo: 5, minutes: 42, rpe: 6, sets: [
                DemoSet("soccer-cone-dribble-slalom", 4), DemoSet("soccer-arrowhead-agility", 4), DemoSet("goblet-squat", 8, 14),
            ]),
            DemoSession(daysAgo: 7, minutes: 55, rpe: 8, sets: [
                DemoSet("goblet-squat", 8, 14), DemoSet("soccer-finishing-under-fatigue", 6), DemoSet("soccer-repeated-40-yard-sprints", 6),
            ]),
            DemoSession(daysAgo: 9, minutes: 38, rpe: 5, sets: [
                DemoSet("soccer-first-touch-wall-rebounds", nil), DemoSet("soccer-driven-pass-gates", 10),
            ]),
            DemoSession(daysAgo: 12, minutes: 50, rpe: 7, sets: [
                DemoSet("goblet-squat", 8, 12), DemoSet("soccer-instep-drive-progression", 8),
            ]),
            DemoSession(daysAgo: 14, minutes: 45, rpe: 6, sets: [
                DemoSet("soccer-target-corner-shooting", 10), DemoSet("goblet-squat", 8, 12),
            ]),
            DemoSession(daysAgo: 16, minutes: 40, rpe: 6, sets: [DemoSet("soccer-one-v-one-channel", 6)]),
            DemoSession(daysAgo: 19, minutes: 52, rpe: 7, sets: [
                DemoSet("goblet-squat", 8, 10), DemoSet("soccer-crossing-from-wide", 8),
            ]),
        ]
        for entry in plan {
            guard let start = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now).flatMap({
                calendar.date(bySettingHour: 16, minute: 30, second: 0, of: $0)
            }) else { continue }
            let session = Session(
                startedAt: start, endedAt: start.addingTimeInterval(Double(entry.minutes) * 60),
                sessionRPE: entry.rpe, minutes: entry.minutes, source: .phone, syncedAt: start, athlete: athlete
            )
            context.insert(session)
            for (index, set) in entry.sets.enumerated() {
                context.insert(SetLog(itemSlug: set.slug, setIndex: index, reps: set.reps, weightKg: set.weightKg, session: session))
            }
        }
        try? context.save()
    }
}

private struct DemoSet {
    let slug: String
    let reps: Int?
    let weightKg: Double?

    init(_ slug: String, _ reps: Int?, _ weightKg: Double? = nil) {
        self.slug = slug
        self.reps = reps
        self.weightKg = weightKg
    }
}

private struct DemoSession {
    let daysAgo: Int
    let minutes: Int
    let rpe: Int
    let sets: [DemoSet]
}

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
            context.insert(CheckIn(
                date: date, sleepQuality: value, soreness: 2 + offset % 3, energy: 3 + (offset + 1) % 3,
                stress: 2 + offset % 2, readinessBand: .green, syncedAt: nil, athlete: athlete
            ))
        }

        // Logged sessions with sets and a rising squat, for the charts.
        let plan: [(daysAgo: Int, minutes: Int, rpe: Int, sets: [(String, Int?, Double?)])] = [
            (2, 48, 7, [("goblet-squat", 8, 16), ("goblet-squat", 8, 16), ("soccer-plant-and-strike", 6, nil), ("soccer-plant-and-strike", 6, nil)]),
            (5, 42, 6, [("soccer-cone-dribble-slalom", 4, nil), ("soccer-arrowhead-agility", 4, nil), ("goblet-squat", 8, 14)]),
            (7, 55, 8, [("goblet-squat", 8, 14), ("soccer-finishing-under-fatigue", 6, nil), ("soccer-repeated-40-yard-sprints", 6, nil)]),
            (9, 38, 5, [("soccer-first-touch-wall-rebounds", nil, nil), ("soccer-driven-pass-gates", 10, nil)]),
            (12, 50, 7, [("goblet-squat", 8, 12), ("soccer-instep-drive-progression", 8, nil)]),
            (14, 45, 6, [("soccer-target-corner-shooting", 10, nil), ("goblet-squat", 8, 12)]),
            (16, 40, 6, [("soccer-one-v-one-channel", 6, nil)]),
            (19, 52, 7, [("goblet-squat", 8, 10), ("soccer-crossing-from-wide", 8, nil)]),
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
                context.insert(SetLog(itemSlug: set.0, setIndex: index, reps: set.1, weightKg: set.2, session: session))
            }
        }
        try? context.save()
    }
}

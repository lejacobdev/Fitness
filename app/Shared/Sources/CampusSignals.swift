import Foundation

/// The athlete's recent days, for Campus recommendations (§16).
@MainActor
enum LessonSignals {
    static func gameYesterday(_ athlete: Athlete, calendar: Calendar = .current) -> Bool {
        athlete.competitions.contains { calendar.isDateInYesterday($0.date) }
    }

    static func hardDayYesterday(calendar: Calendar = .current) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else { return false }
        return (MindsetStore.reflection(on: yesterday, calendar: calendar)?.hardness ?? 0) >= 4
    }

    static func shortNights(_ athlete: Athlete, calendar: Calendar = .current) -> Int {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        return athlete.checkIns.filter { $0.date >= weekAgo && ($0.sleepHours ?? 8) < 7 }.count
    }

    static func lowConfidence(calendar: Calendar = .current) -> Bool {
        let recent = MindsetStore.reflections.prefix(7)
        return recent.filter { $0.needsWork?.contains("Confidence") == true }.count >= 2
    }

    static func inSeason(_ athlete: Athlete) -> Bool {
        guard let sport = athlete.activeSport else { return false }
        return PhaseCalculator.phase(today: .now, seasonStart: sport.seasonStart, seasonEnd: sport.seasonEnd) == .inSeason
    }
}

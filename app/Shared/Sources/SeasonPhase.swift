import Foundation

/// §10's four training phases.
public enum SeasonPhase: String, Sendable, Codable, CaseIterable {
    case offSeason = "OFF_SEASON"
    case preSeason = "PRE_SEASON"
    case inSeason = "IN_SEASON"
    case postSeason = "POST_SEASON"
}

/// §10 describes the four phases with qualitative ranges ("3–8 weeks out",
/// "2–4 weeks after the last game"), not hard day-counts tied to a specific
/// field. This implementation anchors them to the athlete's own declared
/// season window (`AthleteSport.seasonStart`/`seasonEnd`) rather than
/// inferring a competition cadence from scattered `Competition` rows, which
/// would be fragile with a sparse calendar and, more importantly, is a
/// different concern: §10's day-by-day game-week taper (M7) already owns
/// competition-proximity logic at the SESSION level. This function answers
/// a coarser question — which phase governs the whole week — from a field
/// that already exists on the model for exactly this purpose.
public enum PhaseCalculator {
    public static func phase(
        today: Date, seasonStart: Date, seasonEnd: Date, calendar: Calendar = .current
    ) -> SeasonPhase {
        let today = calendar.startOfDay(for: today)
        let start = calendar.startOfDay(for: seasonStart)
        let end = calendar.startOfDay(for: seasonEnd)

        if today >= start && today <= end {
            return .inSeason
        }
        if today < start {
            let daysOut = calendar.dateComponents([.day], from: today, to: start).day ?? Int.max
            return daysOut <= 8 * 7 ? .preSeason : .offSeason
        }
        let daysSince = calendar.dateComponents([.day], from: end, to: today).day ?? Int.max
        return daysSince <= 4 * 7 ? .postSeason : .offSeason
    }
}

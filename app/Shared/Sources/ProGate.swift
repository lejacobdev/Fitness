import Foundation

/// §4's free vs Pro table as pure, testable rules. Everything that makes the
/// app a daily habit — the check-in, today's session and the plan, logging,
/// the Watch, fuelling, and account deletion — is free forever and is listed
/// here only so a test can prove it can never be gated by accident.
public enum ProFeature: String, CaseIterable, Sendable {
    // Free forever (§4, §20).
    case checkIn, weeklyPlan, logging, watch, fuelling, accountDeletion, coachWeeklyReport

    // Limited on free, unlimited on Pro.
    case skillBlocks
    case additionalSportDownloads
    case fullHistory
    case fullSeasonCalendar
    case positionProfiles
    case coachReportOnDemand
    case dataExport
    case multipleSports
    case muscleWorkouts
    case exerciseProgress
    case shareWorkouts

    /// Available to every athlete regardless of subscription.
    public var isFreeForever: Bool {
        switch self {
        case .checkIn, .weeklyPlan, .logging, .watch, .fuelling, .accountDeletion, .coachWeeklyReport: true
        default: false
        }
    }

    /// Plain words for the paywall's feature list and upsell cards.
    public var proDescription: String {
        switch self {
        case .skillBlocks: "Unlimited skill plans"
        case .additionalSportDownloads: "Every sport downloaded for offline use"
        case .fullHistory: "Your whole history and every trend"
        case .fullSeasonCalendar: "Full season calendar, tournaments and multi-game weeks"
        case .positionProfiles: "Every position profile, switchable"
        case .coachReportOnDemand: "A coach report after every session"
        case .dataExport: "Export all your data"
        case .multipleSports: "Play several sports — switch between them any time"
        case .muscleWorkouts: "Unlimited muscle-group workouts"
        case .exerciseProgress: "Progress charts for every exercise"
        case .shareWorkouts: "Share your workouts with a code, link or QR code"
        default: ""
        }
    }
}

public enum ProLimits {
    /// §4: "Named skill menu — 3 skill blocks per month" on free.
    public static let freeSkillBlocksPerMonth = 3
    /// §4: "History and trends — last 30 days" on free.
    public static let freeHistoryDays = 30
    /// §4 / §23: "A free user always has one sport downloaded."
    public static let freeDownloadedSports = 1
    /// Sports on a free account; more than one is Pro.
    public static let freeSports = 1
    /// Muscle-group workouts a free athlete can start per calendar week.
    public static let freeMuscleWorkoutsPerWeek = 1
    /// Times a free athlete can change their sport per calendar month.
    public static let freeSportSwitchesPerMonth = 3
}

public enum ProGate {
    /// The server's `proUntil` (pulled, never written, by the client — §18)
    /// or a live StoreKit entitlement that hasn't reached the server yet
    /// (e.g. an Ask to Buy approval that just landed).
    public static func isPro(proUntil: Date?, hasActiveSubscription: Bool = false, now: Date = .now) -> Bool {
        if hasActiveSubscription { return true }
        guard let proUntil else { return false }
        return proUntil > now
    }

    /// Features with no count or window to check.
    public static func isAvailable(_ feature: ProFeature, isPro: Bool) -> Bool {
        feature.isFreeForever || isPro
    }

    /// Skill blocks saved in the current calendar month count toward the
    /// free allowance. `nil` means unlimited.
    public static func remainingSkillBlocks(
        isPro: Bool, savedBlockDates: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Int? {
        guard !isPro else { return nil }
        let thisMonth = savedBlockDates.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }.count
        return max(0, ProLimits.freeSkillBlocksPerMonth - thisMonth)
    }

    public static func canSaveSkillBlock(
        isPro: Bool, savedBlockDates: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Bool {
        (remainingSkillBlocks(isPro: isPro, savedBlockDates: savedBlockDates, now: now, calendar: calendar) ?? 1) > 0
    }

    /// The earliest date history screens show. `nil` means everything.
    public static func historyCutoff(isPro: Bool, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard !isPro else { return nil }
        return calendar.date(byAdding: .day, value: -ProLimits.freeHistoryDays, to: calendar.startOfDay(for: now))
    }

    public static func canDownloadAnotherSport(isPro: Bool, downloadedSportCount: Int) -> Bool {
        isPro || downloadedSportCount < ProLimits.freeDownloadedSports
    }

    /// §4: free keeps the taper for the next game only.
    public static func competitionsForTaper(_ dates: [Date], isPro: Bool, now: Date = .now, calendar: Calendar = .current) -> [Date] {
        guard !isPro else { return dates }
        let today = calendar.startOfDay(for: now)
        let past = dates.filter { calendar.startOfDay(for: $0) < today }
        let next = dates.filter { calendar.startOfDay(for: $0) >= today }.min()
        // The most recent past game still drives post-game recovery.
        let lastPast = past.max()
        return [lastPast, next].compactMap { $0 }
    }

    public static func canAddSport(isPro: Bool, currentSportCount: Int) -> Bool {
        isPro || currentSportCount < ProLimits.freeSports
    }

    /// Sport changes left this calendar month on free. `nil` means unlimited.
    public static func remainingSportSwitches(
        isPro: Bool, switchDates: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Int? {
        guard !isPro else { return nil }
        let thisMonth = switchDates.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }.count
        return max(0, ProLimits.freeSportSwitchesPerMonth - thisMonth)
    }

    /// Muscle workouts started this calendar week count toward the free
    /// allowance. `nil` means unlimited.
    public static func remainingMuscleWorkouts(
        isPro: Bool, startDates: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Int? {
        guard !isPro else { return nil }
        let thisWeek = startDates.filter { calendar.isDate($0, equalTo: now, toGranularity: .weekOfYear) }.count
        return max(0, ProLimits.freeMuscleWorkoutsPerWeek - thisWeek)
    }
}

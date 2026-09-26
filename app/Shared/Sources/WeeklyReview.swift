import Foundation
import SwiftUI

/// Sunday's weekly review: what you did, one highlight, and next week's
/// focus. Pure summary here; the card is on Home on Sundays.
public struct WeeklyReview: Sendable, Equatable {
    public var workouts: Int
    public var minutes: Int
    public var checkIns: Int
    public var lessons: Int
    public var highlight: String
    public var focus: String

    public struct Input: Sendable {
        public var sessionDates: [Date]
        public var sessionMinutes: [Int]
        public var checkInDates: [Date]
        public var lessonsThisWeek: Int
        public var newBests: [String]
        public var streak: Int
        public var gamesNextWeek: Int
        public var deloadNextWeek: Bool
        public var phase: SeasonPhase?
        public var goal: String?

        public init(sessionDates: [Date], sessionMinutes: [Int], checkInDates: [Date], lessonsThisWeek: Int, newBests: [String],
                    streak: Int, gamesNextWeek: Int, deloadNextWeek: Bool, phase: SeasonPhase?, goal: String?) {
            self.sessionDates = sessionDates
            self.sessionMinutes = sessionMinutes
            self.checkInDates = checkInDates
            self.lessonsThisWeek = lessonsThisWeek
            self.newBests = newBests
            self.streak = streak
            self.gamesNextWeek = gamesNextWeek
            self.deloadNextWeek = deloadNextWeek
            self.phase = phase
            self.goal = goal
        }
    }

    /// The last seven days up to `now`.
    public static func make(_ input: Input, now: Date, calendar: Calendar = .current) -> WeeklyReview {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let inWeek = { (date: Date) in date >= start && date <= now }
        let sessions = zip(input.sessionDates, input.sessionMinutes).filter { inWeek($0.0) }
        let checkIns = Set(input.checkInDates.filter(inWeek).map { calendar.startOfDay(for: $0) }).count

        let highlight: String
        if let best = input.newBests.first {
            highlight = "A new personal best: \(best)."
        } else if checkIns == 7 {
            highlight = "You checked in every day this week."
        } else if input.streak >= 7 {
            highlight = "\(input.streak) days in a row."
        } else if sessions.count >= 3 {
            highlight = "\(sessions.count) workouts: a full week."
        } else if input.lessonsThisWeek >= 3 {
            highlight = "\(input.lessonsThisWeek) Campus lessons this week."
        } else if !sessions.isEmpty {
            highlight = "You trained \(sessions.count == 1 ? "once" : "\(sessions.count) times"). Every session counts."
        } else {
            highlight = "A quiet week. Rest is part of the plan too."
        }

        let focus: String
        if input.deloadNextWeek {
            focus = "Next week is a deload: lighter on purpose, so you come back stronger."
        } else if input.gamesNextWeek > 0 {
            focus = "\(input.gamesNextWeek == 1 ? "A game" : "\(input.gamesNextWeek) games") next week: sleep well and arrive fresh."
        } else if let goal = input.goal {
            focus = "Keep working towards your goal: \(goal)."
        } else if checkIns < 4 {
            focus = "Check in every morning: it lets the plan fit how you feel."
        } else if let phase = input.phase {
            focus = phase.focus
        } else {
            focus = "Keep the rhythm: train, recover, repeat."
        }

        return WeeklyReview(workouts: sessions.count, minutes: sessions.reduce(0) { $0 + $1.1 }, checkIns: checkIns,
                            lessons: input.lessonsThisWeek, highlight: highlight, focus: focus)
    }
}

/// The weekly review, shown on Home on Sundays.
struct WeeklyReviewCard: View {
    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your week")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 10) {
                stat("\(review.workouts)", "workouts")
                stat("\(review.minutes)", "minutes")
                stat("\(review.checkIns)/7", "check-ins")
            }
            Label(review.highlight, systemImage: "star.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.ink)
            Label(review.focus, systemImage: "arrow.right.circle.fill")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(AppTheme.ink)
            Text(label).font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
    }
}

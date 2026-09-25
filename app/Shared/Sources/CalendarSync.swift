import CryptoKit
import Foundation
import SwiftData

/// Keeps the connected calendars current: downloads them (at most every few
/// hours, or right away after a change), and turns their games into the
/// app's games — with the real start time and home/away — so the plan
/// tapers before them like any game added by hand. Practices and exams are
/// read straight from the download by `PracticeSchedule` and `ScheduleStore`.
@MainActor
enum CalendarSync {
    static let refreshInterval: TimeInterval = 3 * 3600

    /// Returns whether anything was downloaded.
    @discardableResult
    static func refresh(athlete: Athlete, context: ModelContext, force: Bool = false,
                        session: URLSession = .shared, now: Date = .now) async -> Bool {
        let feeds = ScheduleStore.feeds
        var schedule = ScheduleStore.imported
        // Calendars that were disconnected leave nothing behind.
        let connected = Set(feeds.map(\.id))
        let removedAny = schedule.byFeed.keys.contains { !connected.contains($0) }
        schedule.byFeed = schedule.byFeed.filter { connected.contains($0.key) }
        guard !feeds.isEmpty else {
            if removedAny || !schedule.byFeed.isEmpty { ScheduleStore.imported = ImportedSchedule() }
            applyGames(ImportedSchedule(), athlete: athlete, context: context, now: now)
            return false
        }
        let missing = feeds.contains { schedule.byFeed[$0.id] == nil }
        if !force, !missing, !removedAny, let fetched = schedule.fetchedAt, now.timeIntervalSince(fetched) < refreshInterval {
            return false
        }

        var downloaded = false
        for feed in feeds {
            // A calendar that can't be reached keeps its last download.
            if let events = try? await feed.fetchEvents(session: session, now: now) {
                schedule.byFeed[feed.id] = events
                downloaded = true
            }
        }
        guard !athlete.isDeleted else { return false }
        if downloaded { schedule.fetchedAt = now }
        ScheduleStore.imported = schedule
        applyGames(schedule, athlete: athlete, context: context, now: now)
        return downloaded
    }

    /// Imported games become `Competition`s with ids made from the event,
    /// so re-importing (or importing on a second phone) never duplicates
    /// one. A game that disappears from the calendar or gets cancelled is
    /// removed; past games are left alone.
    static func applyGames(_ schedule: ImportedSchedule, athlete: Athlete, context: ModelContext, now: Date = .now,
                           calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let sportSlug = athlete.activeSport?.sportSlug ?? athlete.sports.first?.sportSlug ?? ""
        let hidden = ScheduleStore.hiddenGameIDs
        var wanted: [String: ScheduleEvent] = [:]
        for game in schedule.games where game.start >= today {
            let id = competitionID(for: game)
            if !hidden.contains(id) { wanted[id] = game }
        }
        for competition in athlete.competitions where competition.id.hasPrefix(idPrefix) && competition.date >= today && wanted[competition.id] == nil {
            context.delete(competition)
        }
        for (id, game) in wanted {
            let kind = CompetitionKind(rawValue: game.competitionKind) ?? .game
            let notes = [game.title, game.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            if let existing = athlete.competitions.first(where: { $0.id == id }) {
                if existing.date != game.start { existing.date = game.start }
                if existing.kind != kind { existing.kind = kind }
                if existing.isHome == game.isAway { existing.isHome = !game.isAway }
                if existing.notes != notes { existing.notes = notes }
            } else {
                context.insert(Competition(id: id, sportSlug: sportSlug, date: game.start, kind: kind,
                                           isHome: !game.isAway, notes: notes, athlete: athlete))
            }
        }
        try? context.save()
    }

    static let idPrefix = "cal-"

    static func competitionID(for event: ScheduleEvent) -> String {
        idPrefix + SHA256.hash(data: Data(event.id.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// Whether a game came from a connected calendar (and is kept in sync by it).
    static func isImported(_ competition: Competition) -> Bool {
        competition.id.hasPrefix(idPrefix)
    }
}

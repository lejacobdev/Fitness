import CryptoKit
import Foundation
import SwiftData

/// Backs up everything the athlete builds up in the app and shares it
/// across their phones, so a new phone (or a reinstall) comes back exactly
/// as it was: profile, sports, games, saved skill plans, meals, and every
/// setting and bit of progress kept outside SwiftData (Campus XP and
/// lessons, day status, practice days, reminders, tips seen…).
///
/// Each piece is one JSON document on the server (`/sync/state`), last
/// write wins by `updatedAt`; settings are split into small groups
/// (`settings.campus`, `settings.schedule`…) so changes to different
/// things on two phones don't overwrite each other. This device remembers, per document, a hash
/// of what it last synced and when that version was written — a changed
/// hash means "edited here since", so the document gets a fresh timestamp
/// and is pushed; an unchanged one takes the server's copy if the server's
/// is newer. A document this device has never synced (new phone) always
/// takes the server's copy when there is one.
///
/// Check-ins and logged sessions already go up row by row (`SyncQueue`);
/// `restoreRows` brings them back down by `clientId`.
@MainActor
public enum CloudSync {
    // MARK: - What is backed up

    /// UserDefaults keys that belong to the athlete (not to this device).
    static let settingsKeys: Set<String> = [
        "dayStatus.v1", "reminderSettings", "home.introSeen", "home.layout", "appTourSeen", "gettingStartedHidden",
        "libraryOpened", "trainingStartMinutes", "gameStartMinutes", "weightUnit",
        "freeSportSwitchDates", "muscleWorkoutStarts",
    ]
    /// Whole families of athlete keys, including ones later features add.
    static let settingsPrefixes = ["campus.", "schedule.", "plans.", "progress.", "profile.", "tip.", "mindset.", "benchmark.", "calendar.", "safety.", "league."]

    static func isSettingKey(_ key: String) -> Bool {
        settingGroup(of: key) != nil
    }

    /// Settings are backed up in small groups (one document each), so a
    /// Campus lesson finished on one phone and practice days changed on
    /// another both survive.
    static func settingGroup(of key: String) -> String? {
        if let prefix = settingsPrefixes.first(where: { key.hasPrefix($0) }) { return String(prefix.dropLast()) }
        return settingsKeys.contains(key) ? "app" : nil
    }

    static var settingGroups: [String] { ["app"] + settingsPrefixes.map { String($0.dropLast()) } }

    /// Meals older than this aren't backed up (they don't change and would
    /// only grow the document).
    static let mealDays = 365

    private static let metaKey = "cloud.meta"
    private static let lastRowPullKey = "cloud.lastRowPull"

    // MARK: - Running a sync

    /// Pull, merge and push every document. Quietly does nothing when not
    /// signed in or offline; returns whether it reached the server.
    @discardableResult
    public static func sync(
        athlete: Athlete, context: ModelContext, apiClient: APIClient,
        tokenStore: any TokenStore = KeychainTokenStore(), now: Date = .now
    ) async -> Bool {
        guard !DemoData.isEnabled, let token = try? tokenStore.read() else { return false }
        guard let remote = try? await apiClient.fetchState(sessionToken: token) else { return false }
        // The fetch suspended; the athlete may have logged out meanwhile.
        guard !athlete.isDeleted, athlete.modelContext != nil else { return false }

        var meta = loadMeta()
        var toPush: [String: APIClient.SyncedDoc] = [:]
        for (key, local) in exportAll(athlete: athlete, now: now) {
            let hash = digest(local)
            let known = meta[key]
            let localStamp: Date? = known.map { $0.hash == hash ? $0.updatedAt : now }
            let server = remote[key]
            if let server, localStamp.map({ server.updatedAt > $0 }) ?? true {
                // A new phone, or another phone saved a newer copy: take it.
                apply(key, server.json, athlete: athlete, context: context, now: now)
                meta[key] = Meta(hash: digest(export(key, athlete: athlete, now: now)), updatedAt: server.updatedAt)
            } else if let stamp = localStamp ?? (server == nil ? now : nil), server.map({ stamp > $0.updatedAt }) ?? true {
                toPush[key] = .init(json: local, updatedAt: stamp)
            } else if let localStamp {
                meta[key] = Meta(hash: hash, updatedAt: localStamp)
            }
        }
        try? context.save()
        saveMeta(meta)

        guard !toPush.isEmpty else { return true }
        guard let winners = try? await apiClient.pushState(toPush, sessionToken: token) else { return false }
        guard !athlete.isDeleted, athlete.modelContext != nil else { return false }
        for (key, sent) in toPush {
            guard let winner = winners[key] else { continue }
            if winner.updatedAt.timeIntervalSince(sent.updatedAt) > 0.001 {
                // Another phone wrote a newer copy between our pull and push.
                apply(key, winner.json, athlete: athlete, context: context, now: now)
                meta[key] = Meta(hash: digest(export(key, athlete: athlete, now: now)), updatedAt: winner.updatedAt)
            } else {
                // Ours won. Remember the server's own timestamp (it keeps
                // milliseconds), so the next sync sees the two as equal.
                meta[key] = Meta(hash: digest(sent.json), updatedAt: winner.updatedAt)
            }
        }
        try? context.save()
        saveMeta(meta)
        return true
    }

    /// Brings logged sessions and check-ins down from the server and adds
    /// any this phone doesn't have (matched by `clientId`, marked synced so
    /// they're never pushed back). `full` fetches everything — a new phone;
    /// otherwise only the last two weeks, at most every few hours, so a
    /// workout logged on another phone shows up here too.
    public static func restoreRows(
        athlete: Athlete, context: ModelContext, apiClient: APIClient, full: Bool,
        tokenStore: any TokenStore = KeychainTokenStore(), now: Date = .now
    ) async {
        guard !DemoData.isEnabled, let token = try? tokenStore.read() else { return }
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: lastRowPullKey) as? Date
        if !full, let last, now.timeIntervalSince(last) < 4 * 3600 { return }
        let since = full ? nil : Calendar.current.date(byAdding: .day, value: -14, to: now)

        guard let checkIns = try? await apiClient.fetchCheckIns(since: since, sessionToken: token),
              let sessions = try? await apiClient.fetchSessions(since: since, sessionToken: token),
              !athlete.isDeleted, athlete.modelContext != nil else { return }
        mergeCheckIns(checkIns, into: athlete, context: context, now: now)
        mergeSessions(sessions, into: athlete, context: context, now: now)
        try? context.save()
        defaults.set(now, forKey: lastRowPullKey)
    }

    // MARK: - Rows

    static func mergeCheckIns(_ remote: [APIClient.RemoteCheckIn], into athlete: Athlete, context: ModelContext, now: Date, calendar: Calendar = .current) {
        let known = Set(athlete.checkIns.map(\.clientId))
        for row in remote where !known.contains(row.clientId) {
            guard let date = day(row.date, calendar: calendar) else { continue }
            // One check-in per day: a local one for the same day wins.
            if athlete.checkIns.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) { continue }
            let checkIn = CheckIn(
                date: date, sleepQuality: row.sleepQuality, sleepHours: row.sleepHours, soreness: row.soreness,
                sorenessAreas: row.sorenessAreas ?? [], energy: row.energy, stress: row.stress,
                readinessBand: row.readinessBand.flatMap(ReadinessBand.init(rawValue:)), readinessZ: row.readinessZ,
                clientId: row.clientId, athlete: athlete
            )
            checkIn.syncedAt = now
            context.insert(checkIn)
        }
    }

    static func mergeSessions(_ remote: [APIClient.RemoteSession], into athlete: Athlete, context: ModelContext, now: Date) {
        let known = Set(athlete.sessions.map(\.clientId))
        for row in remote where !known.contains(row.clientId) {
            guard let startedAt = APIClient.parseTimestamp(row.startedAt) else { continue }
            let session = Session(
                startedAt: startedAt, endedAt: row.endedAt.flatMap(APIClient.parseTimestamp),
                sessionRPE: row.sessionRPE, minutes: row.minutes,
                source: SessionSource(rawValue: row.source) ?? .phone,
                healthKitWorkoutId: row.healthKitWorkoutId, notes: row.notes,
                clientId: row.clientId, syncedAt: now, athlete: athlete
            )
            context.insert(session)
            for set in row.sets {
                context.insert(SetLog(
                    itemSlug: set.itemSlug, setIndex: set.setIndex, reps: set.reps, weightKg: set.weightKg,
                    seconds: set.seconds, distanceM: set.distanceM, contacts: set.contacts, side: set.side,
                    clientId: set.clientId, session: session
                ))
            }
        }
    }

    private static func day(_ string: String, calendar: Calendar) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // MARK: - Documents

    struct ProfileDoc: Codable, Equatable {
        var displayName: String?
        var birthDate: Date
        var unitSystem: String
        var trainsUnderCoach: Bool
        var equipmentAvailable: [String]
    }

    struct SportDoc: Codable, Equatable {
        var id: String
        var sportSlug: String
        var positionSlug: String?
        var formatSlug: String?
        var seasonStart: Date
        var seasonEnd: Date
        var isPrimary: Bool
    }

    struct CompetitionDoc: Codable, Equatable {
        var id: String
        var sportSlug: String
        var date: Date
        var kind: String
        var isHome: Bool
        var notes: String?
    }

    struct SkillBlockDoc: Codable, Equatable {
        var id: String
        var sportSlug: String
        var skillSlug: String
        var targetDate: Date
        var generatedAt: Date
        var seed: String
    }

    struct MealDoc: Codable, Equatable {
        var id: String
        var date: Date
        var slot: String
        var protein: Int
        var carbs: Int
        var colour: Int
        var water: Int
        var note: String?
        var clientId: String
    }

    /// A UserDefaults value in JSON: what `@AppStorage` and the stores here write.
    enum SettingValue: Codable, Equatable {
        case bool(Bool)
        case number(Double)
        case string(String)
        case strings([String])
        case numbers([Double])
        case data(Data)

        init?(_ object: Any) {
            switch object {
            case let data as Data: self = .data(data)
            case let string as String: self = .string(string)
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() { self = .bool(number.boolValue) }
                else if number.doubleValue.isFinite { self = .number(number.doubleValue) }
                else { return nil }
            case let strings as [String]: self = .strings(strings)
            case let numbers as [NSNumber] where numbers.allSatisfy({ $0.doubleValue.isFinite }): self = .numbers(numbers.map(\.doubleValue))
            default: return nil
            }
        }

        /// The value to put back into UserDefaults — whole numbers as Int so
        /// `integer(forKey:)` and `array(forKey:) as? [Int]` still work.
        var object: Any {
            switch self {
            case .bool(let value): return value
            case .number(let value): return Self.whole(value) ?? value
            case .string(let value): return value
            case .strings(let value): return value
            case .numbers(let values):
                let ints = values.compactMap(Self.whole)
                return ints.count == values.count ? ints as Any : values as Any
            case .data(let value): return value
            }
        }

        private static func whole(_ value: Double) -> Int? {
            value.rounded() == value && abs(value) < 9e15 ? Int(value) : nil
        }

        private enum CodingKeys: String, CodingKey { case bool, number, string, strings, numbers, data }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let v = try c.decodeIfPresent(Bool.self, forKey: .bool) { self = .bool(v) }
            else if let v = try c.decodeIfPresent(Double.self, forKey: .number) { self = .number(v) }
            else if let v = try c.decodeIfPresent(String.self, forKey: .string) { self = .string(v) }
            else if let v = try c.decodeIfPresent([String].self, forKey: .strings) { self = .strings(v) }
            else if let v = try c.decodeIfPresent([Double].self, forKey: .numbers) { self = .numbers(v) }
            else { self = .data(try c.decode(Data.self, forKey: .data)) }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .bool(let v): try c.encode(v, forKey: .bool)
            case .number(let v): try c.encode(v, forKey: .number)
            case .string(let v): try c.encode(v, forKey: .string)
            case .strings(let v): try c.encode(v, forKey: .strings)
            case .numbers(let v): try c.encode(v, forKey: .numbers)
            case .data(let v): try c.encode(v, forKey: .data)
            }
        }
    }

    static var documentKeys: [String] {
        ["profile", "sports", "competitions", "skillBlocks", "meals", "summary"] + settingGroups.map { "settings.\($0)" }
    }

    static func exportAll(athlete: Athlete, now: Date) -> [String: Data] {
        Dictionary(uniqueKeysWithValues: documentKeys.map { ($0, export($0, athlete: athlete, now: now)) })
    }

    static func export(_ key: String, athlete: Athlete, now: Date) -> Data {
        switch key {
        case "profile":
            return encode(ProfileDoc(
                displayName: athlete.displayName, birthDate: athlete.birthDate, unitSystem: athlete.unitSystem.rawValue,
                trainsUnderCoach: athlete.trainsUnderCoach, equipmentAvailable: athlete.equipmentAvailable.sorted()
            ))
        case "sports":
            return encode(athlete.sports.sorted { $0.id < $1.id }.map {
                SportDoc(id: $0.id, sportSlug: $0.sportSlug, positionSlug: $0.positionSlug, formatSlug: $0.formatSlug,
                         seasonStart: $0.seasonStart, seasonEnd: $0.seasonEnd, isPrimary: $0.isPrimary)
            })
        case "competitions":
            return encode(athlete.competitions.sorted { $0.id < $1.id }.map {
                CompetitionDoc(id: $0.id, sportSlug: $0.sportSlug, date: $0.date, kind: $0.kind.rawValue, isHome: $0.isHome, notes: $0.notes)
            })
        case "skillBlocks":
            return encode(athlete.skillBlocks.sorted { $0.id < $1.id }.map {
                SkillBlockDoc(id: $0.id, sportSlug: $0.sportSlug, skillSlug: $0.skillSlug, targetDate: $0.targetDate,
                              generatedAt: $0.generatedAt, seed: $0.seed)
            })
        case "meals":
            let cutoff = mealCutoff(now)
            return encode(athlete.mealLogs.filter { $0.date >= cutoff }.sorted { $0.id < $1.id }.map {
                MealDoc(id: $0.id, date: $0.date, slot: $0.slot.rawValue, protein: $0.proteinPortions, carbs: $0.carbPortions,
                        colour: $0.colourPortions, water: $0.hydrationGlasses, note: $0.note, clientId: $0.clientId)
            })
        case "summary":
            return encode(weekSummary(athlete: athlete, now: now))
        default:
            return encode(exportSettings(group: String(key.dropFirst("settings.".count))))
        }
    }

    /// This week in numbers, for the parent summary page (only numbers —
    /// never anything the athlete wrote). Read by the server, never applied
    /// back onto a phone.
    struct WeekSummaryDoc: Codable, Equatable {
        var week: String
        var campusLessons: Int
        var reflections: Int
        var focusDone: Int
        var focusTotal: Int
        var testHeadline: String?
    }

    static func weekSummary(athlete: Athlete, now: Date) -> WeekSummaryDoc {
        let focus = MindsetEngine.weeklyFocus(goals: MindsetStore.goals, weekStart: now)
        let tests = BenchmarkCatalog.tests(for: athlete.activeSport?.sportSlug)
        return WeekSummaryDoc(
            week: CampusLog.weekKey(now),
            campusLessons: CampusLog.lessons(inWeekOf: now),
            reflections: MindsetStore.reflectionDays(inWeekOf: now),
            focusDone: focus.filter { MindsetStore.isFocusDone($0.goal.id, week: now) }.count,
            focusTotal: focus.count,
            testHeadline: BenchmarkMath.headline(BenchmarkStore.results, tests: tests)
        )
    }

    static func exportSettings(group: String, _ defaults: UserDefaults = .standard) -> [String: SettingValue] {
        var out: [String: SettingValue] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where settingGroup(of: key) == group {
            if let setting = SettingValue(value) { out[key] = setting }
        }
        return out
    }

    static func apply(_ key: String, _ json: Data, athlete: Athlete, context: ModelContext, now: Date) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        switch key {
        case "profile":
            guard let doc = try? decoder.decode(ProfileDoc.self, from: json) else { return }
            athlete.displayName = doc.displayName
            athlete.birthDate = doc.birthDate
            athlete.unitSystem = UnitSystem(rawValue: doc.unitSystem) ?? athlete.unitSystem
            athlete.trainsUnderCoach = doc.trainsUnderCoach
            athlete.equipmentAvailable = doc.equipmentAvailable
        case "sports":
            guard let docs = try? decoder.decode([SportDoc].self, from: json) else { return }
            let ids = Set(docs.map(\.id))
            for sport in athlete.sports where !ids.contains(sport.id) { context.delete(sport) }
            for doc in docs {
                if let sport = athlete.sports.first(where: { $0.id == doc.id }) {
                    sport.sportSlug = doc.sportSlug
                    sport.positionSlug = doc.positionSlug
                    sport.formatSlug = doc.formatSlug
                    sport.seasonStart = doc.seasonStart
                    sport.seasonEnd = doc.seasonEnd
                    sport.isPrimary = doc.isPrimary
                } else {
                    context.insert(AthleteSport(
                        id: doc.id, sportSlug: doc.sportSlug, positionSlug: doc.positionSlug, formatSlug: doc.formatSlug,
                        seasonStart: doc.seasonStart, seasonEnd: doc.seasonEnd, isPrimary: doc.isPrimary, athlete: athlete
                    ))
                }
            }
        case "competitions":
            guard let docs = try? decoder.decode([CompetitionDoc].self, from: json) else { return }
            let ids = Set(docs.map(\.id))
            for competition in athlete.competitions where !ids.contains(competition.id) { context.delete(competition) }
            for doc in docs {
                let kind = CompetitionKind(rawValue: doc.kind) ?? .game
                if let existing = athlete.competitions.first(where: { $0.id == doc.id }) {
                    existing.sportSlug = doc.sportSlug
                    existing.date = doc.date
                    existing.kind = kind
                    existing.isHome = doc.isHome
                    existing.notes = doc.notes
                } else {
                    context.insert(Competition(id: doc.id, sportSlug: doc.sportSlug, date: doc.date, kind: kind,
                                               isHome: doc.isHome, notes: doc.notes, athlete: athlete))
                }
            }
        case "skillBlocks":
            guard let docs = try? decoder.decode([SkillBlockDoc].self, from: json) else { return }
            let ids = Set(docs.map(\.id))
            for block in athlete.skillBlocks where !ids.contains(block.id) { context.delete(block) }
            let existing = Set(athlete.skillBlocks.map(\.id))
            for doc in docs where !existing.contains(doc.id) {
                context.insert(SkillBlock(id: doc.id, sportSlug: doc.sportSlug, skillSlug: doc.skillSlug, targetDate: doc.targetDate,
                                          generatedAt: doc.generatedAt, seed: doc.seed, athlete: athlete))
            }
        case "summary":
            return
        case "meals":
            guard let docs = try? decoder.decode([MealDoc].self, from: json) else { return }
            let ids = Set(docs.map(\.id))
            let cutoff = mealCutoff(now)
            for meal in athlete.mealLogs where meal.date >= cutoff && !ids.contains(meal.id) { context.delete(meal) }
            for doc in docs {
                let slot = MealSlot(rawValue: doc.slot) ?? .snack
                if let meal = athlete.mealLogs.first(where: { $0.id == doc.id }) {
                    meal.date = doc.date
                    meal.slot = slot
                    meal.proteinPortions = doc.protein
                    meal.carbPortions = doc.carbs
                    meal.colourPortions = doc.colour
                    meal.hydrationGlasses = doc.water
                    meal.note = doc.note
                } else {
                    context.insert(MealLog(id: doc.id, date: doc.date, slot: slot, proteinPortions: doc.protein, carbPortions: doc.carbs,
                                           colourPortions: doc.colour, hydrationGlasses: doc.water, note: doc.note,
                                           clientId: doc.clientId, athlete: athlete))
                }
            }
        default:
            guard key.hasPrefix("settings."),
                  let settings = try? decoder.decode([String: SettingValue].self, from: json) else { return }
            applySettings(settings, group: String(key.dropFirst("settings.".count)))
        }
    }

    static func applySettings(_ settings: [String: SettingValue], group: String, to defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where settingGroup(of: key) == group && settings[key] == nil {
            defaults.removeObject(forKey: key)
        }
        for (key, value) in settings where settingGroup(of: key) == group {
            defaults.set(value.object, forKey: key)
        }
    }

    private static func mealCutoff(_ now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -mealDays, to: now) ?? now
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)) ?? Data("null".utf8)
    }

    // MARK: - Bookkeeping

    struct Meta: Codable, Equatable {
        var hash: String
        var updatedAt: Date
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func loadMeta() -> [String: Meta] {
        guard let data = UserDefaults.standard.data(forKey: metaKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Meta].self, from: data)) ?? [:]
    }

    private static func saveMeta(_ meta: [String: Meta]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(meta), forKey: metaKey)
    }
}

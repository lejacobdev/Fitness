import Foundation

/// §16: what the Watch needs to run today's session with no phone and no
/// signal — the athlete's identity, the session token for direct syncing,
/// and today's (readiness-adjusted) plan, flattened to plain values. Sent
/// from the phone over WatchConnectivity and kept on the Watch's own disk.
public struct WatchPlanItem: Codable, Sendable, Hashable {
    public var itemSlug: String
    public var name: String
    public var doseKind: String
    public var sets: Int
    public var reps: Int?
    public var seconds: Int?
    public var metres: Double?
    public var contacts: Int?
    public var restSec: Int
    public var isDrill: Bool

    public init(
        itemSlug: String, name: String, doseKind: String, sets: Int, reps: Int?, seconds: Int?,
        metres: Double?, contacts: Int?, restSec: Int, isDrill: Bool
    ) {
        self.itemSlug = itemSlug
        self.name = name
        self.doseKind = doseKind
        self.sets = sets
        self.reps = reps
        self.seconds = seconds
        self.metres = metres
        self.contacts = contacts
        self.restSec = restSec
        self.isDrill = isDrill
    }

    /// The single target number the Digital Crown adjusts for this dose.
    public var targetValue: Double {
        switch doseKind {
        case "reps": Double(reps ?? 8)
        case "time": Double(seconds ?? 30)
        case "distance": metres ?? 20
        case "contacts": Double(contacts ?? 10)
        default: Double(reps ?? 8)
        }
    }

    public var unitLabel: String {
        switch doseKind {
        case "time": "sec"
        case "distance": "m"
        case "contacts": "contacts"
        default: "reps"
        }
    }
}

public struct WatchTodayPayload: Codable, Sendable, Equatable {
    public var athleteId: String
    public var appleUserId: String
    public var birthDate: Date
    public var sportSlug: String
    public var sportName: String
    public var sessionToken: String?
    public var day: Date
    public var sessionTitle: String?
    public var sessionMinutes: Int?
    public var items: [WatchPlanItem]
    public var nextGameDate: Date?
    public var isGameDay: Bool
    public var checkedInOnPhone: Bool

    public init(
        athleteId: String, appleUserId: String, birthDate: Date, sportSlug: String, sportName: String,
        sessionToken: String?, day: Date, sessionTitle: String?, sessionMinutes: Int?, items: [WatchPlanItem],
        nextGameDate: Date?, isGameDay: Bool, checkedInOnPhone: Bool
    ) {
        self.athleteId = athleteId
        self.appleUserId = appleUserId
        self.birthDate = birthDate
        self.sportSlug = sportSlug
        self.sportName = sportName
        self.sessionToken = sessionToken
        self.day = day
        self.sessionTitle = sessionTitle
        self.sessionMinutes = sessionMinutes
        self.items = items
        self.nextGameDate = nextGameDate
        self.isGameDay = isGameDay
        self.checkedInOnPhone = checkedInOnPhone
    }

    /// Whether this payload's plan is for today (an old payload still
    /// carries a valid identity and token, just not today's session).
    public var isForToday: Bool { Calendar.current.isDateInToday(day) }

    static var deviceURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appending(path: "watch-today.json")
    }

    public static func loadFromDevice() -> WatchTodayPayload? {
        guard let data = try? Data(contentsOf: deviceURL) else { return nil }
        return try? JSONDecoder().decode(WatchTodayPayload.self, from: data)
    }

    public func saveOnDevice() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.deviceURL, options: .atomic)
    }

    /// Built on the phone from the same generated, taper- and
    /// readiness-adjusted session the Today tab shows.
    @MainActor
    public static func make(athlete: Athlete, week: GeneratedWeek?) -> WatchTodayPayload {
        let calendar = Calendar.current
        let checkIn = AthleteStats.todaysCheckIn(athlete)
        var session = week?.sessions.first { calendar.isDateInToday($0.date) }
        if let planned = session, let band = DailyLoop.todayBand(athlete) {
            session = ReadinessApplier.apply(to: planned, band: band).session
        }
        let catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
        let items = (session?.items ?? []).map { item -> WatchPlanItem in
            let catalogueItem = catalogue.item(item.itemSlug)
            return WatchPlanItem(
                itemSlug: item.itemSlug, name: catalogueItem?.name ?? displayName(forSlug: item.itemSlug),
                doseKind: item.dose.kind, sets: item.dose.sets, reps: item.dose.reps, seconds: item.dose.seconds,
                metres: item.dose.metres, contacts: item.dose.contacts, restSec: item.restSec,
                isDrill: catalogueItem?.kind == "drill"
            )
        }
        return WatchTodayPayload(
            athleteId: athlete.id, appleUserId: athlete.appleUserId, birthDate: athlete.birthDate,
            sportSlug: athlete.activeSport?.sportSlug ?? "", sportName: AthleteStats.sportName(athlete),
            sessionToken: try? KeychainTokenStore().read(), day: .now,
            sessionTitle: session?.title, sessionMinutes: session?.estimatedMinutes, items: items,
            nextGameDate: AthleteStats.upcomingCompetitions(athlete).first?.date,
            isGameDay: athlete.competitions.contains { calendar.isDateInToday($0.date) },
            checkedInOnPhone: checkIn != nil
        )
    }
}

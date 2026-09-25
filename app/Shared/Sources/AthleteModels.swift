import Foundation
import SwiftData

/// §14's athlete data — read-write, synced. SwiftData is the on-device
/// source of truth for the UI; backend/prisma/schema.prisma is the source of
/// truth for the account and the sync, with the same field names on both
/// sides "so the mapping is mechanical." Cascade rules here mirror
/// schema.prisma's `onDelete` exactly (checked against it directly, not
/// assumed) — every relationship is `.cascade` except Session's link to
/// PlannedSession, which is `.nullify`: a logged session survives its plan
/// being deleted or regenerated, just losing the link.
///
/// The catalogue (Sport, Item, Quality, Muscle, PosePair, Prop...) is
/// deliberately NOT modeled here. It is read-only, pack-delivered JSON (§3),
/// decoded straight into plain Codable structs — putting it in SwiftData
/// would create a second mutable copy of data that must never be user-edited.

public enum UnitSystem: String, Codable, Sendable {
    case metric = "METRIC"
    case imperial = "IMPERIAL"
}

public enum CompetitionKind: String, Codable, Sendable {
    case game = "GAME"
    case tournament = "TOURNAMENT"
    case meet = "MEET"
}

public enum SessionSource: String, Codable, Sendable {
    case phone = "PHONE"
    case watch = "WATCH"
}

public enum ReadinessBand: String, Codable, Sendable {
    case green = "GREEN"
    case amber = "AMBER"
    case red = "RED"
}

@Model
public final class Athlete {
    @Attribute(.unique) public var id: String
    /// The Apple `sub` and nothing else. No email, no name (§3).
    @Attribute(.unique) public var appleUserId: String
    public var displayName: String?
    public var birthDate: Date
    public var unitSystem: UnitSystem
    public var trainsUnderCoach: Bool
    public var equipmentAvailable: [String]
    /// Written ONLY by the App Store notification handler on the backend
    /// (§18) and pulled down through sync — never set directly on-device.
    public var proUntil: Date?
    public var originalTransactionId: String?
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AthleteSport.athlete)
    public var sports: [AthleteSport] = []
    @Relationship(deleteRule: .cascade, inverse: \Competition.athlete)
    public var competitions: [Competition] = []
    @Relationship(deleteRule: .cascade, inverse: \CheckIn.athlete)
    public var checkIns: [CheckIn] = []
    @Relationship(deleteRule: .cascade, inverse: \Plan.athlete)
    public var plans: [Plan] = []
    @Relationship(deleteRule: .cascade, inverse: \Session.athlete)
    public var sessions: [Session] = []
    @Relationship(deleteRule: .cascade, inverse: \SkillBlock.athlete)
    public var skillBlocks: [SkillBlock] = []
    @Relationship(deleteRule: .cascade, inverse: \CoachReport.athlete)
    public var coachReports: [CoachReport] = []
    @Relationship(deleteRule: .cascade, inverse: \MealLog.athlete)
    public var mealLogs: [MealLog] = []

    public init(
        id: String = UUID().uuidString, appleUserId: String, displayName: String? = nil,
        birthDate: Date, unitSystem: UnitSystem = .metric, trainsUnderCoach: Bool = false,
        equipmentAvailable: [String] = [], proUntil: Date? = nil,
        originalTransactionId: String? = nil, createdAt: Date = .now
    ) {
        self.id = id
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.birthDate = birthDate
        self.unitSystem = unitSystem
        self.trainsUnderCoach = trainsUnderCoach
        self.equipmentAvailable = equipmentAvailable
        self.proUntil = proUntil
        self.originalTransactionId = originalTransactionId
        self.createdAt = createdAt
    }
}

@Model
public final class AthleteSport {
    @Attribute(.unique) public var id: String
    public var sportSlug: String
    public var positionSlug: String?
    /// The sport's format (beach, sitting, wheelchair…); nil for the standard one.
    public var formatSlug: String?
    public var seasonStart: Date
    public var seasonEnd: Date
    public var isPrimary: Bool
    public var athlete: Athlete?

    public init(
        id: String = UUID().uuidString, sportSlug: String, positionSlug: String? = nil, formatSlug: String? = nil,
        seasonStart: Date, seasonEnd: Date, isPrimary: Bool = false, athlete: Athlete? = nil
    ) {
        self.id = id
        self.sportSlug = sportSlug
        self.positionSlug = positionSlug
        self.formatSlug = formatSlug
        self.seasonStart = seasonStart
        self.seasonEnd = seasonEnd
        self.isPrimary = isPrimary
        self.athlete = athlete
    }
}

/// Drives the taper in §10.
@Model
public final class Competition {
    @Attribute(.unique) public var id: String
    public var sportSlug: String
    public var date: Date
    public var kind: CompetitionKind
    public var isHome: Bool
    public var notes: String?
    public var athlete: Athlete?

    public init(
        id: String = UUID().uuidString, sportSlug: String, date: Date,
        kind: CompetitionKind, isHome: Bool = true, notes: String? = nil, athlete: Athlete? = nil
    ) {
        self.id = id
        self.sportSlug = sportSlug
        self.date = date
        self.kind = kind
        self.isHome = isHome
        self.notes = notes
        self.athlete = athlete
    }
}

@Model
public final class CheckIn {
    @Attribute(.unique) public var id: String
    /// §14: unique per athlete per day — enforced at the sync layer (SwiftData
    /// itself has no composite-unique constraint), so a second check-in the
    /// same day must UPDATE this row, never INSERT a new one. Corrupting that
    /// would corrupt every rolling baseline in §11.
    public var date: Date
    public var sleepQuality: Int
    public var sleepHours: Double?
    public var soreness: Int
    public var sorenessAreas: [String]
    public var energy: Int
    public var stress: Int
    public var readinessBand: ReadinessBand?
    public var readinessZ: Double?
    /// The idempotency key for the offline sync queue (§14).
    public var clientId: String
    /// Device-local bookkeeping, like `Session.syncedAt`: nil means "changed
    /// since the last successful push". Editing a check-in clears it again.
    public var syncedAt: Date?
    public var athlete: Athlete?

    public init(
        id: String = UUID().uuidString, date: Date, sleepQuality: Int, sleepHours: Double? = nil,
        soreness: Int, sorenessAreas: [String] = [], energy: Int, stress: Int,
        readinessBand: ReadinessBand? = nil, readinessZ: Double? = nil,
        clientId: String = UUID().uuidString, athlete: Athlete? = nil
    ) {
        self.id = id
        self.date = date
        self.sleepQuality = sleepQuality
        self.sleepHours = sleepHours
        self.soreness = soreness
        self.sorenessAreas = sorenessAreas
        self.energy = energy
        self.stress = stress
        self.readinessBand = readinessBand
        self.readinessZ = readinessZ
        self.clientId = clientId
        self.athlete = athlete
    }
}

@Model
public final class Plan {
    @Attribute(.unique) public var id: String
    public var weekStart: Date
    public var phase: String
    /// The §10 generator's seed — the same inputs always reproduce the same
    /// plan, so any generated week can be reproduced exactly from a bug report.
    public var seed: String
    public var generatedAt: Date
    public var athlete: Athlete?

    @Relationship(deleteRule: .cascade, inverse: \PlannedSession.plan)
    public var sessions: [PlannedSession] = []

    public init(
        id: String = UUID().uuidString, weekStart: Date, phase: String, seed: String,
        generatedAt: Date = .now, athlete: Athlete? = nil
    ) {
        self.id = id
        self.weekStart = weekStart
        self.phase = phase
        self.seed = seed
        self.generatedAt = generatedAt
        self.athlete = athlete
    }
}

@Model
public final class PlannedSession {
    @Attribute(.unique) public var id: String
    public var date: Date
    public var title: String
    public var focusQualities: [String]
    public var estimatedMinutes: Int
    public var plan: Plan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedItem.plannedSession)
    public var items: [PlannedItem] = []
    /// SetNull on the Postgres side — a logged Session survives its
    /// PlannedSession being deleted; SwiftData's `.nullify` is the same rule.
    @Relationship(deleteRule: .nullify, inverse: \Session.plannedSession)
    public var loggedSessions: [Session] = []

    public init(
        id: String = UUID().uuidString, date: Date, title: String,
        focusQualities: [String] = [], estimatedMinutes: Int, plan: Plan? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.focusQualities = focusQualities
        self.estimatedMinutes = estimatedMinutes
        self.plan = plan
    }
}

/// A dose is one of reps/time/distance/contacts (§7) — never all of them, but
/// SwiftData/Codable both want a concrete shape, so this carries every
/// possible field as optional rather than a Swift enum with associated
/// values, matching how it round-trips through the JSON packs and the sync
/// payload (a plain object with a `kind` discriminant, not a tagged union).
public struct Dose: Codable, Sendable, Hashable {
    public var kind: String // "reps" | "time" | "distance" | "contacts"
    public var sets: Int
    public var reps: Int?
    public var seconds: Int?
    public var metres: Double?
    public var contacts: Int?
    public var load: String?
    public var tempo: String?
    public var perSide: Bool?

    public init(
        kind: String, sets: Int, reps: Int? = nil, seconds: Int? = nil, metres: Double? = nil,
        contacts: Int? = nil, load: String? = nil, tempo: String? = nil, perSide: Bool? = nil
    ) {
        self.kind = kind
        self.sets = sets
        self.reps = reps
        self.seconds = seconds
        self.metres = metres
        self.contacts = contacts
        self.load = load
        self.tempo = tempo
        self.perSide = perSide
    }
}

@Model
public final class PlannedItem {
    @Attribute(.unique) public var id: String
    public var itemSlug: String
    public var order: Int
    public var dose: Dose
    public var restSec: Int
    /// §10: "the generator surfaces a plain reason for each item... written
    /// by the engine from the profile weights."
    public var rationale: String
    public var plannedSession: PlannedSession?

    public init(
        id: String = UUID().uuidString, itemSlug: String, order: Int, dose: Dose,
        restSec: Int, rationale: String, plannedSession: PlannedSession? = nil
    ) {
        self.id = id
        self.itemSlug = itemSlug
        self.order = order
        self.dose = dose
        self.restSec = restSec
        self.rationale = rationale
        self.plannedSession = plannedSession
    }
}

@Model
public final class Session {
    @Attribute(.unique) public var id: String
    public var startedAt: Date
    public var endedAt: Date?
    public var sessionRPE: Int?
    public var minutes: Int
    public var source: SessionSource
    /// §16: the Watch writes one HKWorkout and stores its UUID here so the
    /// phone can never write a second one for the same session.
    public var healthKitWorkoutId: String?
    public var notes: String?
    public var clientId: String
    /// §3/§21: nil means "not yet pushed to the backend" — SyncQueue's whole
    /// job. Device-local bookkeeping only; never synced itself (there is no
    /// server-side column for it), so it can't collide with the `clientId`
    /// idempotency key that actually protects the sync.
    public var syncedAt: Date?
    public var athlete: Athlete?
    public var plannedSession: PlannedSession?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    public var sets: [SetLog] = []

    public init(
        id: String = UUID().uuidString, startedAt: Date, endedAt: Date? = nil,
        sessionRPE: Int? = nil, minutes: Int = 0, source: SessionSource,
        healthKitWorkoutId: String? = nil, notes: String? = nil,
        clientId: String = UUID().uuidString, syncedAt: Date? = nil,
        athlete: Athlete? = nil, plannedSession: PlannedSession? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sessionRPE = sessionRPE
        self.minutes = minutes
        self.source = source
        self.healthKitWorkoutId = healthKitWorkoutId
        self.notes = notes
        self.clientId = clientId
        self.syncedAt = syncedAt
        self.athlete = athlete
        self.plannedSession = plannedSession
    }
}

@Model
public final class SetLog {
    @Attribute(.unique) public var id: String
    public var itemSlug: String
    public var setIndex: Int
    public var reps: Int?
    public var weightKg: Double?
    public var seconds: Int?
    public var distanceM: Double?
    public var contacts: Int?
    public var side: String?
    public var clientId: String
    public var session: Session?

    public init(
        id: String = UUID().uuidString, itemSlug: String, setIndex: Int, reps: Int? = nil,
        weightKg: Double? = nil, seconds: Int? = nil, distanceM: Double? = nil,
        contacts: Int? = nil, side: String? = nil, clientId: String = UUID().uuidString,
        session: Session? = nil
    ) {
        self.id = id
        self.itemSlug = itemSlug
        self.setIndex = setIndex
        self.reps = reps
        self.weightKg = weightKg
        self.seconds = seconds
        self.distanceM = distanceM
        self.contacts = contacts
        self.side = side
        self.clientId = clientId
        self.session = session
    }
}

/// The §8 skill-menu output, kept so it can be revisited.
@Model
public final class SkillBlock {
    @Attribute(.unique) public var id: String
    public var sportSlug: String
    public var skillSlug: String
    public var targetDate: Date
    public var generatedAt: Date
    public var seed: String
    public var athlete: Athlete?

    public init(
        id: String = UUID().uuidString, sportSlug: String, skillSlug: String,
        targetDate: Date, generatedAt: Date = .now, seed: String, athlete: Athlete? = nil
    ) {
        self.id = id
        self.sportSlug = sportSlug
        self.skillSlug = skillSlug
        self.targetDate = targetDate
        self.generatedAt = generatedAt
        self.seed = seed
        self.athlete = athlete
    }
}

@Model
public final class CoachReport {
    @Attribute(.unique) public var id: String
    public var weekStart: Date
    public var templateSetVersion: Int
    public var headline: String
    /// §12: observations/recommendations/templateIndexes are all
    /// engine-composed JSON — stored as their encoded JSON text here rather
    /// than a SwiftData-modeled structure, since their shape is small,
    /// display-only, and never queried against individually.
    public var observationsJSON: String
    public var recommendationsJSON: String
    public var encouragement: String
    public var templateIndexesJSON: String
    public var createdAt: Date
    public var athlete: Athlete?

    public init(
        id: String = UUID().uuidString, weekStart: Date, templateSetVersion: Int,
        headline: String, observationsJSON: String, recommendationsJSON: String,
        encouragement: String, templateIndexesJSON: String, createdAt: Date = .now,
        athlete: Athlete? = nil
    ) {
        self.id = id
        self.weekStart = weekStart
        self.templateSetVersion = templateSetVersion
        self.headline = headline
        self.observationsJSON = observationsJSON
        self.recommendationsJSON = recommendationsJSON
        self.encouragement = encouragement
        self.templateIndexesJSON = templateIndexesJSON
        self.createdAt = createdAt
        self.athlete = athlete
    }
}

/// Device-local only (§14) — never synced to the backend, since it just
/// records what this specific device has already downloaded.
@Model
public final class DownloadedPack {
    @Attribute(.unique) public var id: String
    public var packSlug: String
    public var version: Int
    public var downloadedAt: Date

    public init(id: String = UUID().uuidString, packSlug: String, version: Int, downloadedAt: Date = .now) {
        self.id = id
        self.packSlug = packSlug
        self.version = version
        self.downloadedAt = downloadedAt
    }
}

/// The SwiftData container's own schema list — every target that touches the
/// store (phone, watch) configures its `ModelContainer` from this one array,
/// so the two can never silently drift into incompatible schemas.
public let athleteModelTypes: [any PersistentModel.Type] = [
    Athlete.self, AthleteSport.self, Competition.self, CheckIn.self,
    Plan.self, PlannedSession.self, PlannedItem.self,
    Session.self, SetLog.self, SkillBlock.self, CoachReport.self, DownloadedPack.self,
    MealLog.self,
]

public extension Athlete {
    /// The sport the app is currently set to — plan, skills, drills and games
    /// all follow it. An athlete can play several; `isPrimary` marks the one
    /// switched to (the sport switcher sets it), with a stable fallback.
    var activeSport: AthleteSport? {
        sports.first(where: \.isPrimary) ?? sports.min { $0.sportSlug < $1.sportSlug }
    }

    /// Every sport this athlete plays, active one first, then by name.
    var sortedSports: [AthleteSport] {
        let active = activeSport?.id
        return sports.sorted {
            if ($0.id == active) != ($1.id == active) { return $0.id == active }
            return (allSportsBySlug[$0.sportSlug]?.name ?? $0.sportSlug) < (allSportsBySlug[$1.sportSlug]?.name ?? $1.sportSlug)
        }
    }

    /// Makes one sport the active one.
    func switchSport(to sport: AthleteSport) {
        for each in sports { each.isPrimary = each.id == sport.id }
    }
}

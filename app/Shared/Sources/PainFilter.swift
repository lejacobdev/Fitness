import Foundation

/// Reported pain decides what's trained today: nothing that loads a sore
/// area (§2: no session for that body area until the athlete clears it).
/// Leg pain takes out squats, lunges, jumps and sprints; each one is
/// swapped for an exercise with the same purpose that leaves the area
/// alone, or left out when there is none. Never a diagnosis.
public enum PainFilter {
    /// A muscle counts as loaded from this share of the work.
    static let threshold = 0.3

    static let quads: Set<String> = ["rectus-femoris", "vastus-lateralis", "vastus-medialis"]
    static let hamstrings: Set<String> = ["biceps-femoris", "semitendinosus", "semimembranosus"]
    static let calves: Set<String> = ["gastrocnemius", "soleus", "tibialis-anterior", "peroneals", "foot-intrinsics"]
    static let hips: Set<String> = ["gluteus-maximus", "gluteus-medius", "gluteus-minimus", "adductors", "iliopsoas",
                                    "deep-hip-rotators", "tensor-fasciae-latae"]

    /// The muscles each area covers.
    public static func muscles(for area: PainArea) -> Set<String> {
        switch area {
        case .leg: quads.union(hamstrings).union(calves).union(["adductors"])
        case .knee: quads.union(hamstrings).union(["gastrocnemius"])
        case .ankle: calves
        case .hip: hips.union(["rectus-femoris"])
        case .back: ["erector-spinae", "quadratus-lumborum", "multifidus"]
        case .shoulder: ["deltoid-anterior", "deltoid-lateral", "deltoid-posterior", "infraspinatus", "teres-minor", "teres-major",
                         "serratus-anterior", "pectoralis-major", "pectoralis-minor", "trapezius-upper"]
        case .arm: ["biceps-brachii", "triceps-brachii", "brachialis", "brachioradialis", "forearm-flexors", "forearm-extensors"]
        case .neck: ["neck-extensors", "sternocleidomastoid", "trapezius-upper", "levator-scapulae"]
        case .head, .other: []
        }
    }

    /// Pain in the lower body rules out jumping and running on it too.
    static func isLowerBody(_ area: PainArea) -> Bool {
        [.leg, .knee, .ankle, .hip].contains(area)
    }

    /// Whether the item loads any of these areas.
    public static func loads(_ item: CatalogueItem, areas: Set<PainArea>) -> Bool {
        guard !areas.isEmpty else { return false }
        let sore = areas.reduce(into: Set<String>()) { $0.formUnion(muscles(for: $1)) }
        if item.muscles.contains(where: { sore.contains($0.key) && $0.value >= threshold }) { return true }
        if areas.contains(where: isLowerBody), ["contacts", "distance"].contains(item.defaultDose.kind) { return true }
        return false
    }

    /// Today's session without anything that loads a sore area: swapped
    /// (via `replace`) where there's a fitting alternative, left out where not.
    public static func apply(to session: GeneratedSession, areas: Set<PainArea>, catalogue: Catalogue,
                             replace: (GeneratedPlannedItem, GeneratedSession) -> GeneratedPlannedItem?) -> GeneratedSession {
        guard !areas.isEmpty else { return session }
        var items: [GeneratedPlannedItem] = []
        for item in session.items {
            guard let catalogueItem = catalogue.item(item.itemSlug), loads(catalogueItem, areas: areas) else {
                items.append(item)
                continue
            }
            let current = GeneratedSession(date: session.date, title: session.title, focusQualities: session.focusQualities,
                                           estimatedMinutes: session.estimatedMinutes, items: items + session.items.filter { $0.order > item.order })
            if let swap = replace(item, current), let swapItem = catalogue.item(swap.itemSlug), !loads(swapItem, areas: areas) {
                items.append(swap)
            }
        }
        let ordered = items.enumerated().map { index, item in
            GeneratedPlannedItem(itemSlug: item.itemSlug, order: index, dose: item.dose, restSec: item.restSec,
                                 rationale: item.rationale, quality: item.quality)
        }
        let minutes = ordered.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) }
        var safe = GeneratedSession(date: session.date, title: session.title, focusQualities: session.focusQualities,
                                    estimatedMinutes: minutes, items: ordered)
        safe.slot = session.slot
        return safe
    }
}

/// Today's workouts with today's pain taken into account — the one place
/// Home, Workout, the Watch and the widget get them from.
@MainActor
enum TodaysPain {
    static func areas(now: Date = .now) -> Set<PainArea> {
        Set(PainStore.report(on: now)?.areas ?? [])
    }

    static func apply(_ session: GeneratedSession, athlete: Athlete, catalogue: Catalogue) -> GeneratedSession {
        let areas = areas()
        guard !areas.isEmpty else { return session }
        let input = WeeklyPlan.input(for: athlete, catalogue: catalogue, painAreas: areas)
        return PainFilter.apply(to: session, areas: areas, catalogue: catalogue) { item, current in
            input.flatMap { PlanGenerator.replacement(for: item, in: current, input: $0, turn: 0) }
        }
    }
}

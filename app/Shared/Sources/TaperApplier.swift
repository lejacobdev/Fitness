import Foundation

/// §10's game-day periodisation, applied as a second pass over
/// `PlanGenerator`'s output. A week generated with an empty competitions
/// list is untouched by this pass entirely (every session's stage is
/// `.normal`) — this only ever narrows or reschedules what M6 already built,
/// never invents new items.
public enum TaperApplier {
    public static func apply(
        to week: GeneratedWeek, competitions: [Date], contactLevel: String,
        calendar: Calendar = .current
    ) -> GeneratedWeek {
        let sessions = week.sessions.compactMap { session -> GeneratedSession? in
            let stage = TaperCalculator.stage(for: session.date, competitions: competitions, calendar: calendar)
            return transform(session, stage: stage, contactLevel: contactLevel)
        }
        return GeneratedWeek(phase: week.phase, weekStart: week.weekStart, sessions: sessions)
    }

    /// Returns nil to drop the day entirely (game day: "the warm-up
    /// sequence, nothing else" — not a prescribed training session).
    private static func transform(
        _ session: GeneratedSession, stage: TaperStage, contactLevel: String
    ) -> GeneratedSession? {
        switch stage {
        case .normal:
            return session

        case .gameDay:
            return nil

        case .lastHeavySession:
            // "Full intensity, reduced volume": keep dose intensity (reps/
            // load untouched), cut item count and set count.
            return rebuilt(
                session, title: "Last heavy session before game day",
                items: capped(session.items, maxCount: 2, halveSets: true)
            )

        case .qualityOverQuantity:
            // "short, sharp, technical. No lifting to failure": strength work
            // is exactly what "lifting to failure" describes, so it's the
            // one group explicitly excluded here.
            return rebuilt(
                session, title: "Sharp and technical — game in 2 days",
                items: capped(excluding(session.items, group: .strength), maxCount: 2, halveSets: true)
            )

        case .primer:
            return rebuilt(
                session, title: "Primer — not a hard session, game tomorrow",
                items: capped(preferring(session.items, groups: [.speed, .power]), maxCount: 1, halveSets: true)
            )

        case .betweenGames:
            return rebuilt(
                session, title: "Recovery and primer — two games this week",
                items: capped(preferring(session.items, groups: [.speed, .power]), maxCount: 1, halveSets: true)
            )

        case .postGameRecovery:
            // §10: "recovery emphasis, scaled by the sport's contactLevel —
            // a collision sport gets a genuinely easy day, a golf round does
            // not." COLLISION/CONTACT sports get the same light treatment as
            // a primer day; LIMITED backs off a little; NONE is left mostly
            // as generated, since a low-contact sport doesn't need to.
            switch contactLevel {
            case "COLLISION", "CONTACT":
                return rebuilt(
                    session, title: "Easy recovery day",
                    items: capped(preferring(session.items, groups: [.control]), maxCount: 1, halveSets: true)
                )
            case "LIMITED":
                return rebuilt(
                    session, title: "Light recovery day",
                    items: capped(session.items, maxCount: 2, halveSets: true)
                )
            default:
                return rebuilt(session, title: "Recovery day", items: session.items)
            }
        }
    }

    private static func rebuilt(_ session: GeneratedSession, title: String, items: [GeneratedPlannedItem]) -> GeneratedSession {
        GeneratedSession(
            date: session.date, title: title, focusQualities: session.focusQualities,
            estimatedMinutes: items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) },
            items: items, slot: session.slot
        )
    }

    private static func group(of item: GeneratedPlannedItem) -> QualityGroup? {
        qualitiesBySlug[item.quality]?.group
    }

    /// Never returns empty if the input wasn't — §3's "never an empty
    /// session" philosophy applies here too: a taper day that can't find its
    /// ideal quality group still trains something rather than nothing.
    private static func excluding(_ items: [GeneratedPlannedItem], group excluded: QualityGroup) -> [GeneratedPlannedItem] {
        let filtered = items.filter { group(of: $0) != excluded }
        return filtered.isEmpty ? items : filtered
    }

    private static func preferring(_ items: [GeneratedPlannedItem], groups: Set<QualityGroup>) -> [GeneratedPlannedItem] {
        let preferred = items.filter { group(of: $0).map { groups.contains($0) } ?? false }
        return preferred.isEmpty ? items : preferred
    }

    private static func capped(_ items: [GeneratedPlannedItem], maxCount: Int, halveSets: Bool) -> [GeneratedPlannedItem] {
        Array(items.prefix(maxCount)).enumerated().map { index, item in
            var dose = item.dose
            if halveSets { dose.sets = max(1, dose.sets / 2) }
            return GeneratedPlannedItem(
                itemSlug: item.itemSlug, order: index, dose: dose, restSec: item.restSec,
                rationale: item.rationale, quality: item.quality
            )
        }
    }
}

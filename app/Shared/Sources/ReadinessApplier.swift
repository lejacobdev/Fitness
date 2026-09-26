import Foundation

/// §11: "What readiness actually does. It adjusts today's session, visibly
/// and reversibly." Unlike `TaperApplier` (which reshapes the whole week
/// around a competition date, a schedule fact known days in advance),
/// readiness is a same-day biological signal — this only ever touches the
/// single `GeneratedSession` passed in, never the rest of the week, and the
/// caller (the Today tab) is what makes it reversible by keeping the
/// original session around for a one-tap override.
public enum ReadinessApplier {
    public struct Result: Sendable {
        public let session: GeneratedSession
        /// nil on green — "the plan as generated," nothing to say.
        public let reason: String?
    }

    public static func apply(to session: GeneratedSession, band: ReadinessBand) -> Result {
        switch band {
        case .green:
            return Result(session: session, reason: nil)

        case .amber:
            // "Volume trimmed ~20%, intensity held, plyometric contacts
            // cut." Reps/weight/seconds/distance (the intensity of a single
            // rep) are untouched; only the sets — the volume — and
            // plyometric contact counts are scaled down.
            let trimmed = session.items.map { item -> GeneratedPlannedItem in
                var dose = item.dose
                if dose.kind == plyometricDoseKind, let contacts = dose.contacts, contacts > 0 {
                    dose.contacts = max(1, Int((Double(contacts) * 0.8).rounded()))
                } else {
                    dose.sets = max(1, Int((Double(dose.sets) * 0.8).rounded()))
                }
                return GeneratedPlannedItem(
                    itemSlug: item.itemSlug, order: item.order, dose: dose, restSec: item.restSec,
                    rationale: item.rationale, quality: item.quality
                )
            }
            return Result(
                session: rebuilt(session, title: session.title, items: trimmed),
                reason: "Your check-in is a bit below your normal today, so today's volume is trimmed about 20% and plyometric work is cut back. Intensity is unchanged."
            )

        case .red:
            // "The session becomes movement, mobility and an early night...
            // this is the training decision, not a punishment." Prefer
            // whatever control-group (mobility/prehab) items the session
            // already selected; fall back to one lightened item from
            // whatever it has rather than leaving the day completely empty.
            let mobility = preferring(session.items, group: .control)
            let items = capped(mobility.isEmpty ? session.items : mobility, maxCount: 2, halveSets: true)
            return Result(
                session: rebuilt(session, title: "Movement and mobility — an easy day", items: items),
                reason: "Your check-in is well below your normal today, so today is movement, mobility and an early night instead of a full session. This is a training decision, not a punishment — you can still do the original session if you'd rather."
            )
        }
    }

    private static func rebuilt(_ session: GeneratedSession, title: String, items: [GeneratedPlannedItem]) -> GeneratedSession {
        GeneratedSession(
            date: session.date, title: title, focusQualities: session.focusQualities,
            estimatedMinutes: items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) },
            items: items, slot: session.slot
        )
    }

    private static func preferring(_ items: [GeneratedPlannedItem], group target: QualityGroup) -> [GeneratedPlannedItem] {
        items.filter { qualitiesBySlug[$0.quality]?.group == target }
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

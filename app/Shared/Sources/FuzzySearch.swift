import Foundation

/// Search that understands what people mean, used by every search box.
///
/// Each thing searched has weighted fields (name, sport, skills, muscles,
/// equipment, description…). A query word matches a field word when it is
/// the same word, the start of it, a near-miss typo, a synonym, or — weakly —
/// part of a longer word. Every query word must match somewhere; results are
/// ranked by how well. So "ice" lists ice hockey and skating first, and
/// "triceps dips" (which only contains "ice" mid-word) far below.
enum FuzzySearch {
    struct Field: Sendable {
        let words: [String]
        let weight: Double
        /// Typo tolerance is only worth it (and only cheap) on short fields.
        let fuzzy: Bool

        init(_ text: String, weight: Double, fuzzy: Bool = true) {
            words = FuzzySearch.words(text)
            self.weight = weight
            self.fuzzy = fuzzy
        }

        init(_ texts: [String], weight: Double, fuzzy: Bool = true) {
            self.init(texts.joined(separator: " "), weight: weight, fuzzy: fuzzy)
        }
    }

    /// Lowercased, accent-free words ("Ice-hockey's" → ["ice", "hockey", "s"]).
    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Relevance of `fields` for the query (nil when some query word matches nothing).
    static func score(_ query: String, _ fields: [Field]) -> Double? {
        let terms = words(query)
        guard !terms.isEmpty else { return 0 }
        var total = 0.0
        for term in terms {
            var best = 0.0
            for (alt, factor) in expansions(of: term) {
                for field in fields {
                    for word in field.words {
                        let m = match(alt, word, fuzzy: field.fuzzy) * factor * field.weight
                        if m > best { best = m }
                    }
                }
            }
            guard best > 0 else { return nil }
            total += best
        }
        // The whole query starting the first field (usually the name) ranks first.
        if let name = fields.first, name.words.joined(separator: " ").hasPrefix(terms.joined(separator: " ")) { total += 1 }
        return total
    }

    /// `items` that match, best first (ties keep the given order).
    static func rank<T>(_ items: [T], query: String, fields: (T) -> [Field]) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.enumerated()
            .compactMap { index, item in score(trimmed, fields(item)).map { (item, $0, index) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .map(\.0)
    }

    // MARK: Matching

    static func match(_ q: String, _ w: String, fuzzy: Bool) -> Double {
        if w == q { return 1 }
        if q.count >= 2, w.hasPrefix(q) { return 0.9 }
        if fuzzy, q.count >= 4 {
            let allowed = q.count >= 7 ? 2 : 1
            // A typo in a whole word ("hokey") or in the start of one ("basketbal").
            if abs(w.count - q.count) <= allowed, editDistance(q, w, limit: allowed) <= allowed { return 0.7 }
            if w.count > q.count, editDistance(q, String(w.prefix(q.count)), limit: allowed) <= allowed { return 0.6 }
        }
        if q.count >= 3, w.contains(q) { return 0.2 }
        return 0
    }

    /// Levenshtein distance, giving up early past `limit`.
    static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            var rowMin = cur[0]
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                rowMin = min(rowMin, cur[j])
            }
            if rowMin > limit { return limit + 1 }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    // MARK: Synonyms

    /// The term itself, plus what people mean by it (weighted a little lower).
    static func expansions(of term: String) -> [(String, Double)] {
        [(term, 1)] + (synonyms[term] ?? []).map { ($0, 0.85) }
    }

    static let synonyms: [String: [String]] = {
        let groups: [[String]] = [
            ["abs", "core", "abdominals", "abdominal", "trunk", "stomach", "obliques", "plank"],
            ["legs", "leg", "quads", "quadriceps", "hamstrings", "glutes", "calves", "squat", "lunge"],
            ["arms", "arm", "biceps", "triceps", "forearm", "forearms"],
            ["chest", "pecs", "pectoralis", "push"],
            ["back", "lats", "latissimus", "rhomboids", "trapezius", "row", "pull"],
            ["shoulders", "shoulder", "delts", "deltoid", "deltoids"],
            ["butt", "glutes", "gluteus", "hips", "hip"],
            ["cardio", "conditioning", "endurance", "aerobic", "running", "run", "stamina"],
            ["speed", "sprint", "sprinting", "fast", "acceleration", "quickness"],
            ["jump", "jumping", "plyometric", "plyometrics", "plyo", "bound", "hop", "vertical"],
            ["stretch", "stretching", "mobility", "flexibility", "yoga"],
            ["strength", "strong", "power", "weights", "lifting"],
            ["agility", "footwork", "change", "direction", "cutting", "cut"],
            ["balance", "stability", "proprioception"],
            ["throw", "throwing", "pass", "passing"],
            ["kick", "kicking", "strike", "shot", "shooting"],
            ["skate", "skating", "skater", "ice", "rink"],
            ["hoops", "basketball"],
            ["footy", "soccer", "football"],
            ["gym", "barbell", "dumbbell", "kettlebell", "machine"],
            ["bodyweight", "home", "none", "noequipment"],
            ["swim", "swimming", "pool", "water"],
            ["bike", "cycling", "biking", "bicycle"],
            ["warmup", "warm", "activation", "prehab"],
            ["injury", "prevention", "prehab", "rehab"],
            ["keeper", "goalkeeper", "goalie", "goaltending", "goalkeeping"],
        ]
        var out: [String: [String]] = [:]
        for group in groups {
            for word in group { out[word, default: []] += group.filter { $0 != word } }
        }
        return out
    }()
}

// MARK: - What each kind of thing is searched by

enum CatalogueSearch {
    /// Items' search fields, built once each (searching runs on every keystroke).
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var fields: [String: [FuzzySearch.Field]] = [:]
        subscript(slug: String) -> [FuzzySearch.Field]? {
            get { lock.withLock { fields[slug] } }
            set { lock.withLock { fields[slug] = newValue } }
        }
    }
    private static let cache = Cache()

    /// An exercise or drill: name first, then its sport, skills, qualities,
    /// muscles, equipment and surface, then how it's done.
    static func fields(_ item: CatalogueItem) -> [FuzzySearch.Field] {
        if let hit = cache[item.slug] { return hit }
        let sport = item.itemSportSlug.map { [allSportsBySlug[$0]?.name ?? "", $0] } ?? []
        let strong = { (weights: [String: Double]) in weights.filter { $0.value >= 0.5 }.map(\.key) }
        let qualityNames = strong(item.qualities).flatMap { [qualitiesBySlug[$0]?.name ?? "", qualitiesBySlug[$0]?.shortName ?? "", $0] }
        let muscleNames = strong(item.muscles).flatMap { [musclesBySlug[$0]?.name ?? "", musclesBySlug[$0]?.plainName ?? ""] }
        let fields = [
            FuzzySearch.Field(item.name, weight: 3),
            FuzzySearch.Field(sport, weight: 2.4),
            FuzzySearch.Field(item.skills ?? [], weight: 1.8),
            FuzzySearch.Field(qualityNames, weight: 1.5),
            FuzzySearch.Field(muscleNames, weight: 1.4),
            FuzzySearch.Field(item.equipment + [item.surface, item.kind], weight: 1.3),
            FuzzySearch.Field(item.setup + item.execution + item.cues, weight: 0.5, fuzzy: false),
        ]
        cache[item.slug] = fields
        return fields
    }

    static func rank(_ items: [CatalogueItem], query: String) -> [CatalogueItem] {
        FuzzySearch.rank(items, query: query, fields: fields)
    }

    /// A sport: its name, then its positions, skills and governing bodies.
    static func fields(_ sport: SportInfo) -> [FuzzySearch.Field] {
        [
            FuzzySearch.Field(sport.name + " " + sport.slug, weight: 3),
            FuzzySearch.Field(sport.positions.map(\.name) + sport.skills.map(\.name), weight: 1.2),
            FuzzySearch.Field(sport.governing, weight: 0.8, fuzzy: false),
        ]
    }

    /// A named skill: its name, then the qualities it rests on.
    static func fields(_ skill: SportSkill) -> [FuzzySearch.Field] {
        [
            FuzzySearch.Field(skill.name, weight: 3),
            FuzzySearch.Field(skill.slug, weight: 2),
            FuzzySearch.Field(skill.qualityWeights.filter { $0.value >= 0.3 }.keys.flatMap { [qualitiesBySlug[$0]?.name ?? "", $0] }, weight: 1.2),
        ]
    }
}

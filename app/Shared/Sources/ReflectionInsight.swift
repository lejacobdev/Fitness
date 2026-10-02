import Foundation

/// After the evening reflection, sometimes one small thing back (docs/
/// VERSION-6.md §19): what changed in the plan because of the answers, or a
/// pattern worth noticing. Only when it's true — never filler, never praise
/// for its own sake.
public enum ReflectionInsight {
    /// `today` was just saved; `recent` are the days before it (any order).
    public static func make(today: Reflection, recent: [Reflection], practiceToday: Bool, lastShown: String? = nil) -> (key: String, text: String)? {
        let week = recent.filter { $0.day < today.day }.sorted { $0.day > $1.day }.prefix(6)
        var candidates: [(String, String)] = []

        if today.body == 4 {
            candidates.append(("hurt", "You said something hurt. Tomorrow's plan stays gentle until you say it's gone — and if it's sharp, swelling or getting worse, tell an adult tonight."))
        }
        if today.hardness == 4 {
            let usual = week.compactMap(\.hardness)
            let harder = usual.isEmpty || Double(usual.reduce(0, +)) / Double(usual.count) < 3.2
            candidates.append(("hard", practiceToday && harder
                ? "Practice felt harder than usual today. Tomorrow's supplemental session has been adjusted."
                : "Today felt very hard. Tomorrow's session is lighter, so the hard work turns into fitness."))
        }
        let tiredEvenings = ([today] + week.prefix(3)).filter { ($0.body ?? 0) == 3 }.count
        if tiredEvenings >= 3 {
            candidates.append(("tired", "You've felt very tired on three of the last four evenings. Tomorrow is lighter — and an early night will help more than anything in the gym."))
        }
        let greatPractices = ([today] + week).filter { $0.practice == 4 }.count
        if greatPractices >= 3, today.practice == 4 {
            candidates.append(("great", "You rated practice great \(greatPractices) times this week. What did you do differently? Worth writing down."))
        }
        for area in today.wentWell ?? [] where EveningOptions.areas.contains(area) {
            let times = ([today] + week).filter { $0.wentWell?.contains(area) == true }.count
            if times >= 3 {
                candidates.append(("well-\(area)", "\(area) went well \(times) times this week. That's a strength you're building — keep doing what's working."))
                break
            }
        }
        for area in today.needsWork ?? [] where EveningOptions.areas.contains(area) {
            let times = ([today] + week).filter { $0.needsWork?.contains(area) == true }.count
            if times >= 3 {
                candidates.append(("work-\(area)", "\(area) has come up as needing work \(times) times this week. Pick one small thing to try in the next practice."))
                break
            }
        }
        // The first one that wasn't just shown.
        return candidates.first { $0.0 != lastShown }.map { (key: $0.0, text: $0.1) }
    }
}

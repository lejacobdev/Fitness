import Foundation

/// Which parts of the app get used, counted on this phone only — no
/// identifiers, no timestamps, never uploaded or backed up. The athlete can
/// look at it and choose to send it with a support request.
public enum UsageCounts {
    static let key = "usage.counts"

    public static var all: [String: Int] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    public static func count(_ screen: String, _ defaults: UserDefaults = .standard) {
        var counts = (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
        counts[screen, default: 0] += 1
        defaults.set(counts, forKey: key)
    }

    /// Plain text, most used first.
    public static var summary: String {
        all.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}

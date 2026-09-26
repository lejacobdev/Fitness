import Foundation
import Observation

/// Every code in the app — a coach's team, a Campus league, a shared
/// workout — also works as a link that opens the app on the right screen:
///
///   https://api.lejacob.dev/fitness/team/ABC234   (web link: opens the app
///                                                  when installed, else a
///                                                  page with the code)
///   aos://ABC234, aos://team/ABC234               (direct app links)
///   athleteos://… (the same, long form)
///
/// A bare code (`aos://ABC234`) doesn't say what it is; the app asks the
/// server (`GET /codes/:code`) and then opens the team, league or workout.
public enum DeepLink: Hashable, Sendable {
    case team(String)
    case league(String)
    case workout(String)
    /// A code whose kind still has to be looked up.
    case code(String)

    public static let webBase = URL(string: "https://api.lejacob.dev/fitness")!
    public static let webHost = "api.lejacob.dev"
    public static let schemes: Set<String> = ["aos", "athleteos"]

    /// Codes are six characters without look-alikes (no 0/O, 1/I/L).
    static let alphabet = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    public var code: String {
        switch self {
        case .team(let c), .league(let c), .workout(let c), .code(let c): c
        }
    }

    var kindPath: String? {
        switch self {
        case .team: "team"
        case .league: "league"
        case .workout: "workout"
        case .code: nil
        }
    }

    /// The web link to send: opens the app when it's installed.
    public var webURL: URL {
        webBaseURL.appending(path: kindPath ?? "c").appending(path: code)
    }

    /// The direct app link: `aos://team/ABC234` (or `aos://ABC234`).
    public var appURL: URL {
        URL(string: "aos://\(kindPath.map { "\($0)/" } ?? "")\(code)")!
    }

    private var webBaseURL: URL { Self.webBase }

    /// A code as typed or pasted: trimmed, upper-cased, spaces and dashes
    /// removed. Nil unless it's a valid six-character code.
    public static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == 6, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// What a code field got: a code, or a pasted link to one.
    public static func code(fromInput raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil, let link = DeepLink(url: url) { return link.code }
        return normalize(trimmed)
    }

    public init?(url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        var parts: [String]
        if Self.schemes.contains(scheme) {
            // aos://team/ABC234 → host "team", path "/ABC234"; aos://ABC234 → host "ABC234".
            parts = ([url.host(percentEncoded: false) ?? ""] + url.pathComponents).filter { !$0.isEmpty && $0 != "/" }
        } else if scheme == "https" || scheme == "http", url.host(percentEncoded: false)?.lowercased() == Self.webHost {
            parts = url.pathComponents.filter { $0 != "/" }
            guard parts.first == "fitness" else { return nil }
            parts.removeFirst()
        } else {
            return nil
        }
        switch parts.count {
        case 1:
            guard let code = Self.normalize(parts[0]) else { return nil }
            self = .code(code)
        case 2:
            guard let code = Self.normalize(parts[1]) else { return nil }
            switch parts[0].lowercased() {
            case "team", "t": self = .team(code)
            case "league", "l": self = .league(code)
            case "workout", "w": self = .workout(code)
            case "c", "code", "join": self = .code(code)
            default: return nil
            }
        default:
            return nil
        }
    }

    /// The same link once the kind is known (from `GET /codes/:code`).
    public static func resolved(code: String, kind: String) -> DeepLink? {
        switch kind {
        case "team": .team(code)
        case "league": .league(code)
        case "workout": .workout(code)
        default: nil
        }
    }
}

/// The link the app was opened with, until the signed-in app shows it.
/// Opened before setup is finished, it waits (on disk) until it's done.
@MainActor
@Observable
public final class DeepLinkCenter {
    public static let shared = DeepLinkCenter()
    static let key = "deepLink.pending"

    public var pending: DeepLink?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key), let url = URL(string: raw) {
            pending = DeepLink(url: url)
        }
    }

    /// Called for every URL the app is opened with. False if it isn't ours.
    @discardableResult
    public func open(_ url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        pending = link
        UserDefaults.standard.set(link.appURL.absoluteString, forKey: Self.key)
        return true
    }

    /// The screen for the link is showing: forget it.
    public func handled() {
        pending = nil
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}

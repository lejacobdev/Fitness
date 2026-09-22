import Foundation

/// Identifiers shared by all four targets.
///
/// §16: the complication reads the shared App Group container. If the App Group
/// entitlement is missing from a target, `sharedContainer` returns nil and the
/// complication silently shows nothing — so the M0 placeholder screen reports
/// this value rather than assuming it.
public enum AppIdentifiers {
    public static let appGroup = "group.com.studentathlete.app"
    public static let bundlePrefix = "com.studentathlete.app"

    public static var sharedContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }
}

/// What the running binary can actually see. The M0 placeholder screen renders
/// this so the first TestFlight build proves the pipeline attached the
/// entitlements, rather than merely proving the app launches (§19).
public struct BuildEvidence {
    public let version: String
    public let build: String
    public let appGroupResolved: Bool
    public let entitlementsPresent: Bool

    public init() {
        let info = Bundle.main.infoDictionary
        version = info?["CFBundleShortVersionString"] as? String ?? "—"
        build = info?["CFBundleVersion"] as? String ?? "—"
        appGroupResolved = AppIdentifiers.sharedContainer != nil
        // A signed build carries an embedded provisioning profile; an unsigned
        // simulator build does not. Distinguishing the two on-screen is what
        // makes the M0 screenshot evidence instead of decoration.
        entitlementsPresent = Bundle.main.url(
            forResource: "embedded", withExtension: "mobileprovision"
        ) != nil
    }
}

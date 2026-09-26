import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The exercise animations. Every app version has them built in
/// (Generated/PosePatterns.swift), and the server publishes the current set
/// as packs/animations.json. When the downloaded set is newer and fits this
/// app's rig, it is used instead — so a fixed or re-assigned animation
/// reaches phones on the next launch, without a new build. Anything wrong
/// with a download (another rig version, missing keyframes, no connection)
/// leaves the built-in animations in place. It's data, not code: the rig and
/// its drawing stay in the app.
public struct AnimationPack: Codable, Sendable {
    public let version: String
    public let poseModelVersion: Int
    public let joints: [String]
    public let patterns: [PosePatternInfo]
    public let itemPoses: [String: String]
    public let legacy: [String: String]
}

public final class AnimationLibrary: @unchecked Sendable {
    public static let shared = AnimationLibrary()

    struct Snapshot {
        let version: String?
        let patterns: [PosePatternInfo]
        let bySlug: [String: PosePatternInfo]
        let itemPoses: [String: String]
        let legacy: [String: String]

        static let bundled = Snapshot(
            version: nil, patterns: bundledPosePatterns,
            bySlug: Dictionary(bundledPosePatterns.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            itemPoses: bundledPosePatternForItem, legacy: bundledLegacyPosePatterns
        )

        init(version: String?, patterns: [PosePatternInfo], bySlug: [String: PosePatternInfo],
             itemPoses: [String: String], legacy: [String: String]) {
            self.version = version
            self.patterns = patterns
            self.bySlug = bySlug
            self.itemPoses = itemPoses
            self.legacy = legacy
        }

        init(_ pack: AnimationPack) {
            self.init(
                version: pack.version, patterns: pack.patterns,
                bySlug: Dictionary(pack.patterns.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
                itemPoses: pack.itemPoses, legacy: pack.legacy
            )
        }
    }

    private let lock = NSLock()
    private var snapshot: Snapshot
    private let directory: URL?

    /// `directory` holds the downloaded set between launches (nil: memory only, for tests).
    init(directory: URL? = AnimationLibrary.defaultDirectory) {
        self.directory = directory
        snapshot = .bundled
        if let pack = readCached() { apply(pack, save: false) }
    }

    static var defaultDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "animations", directoryHint: .isDirectory)
    }

    // MARK: What the app draws

    /// The downloaded set's version, or nil when the built-in one is in use.
    public var version: String? { read { $0.version } }
    public var patterns: [PosePatternInfo] { read { $0.patterns } }
    public var patternsBySlug: [String: PosePatternInfo] { read { $0.bySlug } }
    public var itemPoses: [String: String] { read { $0.itemPoses } }
    public var legacy: [String: String] { read { $0.legacy } }

    private func read<T>(_ body: (Snapshot) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(snapshot)
    }

    // MARK: Using a downloaded set

    /// Why a downloaded set can't be used in this app version; nil when it can.
    public static func problem(with pack: AnimationPack) -> String? {
        guard pack.poseModelVersion == poseModelVersion else { return "made for rig model \(pack.poseModelVersion), this app has \(poseModelVersion)" }
        guard pack.joints == Joint.allCases.map(\.rawValue) else { return "different joints" }
        guard !pack.patterns.isEmpty else { return "no animations" }
        for pattern in pack.patterns {
            guard !pattern.keyframes.isEmpty else { return "\(pattern.id) has no keyframes" }
            guard pattern.keyframes.allSatisfy({ $0.angles.count == Joint.allCases.count }) else {
                return "\(pattern.id) has keyframes for another rig"
            }
        }
        return nil
    }

    /// Uses the set if it fits (and keeps it for the next launch); false if it doesn't.
    @discardableResult
    public func apply(_ pack: AnimationPack, save: Bool = true) -> Bool {
        guard Self.problem(with: pack) == nil else { return false }
        let next = Snapshot(pack)
        lock.lock()
        snapshot = next
        lock.unlock()
        if save { write(pack) }
        return true
    }

    /// Back to the animations built into this app version (and forget the download).
    public func useBuiltIn() {
        lock.lock()
        snapshot = .bundled
        lock.unlock()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    // MARK: Downloading

    /// Fetches the server's set when it changed since the last download (the
    /// server's ETag), and uses it if it fits. Quietly does nothing offline.
    public func refresh(packsBaseURL: URL, session: URLSession = .shared) async {
        var request = URLRequest(url: packsBaseURL.appending(path: "animations.json"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag = storedETag() { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let pack = try? JSONDecoder().decode(AnimationPack.self, from: data) else { return }
        // Remember what was fetched either way: a set made for a newer rig is
        // not downloaded again until the server's set changes.
        let usable = pack.version == version || apply(pack)
        storeETag(http.value(forHTTPHeaderField: "ETag"), usable: usable)
    }

    // MARK: On disk

    private var packURL: URL? { directory?.appending(path: "animations.json") }
    private var etagURL: URL? { directory?.appending(path: "etag") }
    /// Present when the last download didn't fit this app version.
    private var unusableURL: URL? { directory?.appending(path: "unusable") }

    private func readCached() -> AnimationPack? {
        guard let packURL, let data = try? Data(contentsOf: packURL) else { return nil }
        return try? JSONDecoder().decode(AnimationPack.self, from: data)
    }

    private func write(_ pack: AnimationPack) {
        guard let directory, let packURL, let data = try? JSONEncoder().encode(pack) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: packURL, options: .atomic)
    }

    /// Only when what that ETag names is in hand (in use, or known not to fit).
    private func storedETag() -> String? {
        guard let etagURL, let unusableURL else { return nil }
        guard version != nil || FileManager.default.fileExists(atPath: unusableURL.path()) else { return nil }
        return try? String(contentsOf: etagURL, encoding: .utf8)
    }

    private func storeETag(_ etag: String?, usable: Bool) {
        guard let etag, let directory, let etagURL, let unusableURL else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? etag.write(to: etagURL, atomically: true, encoding: .utf8)
        if usable {
            try? FileManager.default.removeItem(at: unusableURL)
        } else {
            try? Data().write(to: unusableURL)
        }
    }
}

// The animations the app draws — downloaded when newer, else built in.
public var posePatterns: [PosePatternInfo] { AnimationLibrary.shared.patterns }
public var posePatternsBySlug: [String: PosePatternInfo] { AnimationLibrary.shared.patternsBySlug }
/// Item slug → its movement pattern.
public var posePatternForItem: [String: String] { AnimationLibrary.shared.itemPoses }
/// Older pattern names (from packs downloaded before the 3D rig) → today's.
public var legacyPosePatterns: [String: String] { AnimationLibrary.shared.legacy }

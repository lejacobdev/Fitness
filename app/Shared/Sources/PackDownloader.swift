import CryptoKit
import Foundation
import SwiftData

/// §3's content-pack responsibility, client side. Downloads a pack, verifies
/// its SHA-256 against the manifest's own checksum (the same check
/// content/scripts/verify-packs.mjs runs server-side before a pack is ever
/// published — this is the client half of that same guarantee, not a
/// different one), and records a `DownloadedPack` row so the UI can show
/// what is actually available offline.
///
/// §3: "a free user always has at least one sport downloaded and fully
/// usable offline" — the core pack plus exactly one sport pack is the
/// minimum viable download, not the whole catalogue.
public struct PackManifestEntry: Codable, Sendable {
    public let slug: String
    public let version: Int
    public let file: String
    public let sizeBytes: Int
    public let checksum: String
}

public struct PackManifest: Codable, Sendable {
    public let generatedAt: String
    public let packs: [PackManifestEntry]
}

public enum PackDownloadError: Error, Sendable {
    case checksumMismatch(slug: String, expected: String, actual: String)
    case manifestEntryMissing(slug: String)
    case decodingFailed(slug: String)
}

public struct PackDownloader: Sendable {
    private let client: APIClient
    private let fileManager: FileManager
    private let packsDirectory: URL

    public init(client: APIClient, fileManager: FileManager = .default, packsDirectory: URL) {
        self.client = client
        self.fileManager = fileManager
        self.packsDirectory = packsDirectory
        try? fileManager.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
    }

    public func fetchManifest() async throws -> PackManifest {
        let data = try await client.fetchPackManifest()
        do {
            return try JSONDecoder().decode(PackManifest.self, from: data)
        } catch {
            throw PackDownloadError.decodingFailed(slug: "manifest")
        }
    }

    /// Downloads one pack, verifies its checksum against the manifest entry,
    /// and writes it to local storage only if the checksum matches — a
    /// corrupted or tampered download is never written to disk half-verified.
    @discardableResult
    public func download(slug: String, manifest: PackManifest) async throws -> URL {
        guard let entry = manifest.packs.first(where: { $0.slug == slug }) else {
            throw PackDownloadError.manifestEntryMissing(slug: slug)
        }
        let data = try await client.fetchPack(named: entry.file)

        let actualChecksum = sha256Hex(data)
        guard actualChecksum == entry.checksum else {
            throw PackDownloadError.checksumMismatch(slug: slug, expected: entry.checksum, actual: actualChecksum)
        }

        let destination = packsDirectory.appending(path: entry.file)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    /// Every pack file already present locally, from a previous successful
    /// `download(slug:manifest:)` — used to decide what still needs fetching
    /// without re-downloading everything on every launch.
    public func locallyAvailablePackFiles() -> Set<String> {
        let files = (try? fileManager.contentsOfDirectory(atPath: packsDirectory.path)) ?? []
        return Set(files)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Records what this device has downloaded (§14: "device-local only" — never
/// synced). Kept separate from `PackDownloader` itself so the download/verify
/// logic stays testable without a SwiftData `ModelContext`.
@MainActor
public struct DownloadedPackRecorder {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func record(slug: String, version: Int) throws {
        let descriptor = FetchDescriptor<DownloadedPack>(
            predicate: #Predicate { $0.packSlug == slug }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.version = version
            existing.downloadedAt = .now
        } else {
            context.insert(DownloadedPack(packSlug: slug, version: version))
        }
        try context.save()
    }

    public func isDownloaded(slug: String, atLeastVersion version: Int) throws -> Bool {
        let descriptor = FetchDescriptor<DownloadedPack>(
            predicate: #Predicate { $0.packSlug == slug }
        )
        guard let existing = try context.fetch(descriptor).first else { return false }
        return existing.version >= version
    }
}

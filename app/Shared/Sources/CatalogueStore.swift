import Foundation

/// A merged, queryable view over every pack currently downloaded (§3: "every
/// downloaded sport's full library... works offline always"). Built once
/// from whatever is on disk — however partial that is — never assumed to be
/// the whole catalogue.
public struct Catalogue: Sendable {
    public let itemsBySlug: [String: CatalogueItem]
    public let sportsBySlug: [String: SportInfo]

    public init(itemsBySlug: [String: CatalogueItem] = [:], sportsBySlug: [String: SportInfo] = [:]) {
        self.itemsBySlug = itemsBySlug
        self.sportsBySlug = sportsBySlug
    }

    public func item(_ slug: String) -> CatalogueItem? {
        itemsBySlug[slug]
    }
}

public enum CatalogueLoader {
    /// Decodes every `.json` pack file in `packsDirectory` (skipping
    /// `manifest.json`, which isn't a pack) into one merged `Catalogue`. A
    /// pack file that fails to decode — corrupted, mid-write, an unexpected
    /// future shape — is skipped rather than aborting the whole load: one
    /// bad file should never make every OTHER already-downloaded sport
    /// unusable, matching PackDownloader's own fail-closed-per-file design.
    public static func load(from packsDirectory: URL, fileManager: FileManager = .default) -> Catalogue {
        let files = (try? fileManager.contentsOfDirectory(
            at: packsDirectory, includingPropertiesForKeys: nil
        )) ?? []

        var itemsBySlug: [String: CatalogueItem] = [:]
        var sportsBySlug: [String: SportInfo] = [:]
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
            guard
                let data = try? Data(contentsOf: file),
                let pack = try? decoder.decode(CataloguePack.self, from: data)
            else { continue }

            for item in pack.items {
                itemsBySlug[item.slug] = item
            }
            if let sport = pack.sport {
                sportsBySlug[sport.slug] = sport
            }
        }

        return Catalogue(itemsBySlug: itemsBySlug, sportsBySlug: sportsBySlug)
    }
}

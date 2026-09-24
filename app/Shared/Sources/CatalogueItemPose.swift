import Foundation

public extension CatalogueItem {
    /// The movement pattern this item animates. The app's own table wins
    /// (so packs downloaded before a pose update still animate correctly),
    /// then the pack's pattern name, then its older name's replacement.
    var posePattern: PosePatternInfo? {
        for slug in [slug, baseSlug].compactMap({ $0 }) {
            if let name = posePatternForItem[slug], let pattern = posePatternsBySlug[name] { return pattern }
        }
        for name in [startPose, endPose] {
            if let pattern = posePatternsBySlug[name] { return pattern }
            if let newer = legacyPosePatterns[name], let pattern = posePatternsBySlug[newer] { return pattern }
        }
        return nil
    }

    /// The item's highest-weighted quality — what a list row labels it with.
    var primaryQuality: QualityInfo? {
        qualities.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }
            .flatMap { qualitiesBySlug[$0.key] }
    }
}

extension CatalogueItem: Identifiable {
    public var id: String { slug }
}

import Foundation

public extension CatalogueItem {
    /// The movement pattern this item animates (every item names exactly one).
    var posePattern: PosePatternInfo? {
        posePatternsBySlug[startPose] ?? posePatternsBySlug[endPose]
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

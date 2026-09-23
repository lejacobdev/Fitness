import Foundation

public extension CatalogueItem {
    /// Resolves this item's own animated pose pair from the two named
    /// patterns it references. `startPose`/`endPose` are pattern ids (e.g.
    /// "hinge", "instep-strike") — when both are the same id, the item plays
    /// that one pattern's own start-to-end motion; when they differ (e.g. a
    /// drill going from "vertical-jump" into "overhead-throw"), the item's
    /// start is the FIRST pattern's own start pose and its end is the
    /// SECOND pattern's own end pose, composing a single motion out of two
    /// named patterns rather than requiring a distinct pattern to be
    /// authored for every such combination.
    var posePair: (start: Pose, end: Pose)? {
        guard
            let startPattern = posePatternsBySlug[startPose],
            let endPattern = posePatternsBySlug[endPose]
        else { return nil }
        return (startPattern.start, endPattern.end)
    }
}

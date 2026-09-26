import XCTest

/// Exercise animations can be updated from the server without a new build;
/// a set that doesn't fit this app's rig is never used.
final class AnimationLibraryTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appending(path: "AnimationLibraryTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// A downloaded set like the server's, built from this app's own animations.
    private func pack(version: String = "test-1", poseModel: Int = poseModelVersion,
                      joints: [String] = Joint.allCases.map(\.rawValue), itemPoses: [String: String] = bundledPosePatternForItem) -> AnimationPack {
        AnimationPack(version: version, poseModelVersion: poseModel, joints: joints, patterns: bundledPosePatterns,
                      itemPoses: itemPoses, legacy: bundledLegacyPosePatterns)
    }

    func testStartsWithTheBuiltInAnimations() {
        let library = AnimationLibrary(directory: directory)
        XCTAssertNil(library.version)
        XCTAssertEqual(library.patterns.count, bundledPosePatterns.count)
        XCTAssertFalse(library.patterns.isEmpty)
    }

    func testADownloadedSetIsUsedAndKeptForTheNextLaunch() throws {
        let library = AnimationLibrary(directory: directory)
        let slug = try XCTUnwrap(bundledPosePatternForItem.keys.sorted().first)
        let other = try XCTUnwrap(bundledPosePatterns.first { $0.id != bundledPosePatternForItem[slug] }?.id)
        var reassigned = bundledPosePatternForItem
        reassigned[slug] = other
        XCTAssertTrue(library.apply(pack(itemPoses: reassigned)))
        XCTAssertEqual(library.version, "test-1")
        XCTAssertEqual(library.itemPoses[slug], other, "a re-assigned animation shows without a new build")
        XCTAssertEqual(AnimationLibrary(directory: directory).version, "test-1", "still there after a restart")
    }

    func testASetForAnotherRigIsNeverUsed() {
        let library = AnimationLibrary(directory: directory)
        XCTAssertFalse(library.apply(pack(poseModel: poseModelVersion + 1)))
        XCTAssertFalse(library.apply(pack(joints: ["pelvis"])))
        XCTAssertNil(library.version, "the built-in animations stay")
        XCTAssertNotNil(AnimationLibrary.problem(with: pack(poseModel: poseModelVersion + 1)))
        XCTAssertNil(AnimationLibrary.problem(with: pack()))
    }

    func testBackToTheBuiltInAnimations() {
        let library = AnimationLibrary(directory: directory)
        XCTAssertTrue(library.apply(pack()))
        library.useBuiltIn()
        XCTAssertNil(library.version)
        XCTAssertNil(AnimationLibrary(directory: directory).version, "forgotten on disk too")
    }
}

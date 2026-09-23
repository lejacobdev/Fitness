import XCTest

final class CatalogueStoreTests: XCTestCase {
    private func makeEmptyDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "catalogue-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let corePackJSON = """
    {
      "slug": "core", "version": 1, "generatedAt": "2026-01-01T00:00:00.000Z",
      "qualityModelVersion": 1, "muscleModelVersion": 1, "poseModelVersion": 1,
      "items": [
        {
          "slug": "acceleration-wall-drill", "name": "Acceleration Wall Drill", "kind": "exercise",
          "qualities": { "acceleration": 1 }, "muscles": { "gluteus-maximus": 0.8 },
          "equipment": ["wall"], "surface": "anywhere", "minAge": 13, "supervisionLevel": "SELF",
          "setup": ["Lean into a wall."], "execution": ["Drive the knee up."],
          "cues": ["Shin drives forward."], "mistakes": ["Bending at the waist."],
          "progressions": [], "regressions": [], "substitutes": [],
          "defaultDose": { "kind": "time", "sets": 3, "seconds": 20 },
          "restSeconds": 60, "startPose": "sprint-cycle", "endPose": "sprint-cycle"
        }
      ]
    }
    """

    private let basketballPackJSON = """
    {
      "slug": "basketball", "version": 1, "generatedAt": "2026-01-01T00:00:00.000Z",
      "qualityModelVersion": 1, "muscleModelVersion": 1, "poseModelVersion": 1,
      "sport": {
        "slug": "basketball", "name": "Basketball", "governing": ["NFHS"], "season": "WINTER",
        "monthRange": [11, 3], "qualityProfile": { "vertical-power": 0.9 },
        "positions": [], "skills": [{ "slug": "vertical-jump", "name": "Vertical jump", "qualityWeights": { "vertical-power": 1.0 } }],
        "commonLoadAreas": ["knees"], "contactLevel": "CONTACT",
        "typicalSessionLength": 90, "typicalWeeklyGames": 2
      },
      "items": [
        {
          "slug": "basketball-first-step-attack", "name": "First-Step Attack", "kind": "drill",
          "sport": "basketball", "qualities": { "acceleration": 0.9 }, "muscles": { "gluteus-maximus": 0.8 },
          "equipment": ["ball"], "prop": "ball-round", "surface": "court", "minAge": 13,
          "supervisionLevel": "SELF", "setup": ["Triple-threat stance."],
          "execution": ["Push off explosively."], "cues": ["First step is the biggest."],
          "mistakes": ["Standing tall in place."], "progressions": [], "regressions": [], "substitutes": [],
          "defaultDose": { "kind": "reps", "sets": 4, "reps": 5 },
          "restSeconds": 60, "startPose": "sprint-cycle", "endPose": "sprint-cycle"
        }
      ]
    }
    """

    func testLoadsAndMergesEveryPackInTheDirectory() throws {
        let dir = try makeEmptyDirectory()
        try Data(corePackJSON.utf8).write(to: dir.appending(path: "core.json"))
        try Data(basketballPackJSON.utf8).write(to: dir.appending(path: "basketball.json"))

        let catalogue = CatalogueLoader.load(from: dir)

        XCTAssertEqual(catalogue.itemsBySlug.count, 2)
        XCTAssertNotNil(catalogue.item("acceleration-wall-drill"))
        XCTAssertNotNil(catalogue.item("basketball-first-step-attack"))
        XCTAssertEqual(catalogue.sportsBySlug.count, 1)
        XCTAssertEqual(catalogue.sportsBySlug["basketball"]?.name, "Basketball")
    }

    func testManifestJSONIsSkippedRatherThanTreatedAsAPack() throws {
        let dir = try makeEmptyDirectory()
        try Data(corePackJSON.utf8).write(to: dir.appending(path: "core.json"))
        // manifest.json has no "items" key at all — decoding it as a
        // CataloguePack would fail anyway, but this proves it's skipped by
        // name rather than relying on that decode failure.
        try Data(#"{"generatedAt":"2026-01-01T00:00:00.000Z","packs":[]}"#.utf8)
            .write(to: dir.appending(path: "manifest.json"))

        let catalogue = CatalogueLoader.load(from: dir)

        XCTAssertEqual(catalogue.itemsBySlug.count, 1)
    }

    func testACorruptPackFileIsSkippedWithoutLosingTheOthers() throws {
        let dir = try makeEmptyDirectory()
        try Data(corePackJSON.utf8).write(to: dir.appending(path: "core.json"))
        try Data(basketballPackJSON.utf8).write(to: dir.appending(path: "basketball.json"))
        try Data("{ this is not valid json".utf8).write(to: dir.appending(path: "corrupted.json"))

        let catalogue = CatalogueLoader.load(from: dir)

        XCTAssertEqual(catalogue.itemsBySlug.count, 2)
    }

    func testAnEmptyOrMissingDirectoryYieldsAnEmptyCatalogueRatherThanThrowing() {
        let missing = FileManager.default.temporaryDirectory.appending(path: "does-not-exist-\(UUID().uuidString)")
        let catalogue = CatalogueLoader.load(from: missing)

        XCTAssertTrue(catalogue.itemsBySlug.isEmpty)
        XCTAssertTrue(catalogue.sportsBySlug.isEmpty)
    }
}

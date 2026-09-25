import XCTest

/// Decodes every pack the content build actually produced (content/dist,
/// built by CI before the tests run) through the app's own models. A shape
/// mismatch between content JSON and Swift — like `variant` once being
/// decoded as a String when packs carry an object — makes a whole pack fail
/// to decode on device, silently emptying the Library and every plan. This
/// makes that a loud test failure instead.
final class RealPackDecodingTests: XCTestCase {
    private var distDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // StudentAthleteTests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
            .appending(path: "content/dist")
    }

    func testEveryBuiltPackDecodesCompletely() throws {
        let files = try FileManager.default.contentsOfDirectory(at: distDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        XCTAssertEqual(files.count, allSports.count + 1, "expected the core pack plus one per sport")

        var totalItems = 0
        for file in files {
            let data = try Data(contentsOf: file)
            do {
                let pack = try JSONDecoder().decode(CataloguePack.self, from: data)
                totalItems += pack.items.count
            } catch {
                XCTFail("\(file.lastPathComponent) failed to decode: \(error)")
            }
        }
        XCTAssertGreaterThan(totalItems, 100)
    }

    func testTheLoaderSeesEveryItemFromTheRealPacks() throws {
        let catalogue = CatalogueLoader.load(from: distDirectory)
        XCTAssertGreaterThan(catalogue.itemsBySlug.count, 100)
        XCTAssertEqual(catalogue.sportsBySlug.count, allSports.count)
        XCTAssertTrue(catalogue.itemsBySlug.values.contains { $0.variant != nil }, "expanded variants must decode too")
    }
}

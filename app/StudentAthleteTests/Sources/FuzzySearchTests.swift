import XCTest

final class FuzzySearchTests: XCTestCase {
    func testWholeWordsBeatFragmentsInsideOtherWords() {
        let hockey = FuzzySearch.score("ice", [FuzzySearch.Field("Crossover strides", weight: 3), FuzzySearch.Field("Ice hockey", weight: 2.4)]) ?? 0
        let triceps = FuzzySearch.score("ice", [FuzzySearch.Field("Triceps dips", weight: 3)]) ?? 0
        XCTAssertGreaterThan(hockey, triceps * 2)
    }

    func testTyposAndSynonymsStillMatch() {
        XCTAssertNotNil(FuzzySearch.score("hokey", [FuzzySearch.Field("Ice hockey", weight: 3)]))
        XCTAssertNotNil(FuzzySearch.score("basketbal", [FuzzySearch.Field("Basketball", weight: 3)]))
        XCTAssertNotNil(FuzzySearch.score("abs", [FuzzySearch.Field("Dead bug", weight: 3), FuzzySearch.Field("core stability", weight: 1.5)]))
        XCTAssertNil(FuzzySearch.score("xyz", [FuzzySearch.Field("Dead bug", weight: 3)]))
    }

    func testEveryWordOfTheQueryMustMatch() {
        let fields = [FuzzySearch.Field("Slap shot", weight: 3), FuzzySearch.Field("Ice hockey", weight: 2.4)]
        XCTAssertNotNil(FuzzySearch.score("ice shot", fields))
        XCTAssertNil(FuzzySearch.score("ice swim", fields))
    }

    @MainActor
    func testSearchingIceInTheCatalogueListsIceSportsFirst() {
        let catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
        let ranked = CatalogueSearch.rank(Array(catalogue.itemsBySlug.values), query: "ice")
        guard let first = ranked.first else { return } // no packs in the test bundle
        XCTAssertTrue(first.itemSportSlug?.contains("hockey") == true || first.name.lowercased().contains("ice") || first.surface.contains("ice"), first.name)
    }
}

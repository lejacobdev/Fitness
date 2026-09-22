import XCTest

final class SeededGeneratorTests: XCTestCase {
    func testTheSameSeedProducesTheSameSequence() {
        var a = SeededGenerator(seed: "week-2026-01-05")
        var b = SeededGenerator(seed: "week-2026-01-05")

        let sequenceA = (0..<20).map { _ in a.next() }
        let sequenceB = (0..<20).map { _ in b.next() }

        XCTAssertEqual(sequenceA, sequenceB)
    }

    func testDifferentSeedsProduceDifferentSequences() {
        var a = SeededGenerator(seed: "week-2026-01-05")
        var b = SeededGenerator(seed: "week-2026-01-12")

        let sequenceA = (0..<20).map { _ in a.next() }
        let sequenceB = (0..<20).map { _ in b.next() }

        XCTAssertNotEqual(sequenceA, sequenceB)
    }

    /// A zero-hashing seed must not produce a degenerate all-zero stream —
    /// SplitMix64 never recovers from a zero state under its own update rule.
    func testAnEmptySeedStillProducesVariedOutput() {
        var generator = SeededGenerator(seed: "")
        let values = Set((0..<10).map { _ in generator.next() })
        XCTAssertGreaterThan(values.count, 1)
    }
}

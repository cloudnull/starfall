import XCTest
@testable import StarfallCore

/// Tests for the SeededRNG.
final class SeededRNGTests: XCTestCase {
    func testDeterministicSequence() {
        let rng1 = SeededRNG(seed: 42)
        let rng2 = SeededRNG(seed: 42)

        for _ in 0..<100 {
            XCTAssertEqual(rng1.next(), rng2.next())
        }
    }

    func testDifferentSeedsProduceDifferentSequences() {
        let rng1 = SeededRNG(seed: 1)
        let rng2 = SeededRNG(seed: 2)
        XCTAssertNotEqual(rng1.next(), rng2.next())
    }

    func testNextDoubleRange() {
        let rng = SeededRNG(seed: 12345)
        for _ in 0..<1000 {
            let v = rng.nextDouble()
            XCTAssert(v >= 0 && v < 1)
        }
    }

    func testNextIntRange() {
        let rng = SeededRNG(seed: 99)
        for _ in 0..<1000 {
            let v = rng.nextInt(upperBound: 100)
            XCTAssert(v >= 0 && v < 100)
        }
    }

    func testChooseFromNonEmptyArray() {
        let rng = SeededRNG(seed: 7)
        let items = [10, 20, 30, 40, 50]
        let chosen = rng.choose(from: items)
        XCTAssertTrue(items.contains(chosen))
    }

    func testStateReconstruction() {
        let rng = SeededRNG(seed: 42)
        _ = rng.next()
        _ = rng.next()
        let val1 = rng.next()

        let rng2 = SeededRNG(seed: 42)
        _ = rng2.next()
        _ = rng2.next()
        let val2 = rng2.next()

        XCTAssertEqual(val1, val2)
    }
}
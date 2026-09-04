import XCTest
@testable import StarfallCore

/// Tests for FixedTimestep.
final class FixedTimestepTests: XCTestCase {
    func testConstantRateProducesCorrectSteps() {
        let ft = FixedTimestep()
        let frameDuration = FixedTimestep.frameDuration

        var totalSteps = 0
        for _ in 0..<240 {
            let steps = ft.update(elapsed: frameDuration / 10)
            totalSteps += steps
        }

        XCTAssert(totalSteps >= 22 && totalSteps <= 24)
    }

    func testNoStepsWhenNoTimePassed() {
        let ft = FixedTimestep()
        let steps = ft.update(elapsed: 0)
        XCTAssertEqual(steps, 0)
    }

    func testInterpolationAlpha() {
        let ft = FixedTimestep()
        let frameDuration = FixedTimestep.frameDuration

        ft.update(elapsed: frameDuration * 0.5)
        XCTAssert(ft.interpolationAlpha >= 0 && ft.interpolationAlpha < 1)
    }

    func testFrameCountIncreases() {
        let ft = FixedTimestep()
        let frameDuration = FixedTimestep.frameDuration

        ft.update(elapsed: frameDuration)
        XCTAssert(ft.totalFrames >= 1)
    }

    func testReset() {
        var ft = FixedTimestep()
        ft.update(elapsed: FixedTimestep.frameDuration)
        ft.reset()
        XCTAssertEqual(ft.totalFrames, 0)
    }

    func testSimulationFPS() {
        XCTAssertEqual(FixedTimestep.simulationFPS, 24)
    }
}
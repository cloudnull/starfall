import XCTest
@testable import StarfallCore

/// Tests for Angle.
final class AngleTests: XCTestCase {
    func testRadiansToDegrees() {
        let a = Angle(degrees: 180)
        XCTAssertEqual(a.degrees, 180, accuracy: 0.001)
    }

    func testDirectionVector() {
        let a = Angle(0)
        let d = a.direction
        XCTAssertEqual(d.x, 1, accuracy: 0.001)
        XCTAssertEqual(d.y, 0, accuracy: 0.001)
    }

    func testNormalizedAngle() {
        let a = Angle(2 * .pi + 0.5)
        let n = a.normalized
        XCTAssert(n.radians >= -.pi && n.radians <= .pi)
    }

func testShipFacingSnap() {
        let step = ShipFacing.step.radians
        let angle = Angle(step * 0.1) // Very small offset, should snap to 0
        let snapped = ShipFacing.snap(angle)
        XCTAssertEqual(snapped.radians, 0, accuracy: 0.001)
    }
}
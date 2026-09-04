import XCTest
@testable import StarfallCore

/// Tests for the Vec2 struct.
final class Vec2Tests: XCTestCase {
    func testConstruction() {
        let v = Vec2(x: 3, y: 4)
        XCTAssertEqual(v.x, 3)
        XCTAssertEqual(v.y, 4)
    }

    func testAddition() {
        let a = Vec2(x: 1, y: 2)
        let b = Vec2(x: 3, y: 4)
        let sum = a + b
        XCTAssertEqual(sum.x, 4)
        XCTAssertEqual(sum.y, 6)
    }

    func testSubtraction() {
        let a = Vec2(x: 5, y: 7)
        let b = Vec2(x: 3, y: 4)
        let diff = a - b
        XCTAssertEqual(diff.x, 2)
        XCTAssertEqual(diff.y, 3)
    }

    func testScalarMultiplication() {
        let v = Vec2(x: 2, y: 3)
        let scaled = v * 4
        XCTAssertEqual(scaled.x, 8)
        XCTAssertEqual(scaled.y, 12)
    }

    func testLength() {
        let v = Vec2(x: 3, y: 4)
        XCTAssertEqual(v.length, 5, accuracy: 0.0001)
    }

    func testNormalization() {
        let v = Vec2(x: 3, y: 4)
        let n = v.normalized
        XCTAssertEqual(n.length, 1, accuracy: 0.0001)
    }

    func testZeroNormalization() {
        let v = Vec2.zero
        let n = v.normalized
        XCTAssertEqual(n, Vec2.zero)
    }

    func testDotProduct() {
        let a = Vec2(x: 1, y: 2)
        let b = Vec2(x: 3, y: 4)
        XCTAssertEqual(a.dot(b), 11)
    }

    func testPerpendicular() {
        let v = Vec2(x: 1, y: 0)
        let p = v.perpendicular
        XCTAssertEqual(p.x, 0)
        XCTAssertEqual(p.y, -1)
    }
}
import Foundation

/// Two-dimensional vector with floating-point components.
///
/// Used for positions, velocities, and forces throughout the simulation.
public struct Vec2: Hashable, Sendable, Codable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static var zero: Vec2 { Vec2(x: 0, y: 0) }

    public static func + (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func += (lhs: inout Vec2, rhs: Vec2) {
        lhs = lhs + rhs
    }

    public static func - (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func -= (lhs: inout Vec2, rhs: Vec2) {
        lhs = lhs - rhs
    }

    public static func * (lhs: Vec2, scalar: Double) -> Vec2 {
        Vec2(x: lhs.x * scalar, y: lhs.y * scalar)
    }

    public static func * (lhs: Double, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs * rhs.x, y: lhs * rhs.y)
    }

    public static func / (lhs: Vec2, scalar: Double) -> Vec2 {
        Vec2(x: lhs.x / scalar, y: lhs.y / scalar)
    }

    public static prefix func - (vector: Vec2) -> Vec2 {
        Vec2(x: -vector.x, y: -vector.y)
    }

    public var length: Double {
        (x * x + y * y).squareRoot()
    }

    public var lengthSquared: Double {
        x * x + y * y
    }

    public var normalized: Vec2 {
        let len = length
        guard len > 0 else { return .zero }
        return self / len
    }

    public func dot(_ other: Vec2) -> Double {
        x * other.x + y * other.y
    }

    /// Returns the perpendicular vector (rotated 90 degrees clockwise).
    public var perpendicular: Vec2 {
        Vec2(x: y, y: -x)
    }

    public var description: String {
        "(\(x), \(y))"
    }
}

/// Distance between two vectors.
public func distance(_ a: Vec2, _ b: Vec2) -> Double {
    (a - b).length
}
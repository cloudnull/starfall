import Foundation

/// An angle measured in radians.
///
/// Wraps Double to make angle operations explicit and safe.
public struct Angle: Hashable, Sendable, Codable {
    public var radians: Double

    public init(_ radians: Double) {
        self.radians = radians
    }

    public init(degrees: Double) {
        self.radians = degrees * .pi / 180
    }

    public var degrees: Double {
        radians * 180 / .pi
    }

    public static var zero: Angle { Angle(0) }

    public static func + (lhs: Angle, rhs: Angle) -> Angle {
        Angle(lhs.radians + rhs.radians)
    }

    public static func - (lhs: Angle, rhs: Angle) -> Angle {
        Angle(lhs.radians - rhs.radians)
    }

    public var sine: Double { sin(radians) }
    public var cosine: Double { cos(radians) }

    /// Direction vector for this angle.
    public var direction: Vec2 {
        Vec2(x: cosine, y: sine)
    }

    /// Normalized to [-pi, pi].
    public var normalized: Angle {
        var r = radians.truncatingRemainder(dividingBy: 2 * .pi)
        if r > .pi { r -= 2 * .pi }
        if r < -.pi { r += 2 * .pi }
        return Angle(r)
    }
}

/// Computes the angle from vector `from` to vector `to`.
public func angleBetween(_ from: Vec2, _ to: Vec2) -> Angle {
    Angle(atan2(to.y - from.y, to.x - from.x))
}

/// Facing direction for ships. The original Star Control uses 16 discrete
/// facings separated by 22.5 degrees. We represent this as a continuous
/// angle for smoother visuals but snap special weapons that depend on facing
/// to the 16-direction grid when needed.
public enum ShipFacing {
    /// Number of discrete facing directions (matching original Star Control).
    public static let count = 16

    /// Angle step between facings in radians.
    public static var step: Angle {
        Angle(2 * .pi / Double(count))
    }

    /// Snaps a continuous angle to the nearest discrete facing.
    public static func snap(_ angle: Angle) -> Angle {
        let stepRads = Self.step.radians
        let roundedStep = (angle.radians / stepRads).rounded(.toNearestOrEven)
        let snapped = roundedStep * stepRads
        return Angle(snapped)
    }
}
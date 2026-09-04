/// Input intent from a player or AI pilot.
///
/// The simulation only sees intents, never raw keyboard or controller events.
/// This abstraction enables hot-seat multiplayer, AI pilots, and replay.
public struct InputIntent: Hashable, Sendable, Codable {
    /// Ship is thrusting forward.
    public var thrust: Bool

    /// Ship is rotating left (counter-clockwise).
    public var turnLeft: Bool

    /// Ship is rotating right (clockwise).
    public var turnRight: Bool

    /// Primary weapon is being fired.
    public var firePrimary: Bool

    /// Special ability is being activated.
    public var fireSpecial: Bool

    public init(
        thrust: Bool = false,
        turnLeft: Bool = false,
        turnRight: Bool = false,
        firePrimary: Bool = false,
        fireSpecial: Bool = false
    ) {
        self.thrust = thrust
        self.turnLeft = turnLeft
        self.turnRight = turnRight
        self.firePrimary = firePrimary
        self.fireSpecial = fireSpecial
    }

    public static let none: InputIntent = InputIntent()
}
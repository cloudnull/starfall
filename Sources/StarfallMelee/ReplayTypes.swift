import StarfallCore
import StarfallData

/// One frame of recorded input for both players.
public struct MeleeReplayFrame: Hashable, Sendable, Codable {
    public let p1Input: InputIntent
    public let p2Input: InputIntent

    public init(p1Input: InputIntent, p2Input: InputIntent) {
        self.p1Input = p1Input
        self.p2Input = p2Input
    }
}

/// Complete recording of a melee match. Stores everything needed to
/// deterministically replay the simulation from scratch.
public struct MeleeReplay: Hashable, Sendable, Codable {
    /// Ship definition index for player 1 (index into ShipRoster.all).
    public let ship1Index: Int

    /// Ship definition index for player 2.
    public let ship2Index: Int

    /// Arena used for the match.
    public let arena: ArenaState

    /// Player 1 starting position.
    public let ship1StartPos: Vec2

    /// Player 1 starting facing.
    public let ship1StartFacing: Angle

    /// Player 2 starting position.
    public let ship2StartPos: Vec2

    /// Player 2 starting facing.
    public let ship2StartFacing: Angle

    /// Recorded inputs, one per simulation frame.
    public let frames: [MeleeReplayFrame]

    /// Frame on which the match ended (nil = did not finish yet).
    public let endingFrame: Int?

    public init(
        ship1Index: Int,
        ship2Index: Int,
        arena: ArenaState,
        ship1StartPos: Vec2,
        ship1StartFacing: Angle,
        ship2StartPos: Vec2,
        ship2StartFacing: Angle,
        frames: [MeleeReplayFrame],
        endingFrame: Int?
    ) {
        self.ship1Index = ship1Index
        self.ship2Index = ship2Index
        self.arena = arena
        self.ship1StartPos = ship1StartPos
        self.ship1StartFacing = ship1StartFacing
        self.ship2StartPos = ship2StartPos
        self.ship2StartFacing = ship2StartFacing
        self.frames = frames
        self.endingFrame = endingFrame
    }
}
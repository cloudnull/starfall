import StarfallCore
import StarfallData

/// Records inputs during a live melee match so they can be replayed later.
public final class MeleeReplayRecorder {
    private let ship1Index: Int
    private let ship2Index: Int
    private let arena: ArenaState
    private let ship1StartPos: Vec2
    private let ship1StartFacing: Angle
    private let ship2StartPos: Vec2
    private let ship2StartFacing: Angle

    private var frames: [MeleeReplayFrame] = []
    private var endedAtFrame: Int?

    public init(
        ship1Index: Int,
        ship2Index: Int,
        arena: ArenaState,
        ship1StartPos: Vec2,
        ship1StartFacing: Angle,
        ship2StartPos: Vec2,
        ship2StartFacing: Angle
    ) {
        self.ship1Index = ship1Index
        self.ship2Index = ship2Index
        self.arena = arena
        self.ship1StartPos = ship1StartPos
        self.ship1StartFacing = ship1StartFacing
        self.ship2StartPos = ship2StartPos
        self.ship2StartFacing = ship2StartFacing
    }

    /// Record a frame of input. Call before `MeleeSimulation.step()`.
    /// Pass `matchEnded: true` on the frame where the match outcome is first detected.
    public func record(p1Input: InputIntent, p2Input: InputIntent, matchEnded: Bool) {
        frames.append(MeleeReplayFrame(p1Input: p1Input, p2Input: p2Input))
        if matchEnded && endedAtFrame == nil {
            endedAtFrame = frames.count
        }
    }

    /// Clear all recorded frames.
    public func clear() {
        frames.removeAll()
        endedAtFrame = nil
    }

    /// Finalize and return the replay. Call after the match ends.
    public func finalize() -> MeleeReplay {
        MeleeReplay(
            ship1Index: ship1Index,
            ship2Index: ship2Index,
            arena: arena,
            ship1StartPos: ship1StartPos,
            ship1StartFacing: ship1StartFacing,
            ship2StartPos: ship2StartPos,
            ship2StartFacing: ship2StartFacing,
            frames: frames,
            endingFrame: endedAtFrame
        )
    }
}
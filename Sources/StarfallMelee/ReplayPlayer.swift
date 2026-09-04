import StarfallCore
import StarfallData

/// Deterministic replay player. Replays a recorded match frame-by-frame
/// by feeding recorded inputs into a fresh MeleeSimulation.
public final class MeleeReplayPlayer {
    private let replay: MeleeReplay
    public private(set) var simulation: MeleeSimulation?
    private var currentFrame: Int = 0

    /// Callback invoked after each replayed frame with the current simulation state.
    public var onFrame: ((MeleeSimulation) -> Void)?

    /// Callback invoked when the replay reaches its ending frame.
    public var onEnd: ((MatchOutcome?) -> Void)?

    public init(replay: MeleeReplay) {
        self.replay = replay
    }

    /// Prepare the simulation for playback. Must be called before calling `nextFrame()`.
    public func prepare() {
        guard replay.ship1Index >= 0, replay.ship1Index < ShipRoster.all.count,
              replay.ship2Index >= 0, replay.ship2Index < ShipRoster.all.count else {
            return
        }

        let ship1Def = ShipRoster.all[replay.ship1Index]
        let ship2Def = ShipRoster.all[replay.ship2Index]

        simulation = MeleeSimulation(
            arena: replay.arena,
            ship1Def: ship1Def,
            ship1Pos: replay.ship1StartPos,
            ship1Facing: replay.ship1StartFacing,
            ship2Def: ship2Def,
            ship2Pos: replay.ship2StartPos,
            ship2Facing: replay.ship2StartFacing
        )
        currentFrame = 0
    }

/// Advance the replay by one frame. Returns `true` if there are more frames.
    public func nextFrame() -> Bool {
        guard let sim = simulation else {
            return false
        }

        // Check if we've already played all meaningful frames.
        if currentFrame >= replay.frames.count {
            return false
        }

        if let endFrame = replay.endingFrame, currentFrame >= endFrame {
            return false
        }

        let frame = replay.frames[currentFrame]
        sim.step(p1Input: frame.p1Input, p2Input: frame.p2Input)
        onFrame?(sim)
        currentFrame += 1

        if currentFrame >= replay.frames.count ||
           (replay.endingFrame.map({ currentFrame >= $0 }) ?? false) {
            onEnd?(sim.outcome)
        }

        return true
    }

    /// Reset the replay to the beginning.
    public func reset() {
        prepare()
    }

    /// Current frame index (0-based).
    public var frame: Int { currentFrame }

    /// Total frame count in the replay.
    public var totalFrames: Int { replay.frames.count }
}
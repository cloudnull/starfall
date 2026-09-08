import XCTest
import StarfallCore
import StarfallData
import StarfallMelee

final class MeleeReplayTests: XCTestCase {
    private func makeDefaultArena() -> ArenaState {
        ArenaState(
            bounds: Rect(min: Vec2(x: -400, y: -300), max: Vec2(x: 400, y: 300)),
            planetPosition: Vec2.zero,
            planetRadius: 50,
            gravityStrength: 18_000
        )
    }

    // --- Recording helpers ---

    /// Run a simulation for N frames with given inputs, record frames, return replay + final sim state.
    private func recordMatch(
        frames: Int,
        p1Inputs: [InputIntent],
        p2Inputs: [InputIntent],
        in arena: ArenaState,
        ship1Index: Int,
        ship2Index: Int
    ) -> (replay: MeleeReplay, finalSim: MeleeSimulation) {
        let s1Pos = Vec2(x: -300, y: -200)
        let s2Pos = Vec2(x: 300, y: 200)
        let s1Facing: Angle = .zero
        let s2Facing = Angle(.pi)

        let sim = MeleeSimulation(
            arena: arena,
            ship1Def: ShipRoster.all[ship1Index],
            ship1Pos: s1Pos,
            ship1Facing: s1Facing,
            ship2Def: ShipRoster.all[ship2Index],
            ship2Pos: s2Pos,
            ship2Facing: s2Facing
        )

        var replayFrames: [MeleeReplayFrame] = []
        var matchEndFrame: Int? = nil

        for i in 0..<frames {
            let p1i = i < p1Inputs.count ? p1Inputs[i] : .none
            let p2i = i < p2Inputs.count ? p2Inputs[i] : .none
            replayFrames.append(MeleeReplayFrame(p1Input: p1i, p2Input: p2i))
            sim.step(p1Input: p1i, p2Input: p2i)
            if matchEndFrame == nil && sim.outcome != nil {
                matchEndFrame = i + 1
            }
        }

        let replay = MeleeReplay(
            ship1Index: ship1Index,
            ship2Index: ship2Index,
            arena: arena,
            ship1StartPos: s1Pos,
            ship1StartFacing: s1Facing,
            ship2StartPos: s2Pos,
            ship2StartFacing: s2Facing,
            frames: replayFrames,
            endingFrame: matchEndFrame
        )

        return (replay, sim)
    }

    // --- Tests ---

    func testReplayFrameEquality() {
        let f1 = MeleeReplayFrame(p1Input: .none, p2Input: .none)
        let f2 = MeleeReplayFrame(p1Input: .none, p2Input: .none)
        let f3 = MeleeReplayFrame(p1Input: InputIntent(thrust: true), p2Input: .none)

        XCTAssertEqual(f1, f2)
        XCTAssertNotEqual(f1, f3)
    }

    func testReplayDeterministicNoInput() {
        let arena = makeDefaultArena()
        let frames = 20
        let (replay, originalSim) = recordMatch(
            frames: frames,
            p1Inputs: [],
            p2Inputs: [],
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        player.prepare()

        let replaySim = player.simulation!
        for _ in 0..<frames {
            _ = player.nextFrame()
        }

        XCTAssertEqual(replaySim.ship1.position.x, originalSim.ship1.position.x, accuracy: 1e-6)
        XCTAssertEqual(replaySim.ship1.position.y, originalSim.ship1.position.y, accuracy: 1e-6)
        XCTAssertEqual(replaySim.ship2.position.x, originalSim.ship2.position.x, accuracy: 1e-6)
        XCTAssertEqual(replaySim.ship2.position.y, originalSim.ship2.position.y, accuracy: 1e-6)
        XCTAssertEqual(replaySim.ship1.crew, originalSim.ship1.crew)
        XCTAssertEqual(replaySim.ship2.crew, originalSim.ship2.crew)
    }

    func testReplayDeterministicWithInput() {
        let arena = makeDefaultArena()
        let frames = 60

        // P1 thrusts + fires, P2 turns + thrusts
        var p1Inputs: [InputIntent] = []
        var p2Inputs: [InputIntent] = []
        for i in 0..<frames {
            p1Inputs.append(InputIntent(thrust: i % 4 == 0, firePrimary: i % 10 == 0))
            p2Inputs.append(InputIntent(thrust: true, turnLeft: i % 6 == 0))
        }

        let (replay, originalSim) = recordMatch(
            frames: frames,
            p1Inputs: p1Inputs,
            p2Inputs: p2Inputs,
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        player.prepare()

        for _ in 0..<frames {
            _ = player.nextFrame()
        }

        XCTAssertEqual(player.simulation!.ship1.crew, originalSim.ship1.crew)
        XCTAssertEqual(player.simulation!.ship2.crew, originalSim.ship2.crew)
        XCTAssertEqual(player.simulation!.ship1.energy, originalSim.ship1.energy)
        XCTAssertEqual(player.simulation!.ship2.energy, originalSim.ship2.energy)
        XCTAssertEqual(player.simulation!.projectiles.count, originalSim.projectiles.count)
    }

    func testReplayPlayerExhaustion() {
        let arena = makeDefaultArena()
        let frames = 10
        let (replay, _) = recordMatch(
            frames: frames,
            p1Inputs: [],
            p2Inputs: [],
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        player.prepare()

        let maxFrames = replay.endingFrame ?? frames
        var trueCount = 0
        for _ in 0..<maxFrames {
            if player.nextFrame() {
                trueCount += 1
            }
        }
        XCTAssertEqual(trueCount, maxFrames)
        XCTAssertFalse(player.nextFrame())
    }

    func testReplayPlayerReset() {
        let arena = makeDefaultArena()
        let frames = 15
        let (replay, _) = recordMatch(
            frames: frames,
            p1Inputs: [],
            p2Inputs: [],
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        player.prepare()

        // Advance halfway.
        for _ in 0..<frames / 2 {
            _ = player.nextFrame()
        }
        XCTAssertEqual(player.frame, frames / 2)

        // Reset and verify.
        player.reset()
        XCTAssertEqual(player.frame, 0)
        XCTAssertEqual(player.totalFrames, frames)
    }

    func testReplayEndingFrame() {
        let arena = makeDefaultArena()

        // Thrust ships at each other — they should collide or die.
        let frames = 10
        var p1Inputs: [InputIntent] = []
        var p2Inputs: [InputIntent] = []
        for _ in 0..<frames {
            p1Inputs.append(InputIntent(thrust: true))
            p2Inputs.append(InputIntent(thrust: true))
        }

        let (replay, originalSim) = recordMatch(
            frames: frames,
            p1Inputs: p1Inputs,
            p2Inputs: p2Inputs,
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        if originalSim.outcome != nil {
            XCTAssertNotNil(replay.endingFrame)
            XCTAssertLessThan(replay.endingFrame!, frames)
        } else {
            XCTAssertNil(replay.endingFrame)
        }
    }

    func testReplayOnFrameCallback() {
        let arena = makeDefaultArena()
        let frames = 20
        let (replay, _) = recordMatch(
            frames: frames,
            p1Inputs: [],
            p2Inputs: [],
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        var capturedSims: [Int] = []

        player.onFrame = { sim in
            capturedSims.append(sim.ship1.crew)
        }

        player.prepare()
        while player.nextFrame() { /* continue */ }

        let expectedFrames = replay.endingFrame ?? frames
        XCTAssertEqual(capturedSims.count, expectedFrames)
    }

    func testReplayOnEndCallback() {
        let arena = makeDefaultArena()
        let frames = 10
        let (replay, _) = recordMatch(
            frames: frames,
            p1Inputs: [],
            p2Inputs: [],
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        var capturedOutcome: MatchOutcome?

        player.onEnd = { outcome in
            capturedOutcome = outcome
        }

        player.prepare()

        // If match didn't end, onEnd should not fire during normal playback.
        if replay.endingFrame == nil {
            for _ in 0..<frames {
                _ = player.nextFrame()
            }
            XCTAssertNil(capturedOutcome)
        } else {
            var called = false
            player.onEnd = { _ in called = true }
            for _ in 0..<frames {
                _ = player.nextFrame()
            }
            XCTAssertTrue(called)
        }
    }

    func testReplayTotalFrames() {
        let arena = makeDefaultArena()
        let frames = 25
        let (replay, _) = recordMatch(
            frames: frames,
            p1Inputs: [],
            p2Inputs: [],
            in: arena,
            ship1Index: 0,
            ship2Index: 7
        )

        let player = MeleeReplayPlayer(replay: replay)
        player.prepare()
        XCTAssertEqual(player.totalFrames, frames)
    }
}
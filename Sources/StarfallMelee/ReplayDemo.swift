import StarfallCore
import StarfallData

/// Generates a short demo replay using deterministic AI vs AI.
public func generateDemoReplay() -> MeleeReplay {
    let arena = ArenaState(
        bounds: Rect(min: Vec2(x: -400, y: -300), max: Vec2(x: 400, y: 300)),
        planetPosition: Vec2.zero,
        planetRadius: 50,
        gravityStrength: 18_000
    )

    let s1Pos = Vec2(x: -300, y: -200)
    let s2Pos = Vec2(x: 300, y: 200)
    let s1Facing: Angle = .zero
    let s2Facing = Angle(.pi)

    guard !ShipRoster.compact.isEmpty, !ShipRoster.dominion.isEmpty else {
        // Fallback: empty replay.
        return MeleeReplay(
            ship1Index: 0,
            ship2Index: 0,
            arena: arena,
            ship1StartPos: s1Pos,
            ship1StartFacing: s1Facing,
            ship2StartPos: s2Pos,
            ship2StartFacing: s2Facing,
            frames: [],
            endingFrame: nil
        )
    }

    let ship1Index = 0
    let ship2Index = ShipRoster.compact.count

    let sim = MeleeSimulation(
        arena: arena,
        ship1Def: ShipRoster.compact[0],
        ship1Pos: s1Pos,
        ship1Facing: s1Facing,
        ship2Def: ShipRoster.dominion[0],
        ship2Pos: s2Pos,
        ship2Facing: s2Facing
    )

    var rng = SeededRNG(seed: 42)
    var frames: [MeleeReplayFrame] = []
    let maxFrames = 300

    for _ in 0..<maxFrames {
        let p1 = randomInput(&rng)
        let p2 = randomInput(&rng)

        frames.append(MeleeReplayFrame(p1Input: p1, p2Input: p2))
        sim.step(p1Input: p1, p2Input: p2)

        if sim.outcome != nil {
            break
        }
    }

    let endingFrame = sim.outcome != nil ? frames.count : nil

    return MeleeReplay(
        ship1Index: ship1Index,
        ship2Index: ship2Index,
        arena: arena,
        ship1StartPos: s1Pos,
        ship1StartFacing: s1Facing,
        ship2StartPos: s2Pos,
        ship2StartFacing: s2Facing,
        frames: frames,
        endingFrame: endingFrame
    )
}

private func randomInput(_ rng: inout SeededRNG) -> InputIntent {
    InputIntent(
        thrust: rng.nextDouble() < 0.6,
        turnLeft: rng.nextDouble() < 0.25,
        turnRight: rng.nextDouble() < 0.25,
        firePrimary: rng.nextDouble() < 0.15,
        fireSpecial: rng.nextDouble() < 0.05
    )
}
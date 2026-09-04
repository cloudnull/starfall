import XCTest
@testable import StarfallCore

/// Determinism test: proves that same seed + same input sequence always
/// produces identical simulation output.
final class DeterminismTests: XCTestCase {
    struct SimState: Hashable {
        var position: Vec2
        var velocity: Vec2
        var facing: Angle
        var speed: Double
        var crew: Int
        var energy: Int
    }

    func simulate(
        frames: Int,
        seed: UInt64,
        inputs: [InputIntent]
    ) -> [SimState] {
        var rng = SeededRNG(seed: seed)
        var state = SimState(
            position: Vec2(x: 100, y: 100),
            velocity: Vec2.zero,
            facing: Angle(0),
            speed: 0,
            crew: 20,
            energy: 24
        )

        var history: [SimState] = []
        let turnRate: Double = .pi / 180
        let thrustPower: Double = 0.5
        let maxSpeed: Double = 24

        for frame in 0..<frames {
            let input = frame < inputs.count ? inputs[frame] : .none

            if input.turnLeft {
                state.facing = state.facing - Angle(turnRate)
            }
            if input.turnRight {
                state.facing = state.facing + Angle(turnRate)
            }

            if input.thrust {
                let dir = state.facing.direction
                state.velocity = state.velocity + dir * thrustPower
                let spd = state.velocity.length
                if spd > maxSpeed {
                    state.velocity = state.velocity.normalized * maxSpeed
                }
                state.speed = spd
            }

            state.position = state.position + state.velocity

            if rng.nextDouble() < 0.01 && state.crew > 0 {
                state.crew -= 1
            }

            if state.energy < 24 {
                state.energy += 1
            }

            if input.firePrimary && state.energy >= 3 {
                state.energy -= 3
            }

            history.append(state)
        }

        return history
    }

    func testDeterministicReplay() {
        let inputRNG = SeededRNG(seed: 7777)
        var inputs: [InputIntent] = []
        for _ in 0..<500 {
            let r = inputRNG.nextDouble()
            inputs.append(InputIntent(
                thrust: r < 0.4,
                turnLeft: r >= 0.4 && r < 0.6,
                turnRight: r >= 0.6 && r < 0.8,
                firePrimary: r >= 0.8 && r < 0.9,
                fireSpecial: r >= 0.9
            ))
        }

        let run1 = simulate(frames: 500, seed: 42, inputs: inputs)
        let run2 = simulate(frames: 500, seed: 42, inputs: inputs)

        XCTAssertEqual(run1.count, run2.count)
        for i in 0..<run1.count {
            XCTAssertEqual(run1[i], run2[i], "Frame \(i) differs")
        }
    }

    func testDifferentSeedProducesDifferentResult() {
        let inputRNG = SeededRNG(seed: 7777)
        var inputs: [InputIntent] = []
        for _ in 0..<1000 {
            let r = inputRNG.nextDouble()
            inputs.append(InputIntent(
                thrust: r < 0.4,
                turnLeft: r >= 0.4 && r < 0.6,
                turnRight: r >= 0.6 && r < 0.8,
                firePrimary: false,
                fireSpecial: false
            ))
        }

        let run1 = simulate(frames: 1000, seed: 42, inputs: inputs)
        let run2 = simulate(frames: 1000, seed: 99, inputs: inputs)

        var differ = false
        for i in 0..<run1.count {
            if run1[i] != run2[i] {
                differ = true
                break
            }
        }
        XCTAssertTrue(differ, "Results should differ because the RNG affects crew loss with 1000 frames")
    }

    func testIdenticalInputsNoRandomnessProduceIdenticalResult() {
        let inputs = Array(repeating: InputIntent(thrust: true), count: 200)

        let run1 = simulate(frames: 200, seed: 1, inputs: inputs)
        let run2 = simulate(frames: 200, seed: 999, inputs: inputs)

        for i in 0..<run1.count {
            XCTAssertEqual(run1[i].position, run2[i].position, "Position differs at frame \(i)")
            XCTAssertEqual(run1[i].velocity, run2[i].velocity, "Velocity differs at frame \(i)")
            XCTAssertEqual(run1[i].facing, run2[i].facing, "Facing differs at frame \(i)")
            XCTAssertEqual(run1[i].speed, run2[i].speed, "Speed differs at frame \(i)")
        }
    }
}
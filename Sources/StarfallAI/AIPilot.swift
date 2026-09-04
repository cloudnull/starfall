import Foundation
import StarfallCore
import StarfallMelee

/// Provides AI-driven InputIntent for a ship in a melee match.
///
/// The AI evaluates the current simulation state each frame and produces
/// thrust, turn, fire, and special commands. Difficulty controls reaction
/// delay and tactical sophistication.
public final class AIPilot {
    let difficulty: AIDifficulty
    private let rng: SeededRNG

    /// Frames of input delay based on difficulty (easy=12, medium=6, hard=2).
    private var reactionDelay: Int {
        switch difficulty {
        case .easy: return 12
        case .medium: return 6
        case .hard: return 2
        }
    }

    /// Buffered input, delayed by reaction frames.
    private var inputBuffer: CircularBuffer

    public init(difficulty: AIDifficulty, seed: UInt64 = 0) {
        self.difficulty = difficulty
        self.rng = SeededRNG(seed: seed)
        let delay: Int
        switch difficulty {
        case .easy: delay = 12
        case .medium: delay = 6
        case .hard: delay = 2
        }
        self.inputBuffer = CircularBuffer(delay: delay)
    }

    /// Produce input for this frame given the AI ship and the opponent.
    ///
    /// - Parameters:
    ///   - own: The AI-controlled ship.
    ///   - opponent: The opposing ship.
    ///   - projectiles: Current projectiles in the arena.
    ///   - arena: Arena bounds and planet info.
    /// - Returns: InputIntent for the simulation.
    public func think(
        own: ShipState,
        opponent: ShipState,
        projectiles: [Projectile],
        arena: ArenaState
    ) -> InputIntent {
        let intent = decide(own: own, opponent: opponent, projectiles: projectiles, arena: arena)
        inputBuffer.push(intent)
        return inputBuffer.peek(delay: reactionDelay)
    }

    // MARK: - Decision Logic

    private func decide(
        own: ShipState,
        opponent: ShipState,
        projectiles: [Projectile],
        arena: ArenaState
    ) -> InputIntent {
        var intent = InputIntent()

        // Account for arena wrap when computing direction to opponent.
        let rawDelta = opponent.position - own.position
        let toOpponent = Vec2(
            x: wrapDelta(rawDelta.x, bounds: arena.bounds.width),
            y: wrapDelta(rawDelta.y, bounds: arena.bounds.height)
        )
        let distToOpponent = toOpponent.length
        let angleToOpponent = Angle(atan2(toOpponent.y, toOpponent.x))
        let facingDelta = angleToOpponent - own.facing
        let angleDiff = normalizeAngle(facingDelta.radians)

        // 1. Turning — aim toward opponent.
        if angleDiff > 0.3 {
            intent.turnRight = true
        } else if angleDiff < -0.3 {
            intent.turnLeft = true
        }

        // 2. Thrust decision.
        intent.thrust = decideThrust(
            own: own,
            dist: distToOpponent,
            angleDiff: angleDiff,
            toPlanet: arena.planetPosition - own.position,
            planetRadius: arena.planetRadius
        )

        // 3. Fire primary.
        intent.firePrimary = decideFirePrimary(
            own: own,
            dist: distToOpponent,
            angleDiff: angleDiff
        )

        // 4. Fire special.
        intent.fireSpecial = decideFireSpecial(
            own: own,
            opponent: opponent,
            dist: distToOpponent,
            projectiles: projectiles,
            arena: arena
        )

        // 5. Evasive maneuvers (medium+).
        if difficulty != .easy {
            applyEvasiveManeuvers(
                intent: &intent,
                own: own,
                opponent: opponent,
                projectiles: projectiles,
                arena: arena
            )
        }

        // 6. Hard mode: advanced tactics.
        if difficulty == .hard {
            applyAdvancedTactics(
                intent: &intent,
                own: own,
                opponent: opponent,
                dist: distToOpponent,
                arena: arena
            )
        }

        return intent
    }

    // MARK: - Thrust

    private func decideThrust(
        own: ShipState,
        dist: Double,
        angleDiff: Double,
        toPlanet: Vec2,
        planetRadius: Double
    ) -> Bool {
        // Don't thrust if the planet is directly ahead and close.
        let distToPlanet = toPlanet.length
        let planetAhead = distToPlanet > 0 && toPlanet.normalized.dot(own.facing.direction) > 0.7
        if planetAhead && distToPlanet < planetRadius + 150 {
            return false
        }

        let aligned = abs(angleDiff) < 0.8

        if dist > 300 {
            return aligned
        }

        if dist < 120 {
            if difficulty == .easy {
                return aligned
            }
            if aligned {
                return rng.nextDouble() < 0.3
            }
            return true
        }

        return aligned
    }

    // MARK: - Fire Primary

    private func decideFirePrimary(
        own: ShipState,
        dist: Double,
        angleDiff: Double
    ) -> Bool {
        guard own.primaryCooldown <= 0 else { return false }
        guard own.energy >= own.definition.primaryWeapon.energyCost else { return false }
        guard !own.isOverheated else { return false }

        // Heat awareness (medium+): reduce fire rate when running hot.
        let heatFrac = Double(own.heat) / Double(own.definition.heatCapacity)
        if difficulty != .easy && heatFrac > 0.8 {
            return false
        }

        let aligned = abs(angleDiff) < 0.5
        let inRange = dist < 400

        if aligned && inRange {
            if difficulty == .easy {
                return rng.nextDouble() < 0.6
            }
            if difficulty == .medium {
                return rng.nextDouble() < 0.85
            }
            return true
        }

        if difficulty == .hard && dist < 500 {
            return rng.nextDouble() < 0.3
        }

        return false
    }

    // MARK: - Fire Special

    private func decideFireSpecial(
        own: ShipState,
        opponent: ShipState,
        dist: Double,
        projectiles: [Projectile],
        arena: ArenaState
    ) -> Bool {
        guard own.specialCooldown <= 0 else { return false }
        guard own.energy >= own.definition.specialAbility.energyCost else { return false }

        let special = own.definition.specialAbility

        switch special.type {
        case .shield:
            let shieldLow = own.shieldMax > 0 && own.shield < own.shieldMax * 2 / 5
            let hullLow = own.hull < own.definition.startingCrew * 3 / 5
            if shieldLow || hullLow {
                return rng.nextDouble() < 0.7
            }
            return isUnderFire(projectiles: projectiles, targetID: own.id) && rng.nextDouble() < 0.5

        case .cloak:
            if dist < 150 {
                return rng.nextDouble() < 0.6
            }
            return false

        case .specialForm:
            if difficulty != .easy && dist < 300 {
                return rng.nextDouble() < 0.4
            }
            return false

        case .teleport:
            if dist < 100 {
                return rng.nextDouble() < 0.7
            }
            return isUnderFire(projectiles: projectiles, targetID: own.id) && rng.nextDouble() < 0.5

        case .kamikaze:
            if difficulty == .easy { return false }
            if own.hull < 5 && dist < 200 {
                return rng.nextDouble() < 0.6
            }
            return false

        case .launchFighters:
            if dist < 400 {
                return rng.nextDouble() < 0.5
            }
            return false

        case .regrowCrew:
            if own.hull < own.definition.startingCrew / 2 {
                return rng.nextDouble() < 0.8
            }
            return false

        case .rearWeapon:
            if difficulty != .easy && dist < 300 {
                return rng.nextDouble() < 0.4
            }
            return false

        case .pointDefense:
            if isUnderFire(projectiles: projectiles, targetID: own.id) {
                return rng.nextDouble() < 0.7
            }
            return false

        case .parasiteMine:
            if dist < 150 && opponent.parasiteTimer <= 0 {
                return rng.nextDouble() < 0.6
            }
            return false

        case .retroPulse:
            if dist < 200 {
                return rng.nextDouble() < 0.5
            }
            return false

        case .crystalSwarm:
            if own.energy >= 30 && dist < 350 {
                return rng.nextDouble() < 0.3
            }
            return false

        case .morphShift:
            if dist > 300 {
                return rng.nextDouble() < 0.4
            }
            return false

        case .sirenCall:
            if difficulty != .easy && dist < 250 {
                return rng.nextDouble() < 0.4
            }
            return false

        case .none:
            return false
        }
    }

    // MARK: - Evasive Maneuvers

    private func applyEvasiveManeuvers(
        intent: inout InputIntent,
        own: ShipState,
        opponent: ShipState,
        projectiles: [Projectile],
        arena: ArenaState
    ) {
        let incoming = projectiles.filter { proj in
            proj.ownerShipID == opponent.id && proj.lifetime > 0
        }

        for proj in incoming {
            // Account for arena wrap when computing projectile direction.
            let rawDelta = proj.position - own.position
            let toProj = Vec2(
                x: wrapDelta(rawDelta.x, bounds: arena.bounds.width),
                y: wrapDelta(rawDelta.y, bounds: arena.bounds.height)
            )
            let dist = toProj.length
            guard dist < 150 else { continue }

            let projAngle = Angle(atan2(toProj.y, toProj.x))
            let diff = normalizeAngle(projAngle.radians - own.facing.radians)

            if abs(diff) < 0.5 {
                if diff > 0 {
                    intent.turnLeft = true
                } else {
                    intent.turnRight = true
                }
                intent.thrust = rng.nextDouble() < 0.4
            }
            break
        }

    // Planet avoidance.
        let toPlanet = arena.planetPosition - own.position
        let distToPlanet = toPlanet.length - arena.planetRadius - 16
        if distToPlanet < 80 {
            let awayFromPlanet = Angle(atan2(-toPlanet.y, -toPlanet.x))
            let diff = normalizeAngle(awayFromPlanet.radians - own.facing.radians)
            if diff > 0.2 {
                intent.turnRight = true
            } else if diff < -0.2 {
                intent.turnLeft = true
            }
            intent.thrust = distToPlanet < 40
        }

        // Heat-cool maneuver: when overheated, back away from opponent to create distance for cooling.
        if own.isOverheated {
            let rawOppDelta = opponent.position - own.position
            let awayFromOpponent = -Vec2(
                x: wrapDelta(rawOppDelta.x, bounds: arena.bounds.width),
                y: wrapDelta(rawOppDelta.y, bounds: arena.bounds.height)
            )
            let awayAngle = Angle(atan2(awayFromOpponent.y, awayFromOpponent.x))
            let diff = normalizeAngle(awayAngle.radians - own.facing.radians)
            if abs(diff) < 0.5 {
                intent.thrust = true
            } else {
                intent.turnRight = diff > 0
                intent.turnLeft = diff < 0
                intent.thrust = true
            }
        }
    }

    // MARK: - Advanced Tactics (Hard)

    private func applyAdvancedTactics(
        intent: inout InputIntent,
        own: ShipState,
        opponent: ShipState,
        dist: Double,
        arena: ArenaState
    ) {
        // Gravity whip: if near planet and opponent is further, use planet gravity
        // for a slingshot maneuver.
        let toPlanet = arena.planetPosition - own.position
        let distToPlanet = toPlanet.length

        if distToPlanet < 200 && distToPlanet > 80 {
            let rawOppDelta = opponent.position - own.position
            let toOpponent = Vec2(
                x: wrapDelta(rawOppDelta.x, bounds: arena.bounds.width),
                y: wrapDelta(rawOppDelta.y, bounds: arena.bounds.height)
            )
            let planetAngle = Angle(atan2(toPlanet.y, toPlanet.x))
            let oppAngle = Angle(atan2(toOpponent.y, toOpponent.x))
            let angleDiff = normalizeAngle(planetAngle.radians - oppAngle.radians)

            if abs(angleDiff) > 2.5 && own.speed < 15 {
                intent.thrust = true
            }
        }

        // Kite: if own hull is low and opponent is chasing, maintain distance.
        if own.hull < own.definition.startingCrew / 2 && dist < 150 {
            let rawOppDelta = opponent.position - own.position
            let awayFromOpponent = -Vec2(
                x: wrapDelta(rawOppDelta.x, bounds: arena.bounds.width),
                y: wrapDelta(rawOppDelta.y, bounds: arena.bounds.height)
            )
            let awayAngle = Angle(atan2(awayFromOpponent.y, awayFromOpponent.x))
            let diff = normalizeAngle(awayAngle.radians - own.facing.radians)

            if abs(diff) < 0.5 {
                intent.thrust = true
            } else {
                intent.turnRight = diff > 0
                intent.turnLeft = diff < 0
                intent.thrust = rng.nextDouble() < 0.5
            }
        }
    }

    // MARK: - Helpers

    private func isUnderFire(projectiles: [Projectile], targetID: EntityID) -> Bool {
        projectiles.contains { $0.ownerShipID != targetID }
    }
}

// MARK: - Circular Input Buffer

/// Fixed-size circular buffer that delays intent output by `delay` frames.
private struct CircularBuffer {
    private var buffer: [InputIntent]
    private var writeIndex = 0
    private let capacity: Int

    init(delay: Int) {
        // Size must be at least delay+1 to hold delayed data without overwriting
        // the value we're about to read. Add padding for safety.
        self.capacity = max(delay + 2, 4)
        self.buffer = Array(repeating: .none, count: self.capacity)
    }

    mutating func push(_ intent: InputIntent) {
        buffer[writeIndex % capacity] = intent
        writeIndex += 1
    }

    func peek(delay: Int) -> InputIntent {
        let readIndex = max(0, writeIndex - delay)
        return buffer[readIndex % capacity]
    }
}

// MARK: - Angle Helper

private func normalizeAngle(_ radians: Double) -> Double {
    var r = radians.truncatingRemainder(dividingBy: .pi * 2)
    if r > .pi { r -= .pi * 2 }
    if r < -.pi { r += .pi * 2 }
    return r
}
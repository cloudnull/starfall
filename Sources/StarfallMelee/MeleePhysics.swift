import Foundation
import StarfallCore
import StarfallData

/// Determines which way a ship should turn to reach a desired facing.
enum TurnDirection {
    case none
    case clockwise
    case counterClockwise
}

/// Computes the turn direction needed to go from `current` to `desired` facing.
func computeTurnDirection(current: Angle, desired: Angle) -> TurnDirection {
    let diff = (desired.radians - current.radians).normalizedAngle()
    let snapThreshold = ShipFacing.step.radians / 2

    if abs(diff) < snapThreshold {
        return .none
    }

    return diff > 0 ? .counterClockwise : .clockwise
}

extension Double {
    /// Normalizes an angle in radians to [-pi, pi].
    func normalizedAngle() -> Double {
        var r = self.truncatingRemainder(dividingBy: 2 * .pi)
        if r > .pi { r -= 2 * .pi }
        if r < -.pi { r += 2 * .pi }
        return r
    }
}

/// Applies thrust physics to a ship for one simulation frame.
/// Thrust increases speed (scalar) in the facing direction, which is then
/// applied as a velocity delta. Speed is capped at maxThrust/mass.
func applyThrust(
    input: InputIntent,
    def: ShipDefinition,
    speed: inout Double,
    facing: Angle,
    thrustTimer: inout Int,
    velocity: inout Vec2
) {
    guard input.thrust else {
        thrustTimer = 0
        return
    }

    if thrustTimer > 0 {
        thrustTimer -= 1
        return
    }

    let maxSpeed = def.maxThrust / def.mass
    if speed >= maxSpeed {
        thrustTimer = def.thrustWait
        return
    }

    let increment = def.thrustIncrement / def.mass
    speed = min(speed + increment, maxSpeed)
    // Add thrust in the facing direction to existing velocity (accumulates with gravity/drift).
    let thrustVel = facing.direction * increment
    velocity = velocity + thrustVel
    thrustTimer = def.thrustWait
}

/// Applies turning to a ship for one simulation frame.
func applyTurn(
    input: InputIntent,
    def: ShipDefinition,
    facing: inout Angle,
    turnTimer: inout Int,
    desiredFacing: inout Angle
) {
    if input.turnLeft {
        desiredFacing = desiredFacing - ShipFacing.step
    } else if input.turnRight {
        desiredFacing = desiredFacing + ShipFacing.step
    }

    if def.turnWait == 0 {
        facing = desiredFacing
        return
    }

    if turnTimer > 0 {
        turnTimer -= 1
        return
    }

    let diff = (desiredFacing.radians - facing.radians).normalizedAngle()
    let stepRads = ShipFacing.step.radians

    if abs(diff) < stepRads / 2 {
        facing = desiredFacing
    } else if diff > 0 {
        facing = facing + ShipFacing.step
    } else {
        facing = facing - ShipFacing.step
    }

    turnTimer = def.turnWait
}

/// Applies friction (drag) to the ship's speed scalar.
func applyFriction(def: ShipDefinition, speed: inout Double) {
    let friction = 1.0 - 1.0 / (def.mass + 1.0)
    speed *= friction
    if speed < 0.01 {
        speed = 0
    }
}

/// Applies gravitational attraction from the planet toward the ship.
func applyGravity(
    shipPosition: Vec2,
    planetPosition: Vec2,
    gravityStrength: Double,
    mass: Double,
    velocity: inout Vec2
) {
    let toPlanet = planetPosition - shipPosition
    let distSquared = toPlanet.lengthSquared
    let minDistSquared: Double = 2500
    let clampedDist = max(distSquared, minDistSquared)
    let force = gravityStrength / clampedDist
    let direction = toPlanet.normalized
    let acceleration = direction * (force / mass)
    velocity += acceleration
}

/// Wraps a position to the arena bounds.
func applyArenaWrap(position: Vec2, bounds: Rect) -> Vec2 {
    var x = position.x
    var y = position.y

    if x < bounds.min.x {
        x = bounds.max.x - (bounds.min.x - x)
    } else if x > bounds.max.x {
        x = bounds.min.x + (x - bounds.max.x)
    }

    if y < bounds.min.y {
        y = bounds.max.y - (bounds.min.y - y)
    } else if y > bounds.max.y {
        y = bounds.min.y + (y - bounds.max.y)
    }

    return Vec2(x: x, y: y)
}

/// Computes the shortest signed delta accounting for arena wrap-around.
/// Given a raw delta, returns the shortest equivalent delta (could be positive or negative).
public func wrapDelta(_ delta: Double, bounds: Double) -> Double {
    let halfBounds = bounds / 2
    if delta > halfBounds {
        return delta - bounds
    } else if delta < -halfBounds {
        return delta + bounds
    }
    return delta
}

/// Checks if a ship has collided with the planet.
func applyPlanetCollision(
    shipPosition: Vec2,
    planetPosition: Vec2,
    planetRadius: Double,
    shipRadius: Double,
    velocity: Vec2,
    position: inout Vec2,
    velocityOut: inout Vec2
) -> (crewDamage: Int, newPosition: Vec2, newVelocity: Vec2) {
    let toPlanet = planetPosition - position
    let dist = toPlanet.length
    let collisionDistance = planetRadius + shipRadius

    if dist >= collisionDistance || dist == 0 {
        return (0, position, velocity)
    }

    let normal = toPlanet.normalized
    // Push ship well clear of the planet to prevent repeated collisions.
    let safeDist = max(collisionDistance + 50, planetRadius + 80)
    let newPos = planetPosition + normal * safeDist

    // Remove all radial velocity component so the ship doesn't drift back in.
    let radialComponent = velocity.dot(normal)
    let newVel: Vec2
    if radialComponent > 0 {
        // Ship is moving toward planet — kill inward momentum, keep tangential.
        newVel = velocity - normal * radialComponent
    } else {
        // Ship is already moving away — let it go.
        newVel = velocity
    }

    // Only deal damage on first impact, not repeated bounces.
    let damage = radialComponent > 0 ? 1 : 0

    return (damage, newPos, newVel)
}

/// Checks if a projectile has hit a ship.
func projectileHitsShip(projectilePos: Vec2, shipPos: Vec2, shipRadius: Double, projectileRadius: Double) -> Bool {
    let dist = distance(projectilePos, shipPos)
    return dist <= shipRadius + projectileRadius
}

/// Advances timers and clears expired states.
func updateSpecialTimers(
    isCloaked: Bool,
    cloakTimer: Int,
    isSpecialForm: Bool,
    specialFormTimer: Int,
    pointDefenseTimer: Int,
    parasiteTimer: Int,
    sirenCallTimer: Int,
    retroPulseSlowTimer: Int,
    isKamikaze: Bool,
    kamikazeTimer: Int,
    isMorphLocked: Bool
) -> (
    cloaked: Bool, cloakTimer: Int,
    specialForm: Bool, specialFormTimer: Int,
    pointDefenseTimer: Int,
    parasiteTimer: Int,
    sirenCallTimer: Int,
    retroPulseSlowTimer: Int,
    kamikaze: Bool, kamikazeTimer: Int,
    morphLocked: Bool
) {
    var cloaked = isCloaked
    var ct = cloakTimer
    if cloaked {
        ct -= 1
        if ct <= 0 { cloaked = false; ct = 0 }
    }

    var sf = isSpecialForm
    var sft = specialFormTimer
    if sf {
        sft -= 1
        if sft <= 0 { sf = false; sft = 0 }
    }

    var pdt = pointDefenseTimer
    if pdt > 0 { pdt -= 1 }

    var prt = parasiteTimer
    if prt > 0 { prt -= 1 }

    var sct = sirenCallTimer
    if sct > 0 { sct -= 1 }

    var rpt = retroPulseSlowTimer
    if rpt > 0 { rpt -= 1 }

    var kamikaze = isKamikaze
    var kt = kamikazeTimer
    if kamikaze {
        kt -= 1
        if kt <= 0 { kamikaze = false; kt = 0 }
    }

    let morphLocked = isMorphLocked && sf // morph lock ends when special form ends

    return (cloaked, ct, sf, sft, pdt, prt, sct, rpt, kamikaze, kt, morphLocked)
}

/// Applies gravitational pull from the planet on an asteroid.
func applyAsteroidGravity(
    asteroidPosition: Vec2,
    planetPosition: Vec2,
    gravityStrength: Double,
    mass: Double,
    velocity: inout Vec2
) {
    let toPlanet = planetPosition - asteroidPosition
    let distSquared = toPlanet.lengthSquared
    let minDistSquared: Double = 10000
    let clampedDist = max(distSquared, minDistSquared)
    let force = gravityStrength * 0.25 / clampedDist
    let direction = toPlanet.normalized
    let acceleration = direction * (force / mass)
    velocity += acceleration
}

/// Checks if a ship has collided with an asteroid and resolves the bounce.
func applyShipAsteroidCollision(
    shipPosition: Vec2,
    shipVelocity: Vec2,
    shipRadius: Double,
    asteroidPosition: Vec2,
    asteroidVelocity: Vec2,
    asteroidRadius: Double,
    asteroidMass: Double
) -> (shipDamage: Int, newShipPos: Vec2, newShipVel: Vec2, newAsteroidVel: Vec2) {
    let toAsteroid = asteroidPosition - shipPosition
    let dist = toAsteroid.length
    let collisionDist = shipRadius + asteroidRadius

    guard dist < collisionDist && dist > 0 else {
        return (0, shipPosition, shipVelocity, asteroidVelocity)
    }

    let normal = toAsteroid.normalized
    let overlap = collisionDist - dist

    // Push ship out of asteroid.
    let newShipPos = shipPosition - normal * overlap

    // Bounce: reflect ship velocity off asteroid normal with damping.
    let dot = shipVelocity.dot(normal)
    var newShipVel = shipVelocity - normal * (2 * dot)
    newShipVel = newShipVel * 0.6

    // Transfer some momentum to asteroid.
    let impulse = abs(dot) * 0.1
    let asteroidImpulse = normal * (impulse / asteroidMass)
    let newAsteroidVel = asteroidVelocity + asteroidImpulse

    // Damage scales with impact speed.
    let impactSpeed = abs(dot)
    let damage = max(1, Int(impactSpeed / 2))

    return (damage, newShipPos, newShipVel, newAsteroidVel)
}

/// Checks if a projectile has hit an asteroid.
func projectileHitsAsteroid(
    projectilePos: Vec2,
    asteroidPos: Vec2,
    asteroidRadius: Double,
    projectileRadius: Double
) -> Bool {
    let dist = distance(projectilePos, asteroidPos)
    return dist <= asteroidRadius + projectileRadius
}
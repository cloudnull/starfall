import Foundation
import StarfallCore
import StarfallData

/// The main melee simulation engine. Owns two ships, projectiles, and the arena.
/// Step at 24 FPS via FixedTimestep for deterministic replay.
public final class MeleeSimulation {
    public var arena: ArenaState

    public var ship1: ShipState
    public var ship2: ShipState

    public var projectiles: [Projectile]

    /// Asteroids drifting through the arena.
    public var asteroids: [Asteroid]

    /// Next entity ID for projectiles. Starts at 100 so it never collides with ship IDs.
    var nextEntityID: UInt32

    public var outcome: MatchOutcome? {
        if ship1.hull <= 0 && ship2.hull <= 0 {
            return MatchOutcome(winnerID: nil, shipStates: [ship1.id: ship1, ship2.id: ship2])
        } else if ship1.hull <= 0 {
            return MatchOutcome(winnerID: ship2.id, shipStates: [ship1.id: ship1, ship2.id: ship2])
        } else if ship2.hull <= 0 {
            return MatchOutcome(winnerID: ship1.id, shipStates: [ship1.id: ship1, ship2.id: ship2])
        } else if matchTimer <= 0 {
            // Time out -- winner is whoever has more hull.
            let winnerID: EntityID?
            if ship1.hull > ship2.hull {
                winnerID = ship1.id
            } else if ship2.hull > ship1.hull {
                winnerID = ship2.id
            } else {
                winnerID = nil
            }
            return MatchOutcome(winnerID: winnerID, shipStates: [ship1.id: ship1, ship2.id: ship2])
        }
        return nil
    }

    public private(set) var matchTimer: Int
    private let matchDurationFrames: Int

    /// Energy recharge per frame.
    let energyRecharge: Double

    /// Default projectile radius for collision.
    let projectileRadius: Double

    /// Ship collision radius (used when definition doesn't carry one).
    let shipCollisionRadius: Double

    /// Reference to one of the two ships, used for damage application.
    private enum ShipRef { case ship1, ship2 }

    private func shipPosition(_ ref: ShipRef, s1: ShipState, s2: ShipState) -> Vec2 {
        ref == .ship1 ? s1.position : s2.position
    }

    /// Returns true if the weapon type is energy (100% absorbed by shields).
    private func isEnergyWeapon(_ type: WeaponType) -> Bool {
        type == .laser || type == .cone
    }

    /// Applies layered damage: shield → armor → hull.
    private func applyLayeredDamage(rawDamage: Int, isEnergy: Bool, shield: inout Int, shieldMax: Int, armorReduction: Double, hull: inout Int) {
        if isEnergy {
            // Energy: full damage to shield first, overflow to armor→hull.
            var remaining = rawDamage
            if shield > 0 {
                let absorbed = min(shield, remaining)
                shield -= absorbed
                remaining -= absorbed
            }
            if remaining > 0 {
                let armorBlocked = Int(Double(remaining) * armorReduction)
                hull -= (remaining - armorBlocked)
            }
        } else {
            // Ballistic: 60% to shield, 40% bypasses directly.
            let shieldDamage = Int(Double(rawDamage) * 0.6)
            let bypassDamage = rawDamage - shieldDamage

            if shield > 0 && shieldDamage > 0 {
                let absorbed = min(shield, shieldDamage)
                shield -= absorbed
            }

            // Bypass portion goes through armor.
            let armorBlocked = Int(Double(bypassDamage) * armorReduction)
            hull -= (bypassDamage - armorBlocked)
        }
    }

    /// Apply projectile damage to the target ship through the layered system.
    private func applyProjectileDamage(proj: Projectile, to ref: ShipRef, ship1: inout ShipState, ship2: inout ShipState) {
        let weapon = ref == .ship1 ? ship1.definition.primaryWeapon : ship2.definition.primaryWeapon
        let isEnergy = isEnergyWeapon(weapon.type)

        let regenDelay = ref == .ship1 ? ship1.definition.shieldRegenDelay : ship2.definition.shieldRegenDelay

        if ref == .ship1 {
            applyLayeredDamage(
                rawDamage: proj.damage,
                isEnergy: isEnergy,
                shield: &ship1.shield,
                shieldMax: ship1.shieldMax,
                armorReduction: ship1.definition.armorReduction,
                hull: &ship1.hull
            )
            ship1.shieldRegenTimer = max(ship1.shieldRegenTimer, regenDelay)
        } else {
            applyLayeredDamage(
                rawDamage: proj.damage,
                isEnergy: isEnergy,
                shield: &ship2.shield,
                shieldMax: ship2.shieldMax,
                armorReduction: ship2.definition.armorReduction,
                hull: &ship2.hull
            )
            ship2.shieldRegenTimer = max(ship2.shieldRegenTimer, regenDelay)
        }
    }

    /// Update shield regen and heat dissipation for a ship.
    private func updateShieldAndHeat(ship: inout ShipState) {
        // Shield regen
        if ship.shieldRegenTimer > 0 {
            ship.shieldRegenTimer -= 1
        } else if ship.shield < ship.shieldMax && ship.definition.shieldRegenRate > 0 {
            ship.shield = min(ship.shieldMax, ship.shield + ship.definition.shieldRegenRate)
        }

        // Heat dissipation
        if ship.heat > 0 {
            ship.heat = max(0, ship.heat - ship.definition.heatDissipation)
        }
        // Overheat hysteresis: must cool below 50% before firing again.
        if ship.isOverheated && ship.heat < ship.definition.heatCapacity / 2 {
            ship.isOverheated = false
        }
    }

    public init(
        arena: ArenaState,
        ship1Def: ShipDefinition,
        ship1Pos: Vec2,
        ship1Facing: Angle,
        ship2Def: ShipDefinition,
        ship2Pos: Vec2,
        ship2Facing: Angle,
        matchDurationSeconds: Int = 60,
        energyRechargePerFrame: Double = 0.5
    ) {
        self.arena = arena
        self.ship1 = ShipState(id: EntityID(1), definition: ship1Def, position: ship1Pos, facing: ship1Facing)
        self.ship2 = ShipState(id: EntityID(2), definition: ship2Def, position: ship2Pos, facing: ship2Facing)
        self.projectiles = []
        self.asteroids = MeleeSimulation.generateAsteroids(arena: arena, count: 8, shipPositions: [ship1Pos, ship2Pos])
        self.nextEntityID = 100
        self.matchDurationFrames = matchDurationSeconds * 24
        self.matchTimer = self.matchDurationFrames
        self.energyRecharge = energyRechargePerFrame
        self.projectileRadius = 4
        self.shipCollisionRadius = 16
    }

    /// Advances the simulation by one frame.
    public func step(p1Input: InputIntent, p2Input: InputIntent) {
        guard outcome == nil else { return }

        // 1. Update match timer.
        if matchTimer > 0 {
            matchTimer -= 1
        }

        // 2. Process input and apply turning + firing.
        processShipInput(input: p1Input, ship: &ship1, opponent: &ship2)
        processShipInput(input: p2Input, ship: &ship2, opponent: &ship1)

        // 3. Apply thrust.
        applyThrustToShip(input: p1Input, ship: &ship1)
        applyThrustToShip(input: p2Input, ship: &ship2)

        // 4. Apply friction.
        // The original Star Control uses 1/(mass+1) friction per frame.
        // This project's balance decision (dec_ArKmxGrhaFQ4HrjmiiuwSUjC) modified
        // it to 0.02 + 0.02/(mass+1) for higher thrust mobility.
        // Friction is applied only to velocity; speed scalar is updated after.
        let friction1 = 0.02 + 0.02 / (ship1.definition.mass + 1.0)
        let friction2 = 0.02 + 0.02 / (ship2.definition.mass + 1.0)
        ship1.velocity = ship1.velocity * (1.0 - friction1)
        ship2.velocity = ship2.velocity * (1.0 - friction2)

        // 5. Apply gravity.
        applyGravityToShip(ship: &ship1)
        applyGravityToShip(ship: &ship2)

        // 6. Update positions.
        ship1.position = ship1.position + ship1.velocity
        ship2.position = ship2.position + ship2.velocity

        // 7. Arena wrap.
        ship1.position = applyArenaWrap(position: ship1.position, bounds: arena.bounds)
        ship2.position = applyArenaWrap(position: ship2.position, bounds: arena.bounds)

        // 8. Planet collision.
        handlePlanetCollision(ship: &ship1)
        handlePlanetCollision(ship: &ship2)

        // 8b. Safety net — if ship is still inside planet after collision resolution,
        //     place it at a safe distance to prevent death loops.
        ensureShipClearOfPlanet(ship: &ship1)
        ensureShipClearOfPlanet(ship: &ship2)

        // 9. Update special timers.
        updateSpecialTimersForShip(ship: &ship1)
        updateSpecialTimersForShip(ship: &ship2)

        // 10. Recharge energy.
        rechargeEnergy(ship: &ship1)
        rechargeEnergy(ship: &ship2)

        // 11. Shield regen and heat dissipation.
        updateShieldAndHeat(ship: &ship1)
        updateShieldAndHeat(ship: &ship2)

        // 12. Apply parasite drain (every 12 frames).
        applyParasiteDrain(ship: &ship1)
        applyParasiteDrain(ship: &ship2)

        // 12. Apply retro-pulse slow.
        applyRetroPulseSlow(ship: &ship1)
        applyRetroPulseSlow(ship: &ship2)

        // 13. Apply point defense.
        applyPointDefense(ship: ship1)
        applyPointDefense(ship: ship2)

        // 14. Update projectiles.
        updateProjectiles()

        // 15. Check ship-ship collision.
        checkShipShipCollision()

        // 16. Update asteroids and check ship-asteroid collisions.
        updateAsteroids()

        // 17. Ensure speeds are consistent with velocity vectors.
        ship1.speed = ship1.velocity.length
        ship2.speed = ship2.velocity.length
    }

    // MARK: - Ship Input Processing

    func processShipInput(input: InputIntent, ship: inout ShipState, opponent: inout ShipState) {
        let def = ship.definition
        // Turning — uses applyTurn which respects turnWait and turnTimer.
        applyTurn(
            input: input,
            def: def,
            facing: &ship.facing,
            turnTimer: &ship.turnTimer,
            desiredFacing: &ship.desiredFacing
        )

        // Fire primary weapon.
        if input.firePrimary && ship.primaryCooldown <= 0 && !ship.isMorphLocked && !ship.isOverheated {
            let weapon = ship.definition.primaryWeapon
            if ship.energy >= weapon.energyCost {
                ship.energy -= weapon.energyCost
                fireProjectile(
                    from: ship,
                    weapon: weapon,
                    target: opponent
                )
                ship.primaryCooldown = weapon.fireWait
                // Apply heat.
                if weapon.heatPerShot > 0 {
                    ship.heat += weapon.heatPerShot
                    if ship.heat >= ship.definition.heatCapacity {
                        ship.isOverheated = true
                    }
                }
            }
        }

        // Use special ability.
        if input.fireSpecial && ship.specialCooldown <= 0 {
            let special = ship.definition.specialAbility
            if ship.energy >= special.energyCost {
                ship.energy -= special.energyCost
                activateSpecial(ship: &ship, opponent: &opponent)
                ship.specialCooldown = special.useWait
            }
        }

        // Energy recharge timer.
        if ship.energyTimer > 0 {
            ship.energyTimer -= 1
        }
    }

    func applyThrustToShip(input: InputIntent, ship: inout ShipState) {
        let def = ship.definition
        let facing = ship.facing
        applyThrust(
            input: input,
            def: def,
            speed: &ship.speed,
            facing: facing,
            thrustTimer: &ship.thrustTimer,
            velocity: &ship.velocity
        )
    }

    func applyGravityToShip(ship: inout ShipState) {
        let mass = ship.definition.mass
        applyGravity(
            shipPosition: ship.position,
            planetPosition: arena.planetPosition,
            gravityStrength: arena.gravityStrength,
            mass: mass,
            velocity: &ship.velocity
        )
    }

    func handlePlanetCollision(ship: inout ShipState) {
        let pos = ship.position
        let vel = ship.velocity
        let result = applyPlanetCollision(
            shipPosition: pos,
            planetPosition: arena.planetPosition,
            planetRadius: arena.planetRadius,
            shipRadius: shipCollisionRadius,
            velocity: vel,
            position: &ship.position,
            velocityOut: &ship.velocity
        )
        if result.crewDamage > 0 {
            ship.hull -= result.crewDamage
        }
    }

    /// Safety net: if a ship is still inside the planet after collision resolution,
    /// teleport it to a safe distance and zero its velocity to prevent death loops.
    func ensureShipClearOfPlanet(ship: inout ShipState) {
        let dist = distance(ship.position, arena.planetPosition)
        let safeDist = arena.planetRadius + shipCollisionRadius
        guard dist < safeDist && dist > 0 else { return }

        let normal = (ship.position - arena.planetPosition).normalized
        ship.position = arena.planetPosition + normal * (safeDist + 20)
        ship.velocity = .zero
        ship.speed = 0
    }

    func updateSpecialTimersForShip(ship: inout ShipState) {
        let result = updateSpecialTimers(
            isCloaked: ship.isCloaked,
            cloakTimer: ship.cloakTimer,
            isSpecialForm: ship.isSpecialForm,
            specialFormTimer: ship.specialFormTimer,
            pointDefenseTimer: ship.pointDefenseTimer,
            parasiteTimer: ship.parasiteTimer,
            sirenCallTimer: ship.sirenCallTimer,
            retroPulseSlowTimer: ship.retroPulseSlowTimer,
            isKamikaze: ship.isKamikaze,
            kamikazeTimer: ship.kamikazeTimer,
            isMorphLocked: ship.isMorphLocked
        )
        ship.isCloaked = result.cloaked
        ship.cloakTimer = result.cloakTimer
        ship.isSpecialForm = result.specialForm
        ship.specialFormTimer = result.specialFormTimer
        ship.pointDefenseTimer = result.pointDefenseTimer
        ship.parasiteTimer = result.parasiteTimer
        ship.sirenCallTimer = result.sirenCallTimer
        ship.retroPulseSlowTimer = result.retroPulseSlowTimer
        ship.isKamikaze = result.kamikaze
        ship.kamikazeTimer = result.kamikazeTimer
        ship.isMorphLocked = result.morphLocked
    }

    func rechargeEnergy(ship: inout ShipState) {
        if ship.energy < ship.definition.maxEnergy {
            if ship.energyTimer <= 0 {
                ship.energy = min(ship.definition.maxEnergy, ship.energy + ship.definition.energyRegen)
                ship.energyTimer = ship.definition.energyWait
            }
        }
    }

    // MARK: - Weapons

    func fireProjectile(from ship: ShipState, weapon: ShipWeapon, target: ShipState) {
        let boltSpeed = weapon.projectileSpeed
        let projVelocity = ship.facing.direction * boltSpeed + ship.velocity * 0.3

        // Spawn point is slightly ahead of the ship.
        let spawnOffset = ship.facing.direction * shipCollisionRadius
        let spawnPos = ship.position + spawnOffset

        let projID = EntityID(nextEntityID)
        nextEntityID += 1

        let proj = Projectile(
            id: projID,
            position: spawnPos,
            velocity: projVelocity,
            damage: weapon.damage,
            isTracking: weapon.isTracking,
            ownerShipID: ship.id,
            lifetime: 180,
            weaponType: weapon.type
        )
        projectiles.append(proj)
    }

    func updateProjectiles() {
        var surviving: [Projectile] = []

        for proj in projectiles {
            var projPos = proj.position
            var projVel = proj.velocity

            // Siren Call: projectiles switch sides if the target is under siren call.
            var ownerID = proj.ownerShipID
            if ship2.sirenCallTimer > 0 && proj.ownerShipID == ship1.id {
                ownerID = ship2.id
            } else if ship1.sirenCallTimer > 0 && proj.ownerShipID == ship2.id {
                ownerID = ship1.id
            }

            // Tracking steering — targets the opponent of the current (possibly switched) owner.
            if proj.isTracking {
                let targetShip = ownerID == ship1.id ? ship2 : ship1
                if targetShip.hull > 0 {
                    // Account for arena wrap when computing direction.
                    let toTargetRaw = targetShip.position - projPos
                    let toTarget = Vec2(
                        x: wrapDelta(toTargetRaw.x, bounds: arena.bounds.width),
                        y: wrapDelta(toTargetRaw.y, bounds: arena.bounds.height)
                    )
                    if toTarget.length > 0 {
                        let steer = toTarget.normalized * 0.3
                        projVel = projVel + steer
                        if projVel.length > 8 {
                            projVel = projVel.normalized * 8
                        }
                    }
                }
            }

            projPos = projPos + projVel
            projPos = applyArenaWrap(position: projPos, bounds: arena.bounds)

            let projLifetime = proj.lifetime - 1

            // Check collision with target ship (target is the opponent of the current owner).
            let targetShipRef: ShipRef = ownerID == ship1.id ? .ship2 : .ship1

            if projectileHitsShip(
                projectilePos: projPos,
                shipPos: shipPosition(targetShipRef, s1: ship1, s2: ship2),
                shipRadius: shipCollisionRadius,
                projectileRadius: projectileRadius
            ) {
                applyProjectileDamage(proj: proj, to: targetShipRef, ship1: &ship1, ship2: &ship2)
                continue
            }

            // Check collision with planet.
            let toPlanet = arena.planetPosition - projPos
            if toPlanet.length < arena.planetRadius + projectileRadius {
                continue
            }

            if projLifetime <= 0 {
                continue
            }

            surviving.append(Projectile(
                id: proj.id,
                position: projPos,
                velocity: projVel,
                damage: proj.damage,
                isTracking: proj.isTracking,
                ownerShipID: ownerID,
                lifetime: projLifetime,
                weaponType: proj.weaponType
            ))
        }

        projectiles = surviving
    }

    // MARK: - Special Weapons

    func activateSpecial(ship: inout ShipState, opponent: inout ShipState) {
        let special = ship.definition.specialAbility
        let rng = SeededRNG(seed: UInt64(ship.id.value) ^ UInt64(matchTimer))

        switch special.type {
        case .none:
            return

        case .shield:
            ship.shield = ship.shieldMax
            ship.shieldRegenTimer = 0

        case .cloak:
            ship.isCloaked = true
            ship.cloakTimer = 312 // ~13s

        case .specialForm:
            ship.isSpecialForm = true
            ship.specialFormTimer = 120 // 5s

        case .teleport:
            // Blink: teleport to a random position in the arena, clear velocity.
            let bx = rng.nextDouble() * (arena.bounds.max.x - arena.bounds.min.x) + arena.bounds.min.x
            let by = rng.nextDouble() * (arena.bounds.max.y - arena.bounds.min.y) + arena.bounds.min.y
            ship.position = Vec2(x: bx, y: by)
            ship.velocity = .zero
            ship.speed = 0

        case .kamikaze:
            // Glory Run: kamikaze mode — high speed boost, kills both on collision.
            ship.isKamikaze = true
            ship.kamikazeTimer = 90 // 3.75s
            ship.velocity = ship.facing.direction * 8

        case .launchFighters:
            // Launch Drones: fire 3 tracking projectiles with extra lifetime.
            for i in 0..<3 {
                let spread = Angle(Double(i - 1) * 0.2)
                let dir = (ship.facing + spread).direction
                let projVel = dir * 5 + ship.velocity * 0.2
                let spawnOffset = ship.facing.direction * shipCollisionRadius
                let spawnPos = ship.position + spawnOffset
                let projID = EntityID(nextEntityID)
                nextEntityID += 1
                projectiles.append(Projectile(
                    id: projID,
                    position: spawnPos,
                    velocity: projVel,
                    damage: 8,
                    isTracking: true,
                    ownerShipID: ship.id,
                    lifetime: 300,
                    weaponType: .missile
                ))
            }

        case .regrowCrew:
            // Regrow Crew: restore 10 hull.
            ship.hull = min(ship.definition.maxCrew, ship.hull + 10)

        case .rearWeapon:
            // Rear Cannon: fire a projectile backwards.
            let rearFacing = ship.facing + Angle(.pi)
            let projVel = rearFacing.direction * 6 + ship.velocity * 0.3
            let spawnOffset = rearFacing.direction * shipCollisionRadius
            let spawnPos = ship.position + spawnOffset
            let projID = EntityID(nextEntityID)
            nextEntityID += 1
            projectiles.append(Projectile(
                id: projID,
                position: spawnPos,
                velocity: projVel,
                damage: 5,
                isTracking: false,
                ownerShipID: ship.id,
                lifetime: 180,
                weaponType: .projectile
            ))

        case .pointDefense:
            // Point Defense: auto-destroy incoming projectiles for 120 frames.
            ship.pointDefenseTimer = 120

        case .parasiteMine:
            // Parasite Mine: attach parasite that drains 1 crew every 12 frames.
            opponent.parasiteTimer = 180 // 7.5s

        case .retroPulse:
            // Retro Pulse: slow opponent for 240 frames.
            opponent.retroPulseSlowTimer = 240

        case .crystalSwarm:
            // Crystal Swarm: fire 12 low-damage projectiles in all directions.
            for i in 0..<12 {
                let angle = Angle(Double(i) * (.pi * 2) / 12)
                let dir = angle.direction
                let projVel = dir * 3
                let projID = EntityID(nextEntityID)
                nextEntityID += 1
                projectiles.append(Projectile(
                    id: projID,
                    position: ship.position,
                    velocity: projVel,
                    damage: 3,
                    isTracking: false,
                    ownerShipID: ship.id,
                    lifetime: 120,
                    weaponType: .spread
                ))
            }

        case .morphShift:
            // Morph Shift: transform — speed boost, can't fire primary, lasts 60 frames.
            ship.isSpecialForm = true
            ship.specialFormTimer = 60
            ship.isMorphLocked = true
            ship.velocity = ship.facing.direction * 6

        case .sirenCall:
            // Siren Call: opponent's projectiles switch sides for 120 frames.
            opponent.sirenCallTimer = 120
        }
    }

    // MARK: - Ship-Ship Collision

    func checkShipShipCollision() {
        let s1Pos = ship1.position
        let s2Pos = ship2.position
        let s1Vel = ship1.velocity
        let s2Vel = ship2.velocity
        let dist = distance(s1Pos, s2Pos)
        let collisionDist = shipCollisionRadius * 2

        guard dist < collisionDist && dist > 0 else { return }

        let normal = (s2Pos - s1Pos).normalized
        let overlap = collisionDist - dist

        // Kamikaze: if either ship is in Glory Run mode, ram damage based on speed.
        if ship1.isKamikaze || ship2.isKamikaze {
            let kamikazeSpeed = ship1.isKamikaze ? ship1.velocity.length : ship2.velocity.length
            let kamikazeCrew = ship1.isKamikaze ? ship1.hull : ship2.hull
            
            // Glory Run deals damage based on impact speed and remaining crew.
            let impactDamage = max(1, Int(kamikazeSpeed) * kamikazeCrew)
            
            if ship1.isKamikaze {
                ship2.hull -= impactDamage
                ship1.hull = 0
                ship1.isKamikaze = false
                ship1.kamikazeTimer = 0
            } else {
                ship1.hull -= impactDamage
                ship2.hull = 0
                ship2.isKamikaze = false
                ship2.kamikazeTimer = 0
            }
            return
        }

        ship1.position = s1Pos - normal * overlap * 0.5
        ship2.position = s2Pos + normal * overlap * 0.5

        let relVel = s1Vel - s2Vel
        let relDot = relVel.dot(normal)

        if relDot > 0 {
            ship1.velocity = s1Vel - normal * relDot * 0.5
            ship2.velocity = s2Vel + normal * relDot * 0.5
            ship1.speed = ship1.velocity.length
            ship2.speed = ship2.velocity.length

            let damage = max(1, Int(overlap / 2))
            ship1.hull -= damage
            ship2.hull -= damage
        }
    }

    // MARK: - Special Per-Frame Effects

    func applyParasiteDrain(ship: inout ShipState) {
        if ship.parasiteTimer > 0 && ship.parasiteTimer % 12 == 0 {
            ship.hull -= 1
        }
    }

    func applyRetroPulseSlow(ship: inout ShipState) {
        if ship.retroPulseSlowTimer > 0 {
            ship.velocity = ship.velocity * 0.95
        }
    }

    func applyPointDefense(ship: ShipState) {
        guard ship.pointDefenseTimer > 0 else { return }
        // Intercept incoming projectiles heading toward this ship.
        let targetShip = ship.id == ship1.id ? ship1 : ship2
        let otherShip = ship.id == ship1.id ? ship2 : ship1
        projectiles = projectiles.filter { proj in
            guard proj.ownerShipID == otherShip.id else { return true }
            let dist = distance(proj.position, targetShip.position)
            return dist > shipCollisionRadius + 40
        }
    }

    // MARK: - Asteroids

    /// Generate asteroids scattered around the arena, avoiding the planet and ship spawn zones.
    static func generateAsteroids(arena: ArenaState, count: Int, shipPositions: [Vec2]) -> [Asteroid] {
        var asteroids: [Asteroid] = []
        let rng = SeededRNG(seed: 12345)
        let shipAvoidanceDist: Double = 80

        for i in 0..<count {
            let radius = rng.nextDouble() * 10 + 8
            let mass = radius / 5

            var pos: Vec2
            repeat {
                let px = rng.nextDouble() * (arena.bounds.max.x - arena.bounds.min.x) + arena.bounds.min.x
                let py = rng.nextDouble() * (arena.bounds.max.y - arena.bounds.min.y) + arena.bounds.min.y
                pos = Vec2(x: px, y: py)
            } while distance(pos, arena.planetPosition) < arena.planetRadius + 60
                || shipPositions.contains { distance(pos, $0) < shipAvoidanceDist }

            let angle = rng.nextDouble() * .pi * 2
            let speed = rng.nextDouble() * 1.5 + 0.3
            let vel = Vec2(x: cos(angle) * speed, y: sin(angle) * speed)

            asteroids.append(Asteroid(
                id: EntityID(200 + UInt32(i)),
                position: pos,
                velocity: vel,
                radius: radius,
                mass: mass
            ))
        }

        return asteroids
    }

    /// Update asteroid positions and handle collisions with ships and projectiles.
    func updateAsteroids() {
        // Asteroids drift freely as static-ish hazards. They do NOT take planet
        // gravity: a gravity well (especially with a speed cap and no friction)
        // pulls them into a stable orbiting ring around the sun, which looks
        // wrong and clusters all the obstacles in one spot. Free drift keeps
        // them spread across the arena.
        for i in asteroids.indices {
            var ast = asteroids[i]

            ast.position = ast.position + ast.velocity

            // Keep drift speed gentle so they never read as stray projectiles.
            if ast.velocity.length > 3.0 {
                ast.velocity = ast.velocity.normalized * 3.0
            }

            // Arena wrap keeps them circulating in view.
            ast.position = applyArenaWrap(
                position: ast.position,
                bounds: arena.bounds
            )

            asteroids[i] = ast
        }

        // Ship-asteroid collisions.
        checkShipAsteroidCollision(ship: &ship1)
        checkShipAsteroidCollision(ship: &ship2)

        // Projectile-asteroid collisions: remove projectiles that hit asteroids.
        let asteroidPositions: [(Vec2, Double)] = asteroids.map { ($0.position, $0.radius) }
        projectiles = projectiles.filter { proj in
            for (apos, aradius) in asteroidPositions {
                if projectileHitsAsteroid(
                    projectilePos: proj.position,
                    asteroidPos: apos,
                    asteroidRadius: aradius,
                    projectileRadius: projectileRadius
                ) {
                    return false
                }
            }
            return true
        }
    }

    func checkShipAsteroidCollision(ship: inout ShipState) {
        for i in asteroids.indices {
            let result = applyShipAsteroidCollision(
                shipPosition: ship.position,
                shipVelocity: ship.velocity,
                shipRadius: shipCollisionRadius,
                asteroidPosition: asteroids[i].position,
                asteroidVelocity: asteroids[i].velocity,
                asteroidRadius: asteroids[i].radius,
                asteroidMass: asteroids[i].mass
            )

            if result.shipDamage > 0 {
                ship.hull -= result.shipDamage
                ship.position = result.newShipPos
                ship.velocity = result.newShipVel
                asteroids[i].velocity = result.newAsteroidVel
            }
        }
    }
}
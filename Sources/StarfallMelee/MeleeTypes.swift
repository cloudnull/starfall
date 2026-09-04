/// The Melee simulation module.
///
/// Contains the deterministic real-time combat simulation. The simulation
/// is entirely separate from rendering, input, and audio.
///
/// A match consists of two ships fighting in an arena with a gravity well.
/// The simulation advances in fixed timesteps (24 FPS) and produces
/// deterministic results given the same seed and input stream.

import StarfallCore
import StarfallData

/// Ship state during a melee match.
public struct ShipState: Hashable, Sendable {
    /// Unique identifier for this ship.
    public let id: EntityID

    /// Ship definition.
    public let definition: ShipDefinition

    /// Current position in world units.
    public var position: Vec2

    /// Current velocity in world units per frame.
    public var velocity: Vec2

    /// Current facing angle.
    public var facing: Angle

    /// Current speed (magnitude of velocity).
    public var speed: Double

    /// Remaining hull (structural hit points, formerly crew).
    public var hull: Int

    /// Maximum hull (from startingCrew).
    public let hullMax: Int

    /// Remaining shield pool. Shield absorbs weapon damage before hull.
    public var shield: Int

    /// Maximum shield (from definition).
    public let shieldMax: Int

    /// Frames until shield regeneration resumes after taking damage.
    public var shieldRegenTimer: Int

    /// Current weapon heat. When >= heatCapacity, ship is overheated.
    public var heat: Int

    /// Whether primary weapon is currently locked due to overheat.
    public var isOverheated: Bool

    /// Remaining energy.
    public var energy: Int

    /// Frames since last primary fire.
    public var primaryCooldown: Int

    /// Frames since last special use.
    public var specialCooldown: Int

    /// Frames since last energy recharge.
    public var energyTimer: Int

    /// Frames since last thrust increment.
    public var thrustTimer: Int

    /// Frames since last facing change.
    public var turnTimer: Int

    /// Desired facing (where the ship is trying to point based on input).
    public var desiredFacing: Angle

    /// Whether the ship is currently cloaked.
    public var isCloaked: Bool

    /// Cloak duration remaining.
    public var cloakTimer: Int

    /// Whether the ship is currently in a special form (e.g., comet).
    public var isSpecialForm: Bool

    /// Special form duration remaining.
    public var specialFormTimer: Int

    /// Frames remaining for point defense auto-intercept.
    public var pointDefenseTimer: Int

    /// Frames remaining for parasite drain on this ship (0 = not parasited).
    public var parasiteTimer: Int

    /// Frames remaining for Siren Call effect on this ship (fires for the other side).
    public var sirenCallTimer: Int

    /// Frames remaining for retro-pulse slow on this ship.
    public var retroPulseSlowTimer: Int

    /// Whether this ship is in Glory Run (kamikaze) mode.
    public var isKamikaze: Bool

    /// Kamikaze duration remaining.
    public var kamikazeTimer: Int

    /// Whether morph-shift has locked primary weapon.
    public var isMorphLocked: Bool

    /// Current crew count (for display). Defaults to hull; can diverge for crew-specific abilities.
    public var crew: Int { hull }

    public init(
        id: EntityID,
        definition: ShipDefinition,
        position: Vec2,
        facing: Angle = .zero
    ) {
        self.id = id
        self.definition = definition
        self.position = position
        self.velocity = .zero
        self.facing = facing
        self.speed = 0
        self.hull = definition.startingCrew
        self.hullMax = definition.maxCrew
        self.shield = definition.shieldMax
        self.shieldMax = definition.shieldMax
        self.shieldRegenTimer = 0
        self.heat = 0
        self.isOverheated = false
        self.energy = definition.startingEnergy
        self.primaryCooldown = 0
        self.specialCooldown = 0
        self.energyTimer = 0
        self.thrustTimer = 0
        self.turnTimer = 0
        self.desiredFacing = facing
        self.isCloaked = false
        self.cloakTimer = 0
        self.isSpecialForm = false
        self.specialFormTimer = 0
        self.pointDefenseTimer = 0
        self.parasiteTimer = 0
        self.sirenCallTimer = 0
        self.retroPulseSlowTimer = 0
        self.isKamikaze = false
        self.kamikazeTimer = 0
        self.isMorphLocked = false
    }
}

/// A projectile in the melee arena.
public struct Projectile: Hashable, Sendable {
    public let id: EntityID
    public var position: Vec2
    public var velocity: Vec2
    public var damage: Int
    public var isTracking: Bool
    public var ownerShipID: EntityID
    public var lifetime: Int // frames remaining
    public var weaponType: WeaponType // for rendering variety

    public init(
        id: EntityID,
        position: Vec2,
        velocity: Vec2,
        damage: Int,
        isTracking: Bool,
        ownerShipID: EntityID,
        lifetime: Int = 120,
        weaponType: WeaponType = .projectile
    ) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.damage = damage
        self.isTracking = isTracking
        self.ownerShipID = ownerShipID
        self.lifetime = lifetime
        self.weaponType = weaponType
    }
}

/// The melee arena state.
public struct ArenaState: Hashable, Sendable, Codable {
    /// Arena dimensions in world units.
    public let bounds: Rect

    /// Planet position in world units.
    public let planetPosition: Vec2

    /// Planet radius in world units.
    public let planetRadius: Double

    /// Gravity strength.
    public let gravityStrength: Double

    public init(
        bounds: Rect,
        planetPosition: Vec2,
        planetRadius: Double,
        gravityStrength: Double
    ) {
        self.bounds = bounds
        self.planetPosition = planetPosition
        self.planetRadius = planetRadius
        self.gravityStrength = gravityStrength
    }
}

/// Axis-aligned rectangle.
public struct Rect: Hashable, Sendable, Codable {
    public var min: Vec2
    public var max: Vec2

    public init(min: Vec2, max: Vec2) {
        self.min = min
        self.max = max
    }

    public var width: Double { max.x - min.x }
    public var height: Double { max.y - min.y }
}

/// An asteroid floating through the arena.
public struct Asteroid: Hashable, Sendable {
    public let id: EntityID
    public var position: Vec2
    public var velocity: Vec2
    public var radius: Double
    public var mass: Double

    public init(id: EntityID, position: Vec2, velocity: Vec2, radius: Double, mass: Double) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.mass = mass
    }
}

/// Outcome of a melee match.
public struct MatchOutcome: Hashable, Sendable {
    /// ID of the winning ship (if any).
    public let winnerID: EntityID?

    /// Final state of both ships.
    public let shipStates: [EntityID: ShipState]

    /// Whether the match ended in a tie.
    public var isTie: Bool { winnerID == nil }

    public init(winnerID: EntityID?, shipStates: [EntityID: ShipState]) {
        self.winnerID = winnerID
        self.shipStates = shipStates
    }
}
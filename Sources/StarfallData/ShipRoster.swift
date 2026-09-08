/// Complete ship roster from Phase 0 research.
///
/// Stats are sourced from the SC2/Ur-Quan Masters table at
/// wiki.starcontrol.com/index.php/Table_of_ship_properties.
/// Species and ship names are original (see IP guardrail decision).
/// See docs/research-dossier.md for the full research record.
public struct ShipRoster {

    /// All 14 ships in the game.
    public static let all: [ShipDefinition] = compact + dominion

    // MARK: - Kaelen Compact

    /// Alliance ships, ordered by cost descending.
    public static let compact: [ShipDefinition] = [
        ossariBroodstone,
        vaelenStriker,
        krtrukShifter,
        paelinDart,
        sirethVeil,
        terraniRunner,
        xhofiSpark
    ]

    // MARK: - Vexari Dominion

    /// Dominion ships, ordered by cost descending.
    public static let dominion: [ShipDefinition] = [
        vexariDreadCommand,
        fungorSporepod,
        kesharunner,
        synthariWarden,
        vokkHarasser,
        gorthReaver,
        drulSkirmisher
    ]

    /// Looks up a ship definition by name.
    public static func lookup(named name: String) -> ShipDefinition? {
        all.first { $0.name == name }
    }
}

// MARK: - Compact Ships

/// Ossari Broodstone - crystalline mothership.
/// Source: Chenjesu Broodhome (crew:36, energy:30, cost:26).
private let ossariBroodstone = ShipDefinition(
    name: "Broodstone",
    species: "Ossari",
    faction: .compact,
    cost: 26,
    maxCrew: 36,
    startingCrew: 36,
    maxEnergy: 30,
    startingEnergy: 30,
    energyRegen: 1,
    energyWait: 4,
    maxThrust: 27,
    thrustIncrement: 3,
    thrustWait: 4,
    turnWait: 6,
    mass: 10,
    primaryWeapon: ShipWeapon(
        name: "Crystal Shard",
        type: .spread,
        damage: 6,
        energyCost: 5,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 6,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Crystal Swarm",
        type: .crystalSwarm,
        energyCost: 20,
        useWait: 0
    ),
    shape: .broodstone,
    shieldMax: 40,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.3,
    heatCapacity: 100,
    heatDissipation: 3
)

/// Vaelen Striker - honor-bound warrior ship.
/// Source: Yehat Terminator (crew:20, energy:10, cost:23).
private let vaelenStriker = ShipDefinition(
    name: "Striker",
    species: "Vaelen",
    faction: .compact,
    cost: 23,
    maxCrew: 20,
    startingCrew: 20,
    maxEnergy: 10,
    startingEnergy: 10,
    energyRegen: 2,
    energyWait: 6,
    maxThrust: 30,
    thrustIncrement: 6,
    thrustWait: 2,
    turnWait: 2,
    mass: 3,
    primaryWeapon: ShipWeapon(
        name: "Twin Pulse Cannon",
        type: .projectile,
        damage: 1,
        energyCost: 1,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 10,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Force Shield",
        type: .shield,
        energyCost: 3,
        useWait: 2
    ),
    shape: .striker,
    shieldMax: 15,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.3,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Krr-tk Shifter - shapeshifter ship.
/// Source: Mmrnmhrm X-Form (crew:20, energy:10, cost:19).
private let krtrukShifter = ShipDefinition(
    name: "Shifter",
    species: "Krr-tk",
    faction: .compact,
    cost: 19,
    maxCrew: 20,
    startingCrew: 20,
    maxEnergy: 10,
    startingEnergy: 10,
    energyRegen: 1,
    energyWait: 6,
    maxThrust: 50,
    thrustIncrement: 10,
    thrustWait: 0,
    turnWait: 14,
    mass: 3,
    primaryWeapon: ShipWeapon(
        name: "Phase Missile",
        type: .missile,
        damage: 1,
        energyCost: 1,
        fireWait: 0,
        isTracking: true,
        projectileSpeed: 7,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Morph Shift",
        type: .morphShift,
        energyCost: 10,
        useWait: 0
    ),
    shape: .shifter,
    shieldMax: 10,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.1,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Paelin Dart - tiny, elusive scout.
/// Source: Arilou Skiff (crew:6, energy:20, cost:16).
private let paelinDart = ShipDefinition(
    name: "Dart",
    species: "Paelin",
    faction: .compact,
    cost: 16,
    maxCrew: 12,
    startingCrew: 12,
    maxEnergy: 20,
    startingEnergy: 20,
    energyRegen: 1,
    energyWait: 6,
    maxThrust: 22,
    thrustIncrement: 18,
    thrustWait: 0,
    turnWait: 0,
    mass: 1,
    primaryWeapon: ShipWeapon(
        name: "Auto Laser",
        type: .laser,
        damage: 1,
        energyCost: 2,
        fireWait: 1,
        isTracking: true,
        projectileSpeed: 12,
        heatPerShot: 1
    ),
    specialAbility: ShipSpecial(
        name: "Blink",
        type: .teleport,
        energyCost: 3,
        useWait: 2
    ),
    shape: .dart,
    shieldMax: 0,
    shieldRegenRate: 0,
    shieldRegenDelay: 60,
    armorReduction: 0.0,
    heatCapacity: 80,
    heatDissipation: 3
)

/// Sireth Veil - psychological warfare ship.
/// Source: Syreen Penetrator (crew:30, energy:10, cost:12).
private let sirethVeil = ShipDefinition(
    name: "Veil",
    species: "Sireth",
    faction: .compact,
    cost: 12,
    maxCrew: 30,
    startingCrew: 30,
    maxEnergy: 10,
    startingEnergy: 10,
    energyRegen: 1,
    energyWait: 10,
    maxThrust: 48,
    thrustIncrement: 12,
    thrustWait: 1,
    turnWait: 1,
    mass: 7,
    primaryWeapon: ShipWeapon(
        name: "Particle Stiletto",
        type: .laser,
        damage: 2,
        energyCost: 2,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 10,
        heatPerShot: 3
    ),
    specialAbility: ShipSpecial(
        name: "Siren Call",
        type: .sirenCall,
        energyCost: 3,
        useWait: 7
    ),
    shape: .veil,
    shieldMax: 25,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.1,
    heatCapacity: 60,
    heatDissipation: 3
)

/// Terrani Runner - human adaptable fighter.
/// Source: Earthling Cruiser (crew:18, energy:18, cost:9).
private let terraniRunner = ShipDefinition(
    name: "Runner",
    species: "Terrani",
    faction: .compact,
    cost: 9,
    maxCrew: 18,
    startingCrew: 18,
    maxEnergy: 18,
    startingEnergy: 18,
    energyRegen: 1,
    energyWait: 8,
    maxThrust: 24,
    thrustIncrement: 3,
    thrustWait: 4,
    turnWait: 1,
    mass: 6,
    primaryWeapon: ShipWeapon(
        name: "Tracking Missile",
        type: .missile,
        damage: 4,
        energyCost: 6,
        fireWait: 8,
        isTracking: true,
        projectileSpeed: 6,
        heatPerShot: 5
    ),
    specialAbility: ShipSpecial(
        name: "Point Defense",
        type: .pointDefense,
        energyCost: 4,
        useWait: 9
    ),
    shape: .runner,
    shieldMax: 20,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.3,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Xhofi Spark - kamikaze fox-warrior ship.
/// Source: Shofixti Scout (crew:20, energy:40, cost:5).
private let xhofiSpark = ShipDefinition(
    name: "Spark",
    species: "Xhofi",
    faction: .compact,
    cost: 5,
    maxCrew: 20,
    startingCrew: 20,
    maxEnergy: 40,
    startingEnergy: 40,
    energyRegen: 1,
    energyWait: 4,
    maxThrust: 27,
    thrustIncrement: 9,
    thrustWait: 6,
    turnWait: 6,
    mass: 7,
    primaryWeapon: ShipWeapon(
        name: "Energy Dart",
        type: .projectile,
        damage: 1,
        energyCost: 2,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 8,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Glory Run",
        type: .kamikaze,
        energyCost: 40,
        useWait: 0
    ),
    shape: .spark,
    shieldMax: 10,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.1,
    heatCapacity: 80,
    heatDissipation: 3
)

// MARK: - Dominion Ships

/// Vexari Dread Command - overmind flagship.
/// Source: Ur-Quan Dreadnought (crew:10, energy:30, cost:30).
private let vexariDreadCommand = ShipDefinition(
    name: "Dread Command",
    species: "Vexari",
    faction: .dominion,
    cost: 30,
    maxCrew: 10,
    startingCrew: 10,
    maxEnergy: 30,
    startingEnergy: 30,
    energyRegen: 30,
    energyWait: 150,
    maxThrust: 18,
    thrustIncrement: 6,
    thrustWait: 3,
    turnWait: 4,
    mass: 1,
    primaryWeapon: ShipWeapon(
        name: "Fusion Blaster",
        type: .laser,
        damage: 6,
        energyCost: 2,
        fireWait: 10,
        isTracking: false,
        projectileSpeed: 10,
        heatPerShot: 5
    ),
    specialAbility: ShipSpecial(
        name: "Launch Drones",
        type: .launchFighters,
        energyCost: 1,
        useWait: 2
    ),
    shape: .dreadCommand,
    shieldMax: 35,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.4,
    heatCapacity: 80,
    heatDissipation: 2
)

/// Fungor Sporepod - fungal hive ship.
/// Source: Mycon Podship (crew:20, energy:16, cost:23).
private let fungorSporepod = ShipDefinition(
    name: "Sporepod",
    species: "Fungor",
    faction: .dominion,
    cost: 23,
    maxCrew: 20,
    startingCrew: 20,
    maxEnergy: 16,
    startingEnergy: 16,
    energyRegen: 1,
    energyWait: 6,
    maxThrust: 36,
    thrustIncrement: 9,
    thrustWait: 1,
    turnWait: 1,
    mass: 7,
    primaryWeapon: ShipWeapon(
        name: "Homing Plasmoid",
        type: .tracking,
        damage: 5,
        energyCost: 1,
        fireWait: 8,
        isTracking: true,
        projectileSpeed: 5,
        heatPerShot: 4
    ),
    specialAbility: ShipSpecial(
        name: "Regrow Crew",
        type: .regrowCrew,
        energyCost: 5,
        useWait: 10
    ),
    shape: .sporepod,
    shieldMax: 20,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.3,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Kesh Runner - cowardly escape artist.
/// Source: Spathi Eluder (crew:6, energy:4, cost:18).
private let kesharunner = ShipDefinition(
    name: "Runner",
    species: "Kesha",
    faction: .dominion,
    cost: 18,
    maxCrew: 10,
    startingCrew: 10,
    maxEnergy: 8,
    startingEnergy: 8,
    energyRegen: 1,
    energyWait: 9,
    maxThrust: 35,
    thrustIncrement: 5,
    thrustWait: 0,
    turnWait: 1,
    mass: 1,
    primaryWeapon: ShipWeapon(
        name: "Forward Blaster",
        type: .projectile,
        damage: 1,
        energyCost: 1,
        fireWait: 3,
        isTracking: false,
        projectileSpeed: 9,
        heatPerShot: 1
    ),
    specialAbility: ShipSpecial(
        name: "Rear Cannon",
        type: .rearWeapon,
        energyCost: 0,
        useWait: 0
    ),
    shape: .kesharunner,
    shieldMax: 0,
    shieldRegenRate: 0,
    shieldRegenDelay: 60,
    armorReduction: 0.0,
    heatCapacity: 80,
    heatDissipation: 3
)

/// Synthari Warden - artificial comet ship.
/// Source: Androsynth Guardian (crew:20, energy:24, cost:15).
private let synthariWarden = ShipDefinition(
    name: "Warden",
    species: "Synthari",
    faction: .dominion,
    cost: 15,
    maxCrew: 20,
    startingCrew: 20,
    maxEnergy: 24,
    startingEnergy: 24,
    energyRegen: 1,
    energyWait: 8,
    maxThrust: 24,
    thrustIncrement: 3,
    thrustWait: 4,
    turnWait: 6,
    mass: 10,
    primaryWeapon: ShipWeapon(
        name: "Acid Sphere",
        type: .tracking,
        damage: 2,
        energyCost: 3,
        fireWait: 0,
        isTracking: true,
        projectileSpeed: 4,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Blazer Form",
        type: .specialForm,
        energyCost: 2,
        useWait: 0
    ),
    shape: .warden,
    shieldMax: 20,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.2,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Vokk Harasser - paranoid heavy weapon ship.
/// Source: VUX Intruder (crew:42, energy:42, cost:12).
private let vokkHarasser = ShipDefinition(
    name: "Harasser",
    species: "Vokk",
    faction: .dominion,
    cost: 12,
    maxCrew: 30,
    startingCrew: 30,
    maxEnergy: 35,
    startingEnergy: 35,
    energyRegen: 1,
    energyWait: 8,
    maxThrust: 21,
    thrustIncrement: 7,
    thrustWait: 4,
    turnWait: 6,
    mass: 6,
    primaryWeapon: ShipWeapon(
        name: "Gigawatt Laser",
        type: .laser,
        damage: 1,
        energyCost: 1,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 14,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Parasite Mine",
        type: .parasiteMine,
        energyCost: 8,
        useWait: 7
    ),
    shape: .harasser,
    shieldMax: 20,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.4,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Gorth Reaver - fanatical cloaked attacker.
/// Source: Ilwrath Avenger (crew:22, energy:16, cost:10).
private let gorthReaver = ShipDefinition(
    name: "Reaver",
    species: "Gorth",
    faction: .dominion,
    cost: 10,
    maxCrew: 22,
    startingCrew: 22,
    maxEnergy: 16,
    startingEnergy: 16,
    energyRegen: 4,
    energyWait: 0,
    maxThrust: 25,
    thrustIncrement: 5,
    thrustWait: 0,
    turnWait: 2,
    mass: 7,
    primaryWeapon: ShipWeapon(
        name: "Hellfire Spout",
        type: .cone,
        damage: 1,
        energyCost: 1,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 10,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Shadow Cloak",
        type: .cloak,
        energyCost: 3,
        useWait: 13
    ),
    shape: .reaver,
    shieldMax: 10,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.3,
    heatCapacity: 100,
    heatDissipation: 2
)

/// Drul Skirmisher - bird-like scavenger.
/// Source: Umgah Drone (crew:12, energy:16, cost:7).
private let drulSkirmisher = ShipDefinition(
    name: "Skirmisher",
    species: "Drul",
    faction: .dominion,
    cost: 7,
    maxCrew: 12,
    startingCrew: 12,
    maxEnergy: 16,
    startingEnergy: 16,
    energyRegen: 1,
    energyWait: 6,
    maxThrust: 30,
    thrustIncrement: 6,
    thrustWait: 2,
    turnWait: 2,
    mass: 3,
     primaryWeapon: ShipWeapon(
        name: "Antimatter Cone",
        type: .cone,
        damage: 1,
        energyCost: 1,
        fireWait: 0,
        isTracking: false,
        projectileSpeed: 8,
        heatPerShot: 2
    ),
    specialAbility: ShipSpecial(
        name: "Retro Pulse",
        type: .retroPulse,
        energyCost: 6,
        useWait: 0
    ),
    shape: .skirmisher,
    shieldMax: 10,
    shieldRegenRate: 1,
    shieldRegenDelay: 60,
    armorReduction: 0.1,
    heatCapacity: 80,
    heatDissipation: 3
)
import StarfallCore
import StarfallData

/// The Campaign simulation module.
///
/// Contains the deterministic turn-based strategic simulation. The campaign
/// manages star systems, resources, fleet construction, and movement.
/// When opposing fleets meet, the campaign hands control to the Melee module.

// MARK: - Star System

/// Type of star system.
public enum SystemType: String, Codable, Sendable, CaseIterable {
    /// Can be colonized (provides crew recruitment).
    case life
    /// Can be mined (produces resources).
    case mineral
    /// Neither, but can be fortified.
    case dead
}

/// Build action in progress on a system.
public enum BuildAction: String, Codable, Sendable {
    case mine
    case colony
    case fortification
}

/// A star system on the campaign map.
public struct StarSystem: Hashable, Sendable, Codable {
    public let id: EntityID
    public let name: String
    public let position: Vec2
    public let type: SystemType
    public var owner: Faction?
    public var hasMine: Bool
    public var hasColony: Bool
    public var isFortified: Bool
    public var actionTurnsRemaining: Int
    public var currentAction: BuildAction?
    
    /// Whether a starbase is present at this system.
    public var hasStarbase: Bool
    
    public init(id: EntityID, name: String, position: Vec2, type: SystemType) {
        self.id = id
        self.name = name
        self.position = position
        self.type = type
        self.owner = nil
        self.hasMine = false
        self.hasColony = false
        self.isFortified = false
        self.actionTurnsRemaining = 0
        self.currentAction = nil
        self.hasStarbase = false
    }
}

// MARK: - Fleet

/// A single ship entry within a fleet.
public struct FleetShipEntry: Hashable, Sendable, Codable {
    public let shipIndex: Int
    public var crew: Int
    
    public init(shipIndex: Int, crew: Int) {
        self.shipIndex = shipIndex
        self.crew = crew
    }
    
    public func withCrew(_ newCrew: Int) -> FleetShipEntry {
        FleetShipEntry(shipIndex: shipIndex, crew: newCrew)
    }
}

/// A fleet unit on the campaign map.
public struct FleetUnit: Hashable, Sendable, Codable {
    public let id: EntityID
    public var systemID: EntityID
    public var faction: Faction
    public var ships: [FleetShipEntry]
    public var destinationSystemID: EntityID?
    
    public init(id: EntityID, systemID: EntityID, faction: Faction, ships: [FleetShipEntry]) {
        self.id = id
        self.systemID = systemID
        self.faction = faction
        self.ships = ships
        self.destinationSystemID = nil
    }
    
    public var isEmpty: Bool { ships.isEmpty }
}

// MARK: - Campaign Action

/// An action a player can take during their turn.
public enum CampaignAction: Sendable {
    /// Move fleet from current system to adjacent system.
    case moveFleet(fleetID: EntityID, targetSystemID: EntityID)
    
    /// Build a new ship at the player's starbase system.
    case buildShip(shipIndex: Int)
    
    /// Colonize a life world.
    case colonize(systemID: EntityID)
    
    /// Build a mine on a mineral world.
    case mine(systemID: EntityID)
    
    /// Build fortifications on a dead world.
    case fortify(systemID: EntityID)
    
    /// Recruit crew at a colony.
    case recruitCrew(systemID: EntityID)
    
    /// Besiege a fortified enemy system (attempt to destroy fortifications).
    case besiege(systemID: EntityID)
    
    /// Suttle (destroy) one of own ships to free up resources.
    case scuttle(fleetID: EntityID, shipIndex: Int)
    
    /// Merge two fleets at the same system into one.
    case mergeFleets(fleetID1: EntityID, fleetID2: EntityID)
    
    /// Rebuild a starting fleet at the home starbase (used when the faction
    /// has lost every ship but still holds its starbase).
    case rebuildFleet
    
    /// Pass remaining actions.
    case pass
}

// MARK: - Combat Result

/// Outcome of a campaign combat encounter between two fleets.
public struct CombatResult: Sendable {
    /// Which faction won the encounter (nil = draw, both fleets destroyed).
    public let winnerFaction: Faction?
    
    /// Surviving ships for the attacking faction (crew-damaged).
    public let attackerShips: [FleetShipEntry]
    
    /// Surviving ships for the defending faction.
    public let defenderShips: [FleetShipEntry]
    
    public init(
        winnerFaction: Faction?,
        attackerShips: [FleetShipEntry],
        defenderShips: [FleetShipEntry]
    ) {
        self.winnerFaction = winnerFaction
        self.attackerShips = attackerShips
        self.defenderShips = defenderShips
    }
}

/// A connection between two star systems.
public struct SystemConnection: Hashable, Sendable, Codable {
    public let a: EntityID
    public let b: EntityID
    
    public init(_ a: EntityID, _ b: EntityID) {
        self.a = a
        self.b = b
    }
}

// MARK: - Campaign State

/// Full campaign state.
public struct CampaignState: Sendable, Codable {
    public var systems: [EntityID: StarSystem]
    public var connections: [SystemConnection]
    public var fleets: [EntityID: FleetUnit]
    public var resources: [Faction: Int]
    public var currentTurn: Int
    public var currentFaction: Faction
    public var actionsRemaining: Int

    /// Next fleet ID allocator.
    public var nextFleetID: UInt32

    /// Next system ID allocator (for any runtime-added systems).
    public var nextSystemID: UInt32

    public var isOver: Bool
    public var winner: Faction?
    
    /// Seed used to generate this campaign's map. Stored for display purposes.
    public var seed: UInt64 = 0

    /// Pending combat: set when two fleets collide; the game should drop into melee.
    public var pendingCombat: PendingCombat?

    /// Story event IDs that have already been shown to the player.
    public var firedStoryEvents: Set<String>

    /// Pending story event to display before returning to the campaign map.
    public var pendingStoryEvent: String?

    /// AI difficulty chosen at campaign start. Persisted so a resumed
    /// campaign keeps using the player's choice instead of the hard-coded
    /// turn-based ramp. Defaults to medium (legacy saves have no value).
    public var aiDifficulty: AIDifficulty = .medium

    /// Systems the player's faction (Compact) has ever seen.
    /// A system is revealed when a fleet enters it or an adjacent system.
    /// Once revealed, it stays revealed (explored but may be out of sight).
    public var revealedSystems: Set<EntityID>

    public init() {
        self.systems = [:]
        self.connections = []
        self.fleets = [:]
        self.resources = [.compact: 0, .dominion: 0]
        self.currentTurn = 0
        self.currentFaction = .compact
        self.actionsRemaining = 3
        self.nextFleetID = 1000
        self.nextSystemID = 500
        self.isOver = false
        self.winner = nil
        self.pendingCombat = nil
        self.firedStoryEvents = []
        self.pendingStoryEvent = nil
        self.revealedSystems = []
    }
}

/// Represents a pending combat between two fleets, awaiting melee resolution.
public struct PendingCombat: Sendable, Codable {
    public let attackerFleetID: EntityID
    public let defenderFleetID: EntityID
    public let systemID: EntityID
}
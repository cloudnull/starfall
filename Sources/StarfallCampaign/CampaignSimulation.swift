import StarfallCore
import StarfallData

/// The campaign simulation engine.
///
/// Manages turn-based strategic play: resources, fleet movement,
/// building, and fleet combat. When two opposing fleets arrive at the
/// same system, a combat is triggered and control passes to the Melee module.
public final class CampaignSimulation {
    
    public var state: CampaignState
    private let rng: SeededRNG
    public let seedValue: UInt64
    
    /// Starting resources for each faction.
    private let startingResources: Int = 5
    
    /// Resources generated per turn by the starbase.
    private let starbaseIncome: Int = 1
    
    /// Resources per mine per turn.
    private let mineIncome: Int = 1
    
    /// Turns to complete a build action.
    private let buildTime: Int = 2
    
    /// Crew restored per recruit action (up to ship max).
    private let recruitAmount: Int = 4
    
    /// Chance to destroy fortifications per besiege action (1 in N).
    private let besiegeDenominator: Int = 15
    
    public init(seed: UInt64 = 42) {
        self.rng = SeededRNG(seed: seed)
        self.seedValue = seed
        self.state = CampaignState()
        self.state.seed = seed
        self.setupInitialMap()
    }
    
    // MARK: - Setup
    
    private func setupInitialMap() {
        let generator = CampaignMapGenerator(seed: rng.next())
        let (systems, connections) = generator.generate(systemCount: 25)
        
        state.systems = systems
        state.connections = connections
        
        // Find leftmost and rightmost systems for starting positions.
        let sortedByX = systems.values.sorted { $0.position.x < $1.position.x }
        guard sortedByX.count >= 2 else { return }
        
        let compactHomeID = sortedByX.first!.id
        let dominionHomeID = sortedByX.last!.id
        
        // Set up starting systems.
        if var compactHome = state.systems[compactHomeID] {
            compactHome.owner = .compact
            compactHome.hasStarbase = true
            compactHome.hasColony = compactHome.type == .life
            state.systems[compactHomeID] = compactHome
        }
        
        if var dominionHome = state.systems[dominionHomeID] {
            dominionHome.owner = .dominion
            dominionHome.hasStarbase = true
            dominionHome.hasColony = dominionHome.type == .life
            state.systems[dominionHomeID] = dominionHome
        }
        
        // Starting fleets (each faction gets 2 ships from their roster).
        // Crew values are slightly below startingCrew to reflect wartime damage.
        let compactStartShips = [
            FleetShipEntry(shipIndex: 1, crew: 18), // Striker (max 20)
            FleetShipEntry(shipIndex: 5, crew: 16), // Runner (max 18)
        ]
        
        let dominionStartShips = [
            FleetShipEntry(shipIndex: 8, crew: 18), // Sporepod (max 20)
            FleetShipEntry(shipIndex: 12, crew: 20), // Reaver (max 22)
        ]
        
        let compactFleetID = EntityID(state.nextFleetID)
        state.nextFleetID += 1
        
        let dominionFleetID = EntityID(state.nextFleetID)
        state.nextFleetID += 1
        
        state.fleets[compactFleetID] = FleetUnit(
            id: compactFleetID, systemID: compactHomeID, faction: .compact,
            ships: compactStartShips
        )
        
        state.fleets[dominionFleetID] = FleetUnit(
            id: dominionFleetID, systemID: dominionHomeID, faction: .dominion,
            ships: dominionStartShips
        )
        
        // Starting resources.
        state.resources[.compact] = startingResources
        state.resources[.dominion] = startingResources
        
        state.currentTurn = 1
        state.currentFaction = .compact
        state.actionsRemaining = 3

        // Reveal starting systems to the Compact faction.
        _ = updateRevealedSystems()
    }
    
    // MARK: - Player Action
    
    /// Execute a player action. Returns an error message if the action is invalid.
    @discardableResult
    public func execute(_ action: CampaignAction) -> String? {
        guard !state.isOver else { return "Campaign is over." }
        guard state.actionsRemaining > 0 else { return "No actions remaining." }

        let result: String?
        switch action {
        case .moveFleet(let fleetID, let targetSystemID):
            result = executeMoveFleet(fleetID, targetSystemID)
        case .buildShip(let shipIndex):
            result = executeBuildShip(shipIndex)
        case .colonize(let systemID):
            result = executeColonize(systemID)
        case .mine(let systemID):
            result = executeMine(systemID)
        case .fortify(let systemID):
            result = executeFortify(systemID)
        case .recruitCrew(let systemID):
            result = executeRecruitCrew(systemID)
        case .besiege(let systemID):
            result = executeBesiege(systemID)
        case .scuttle(let fleetID, let shipIndex):
            result = executeScuttle(fleetID, shipSlot: shipIndex)
        case .mergeFleets(let fleetID1, let fleetID2):
            result = executeMergeFleets(fleetID1, fleetID2)
        case .pass:
            // Pass skips remaining actions for this turn.
            state.actionsRemaining = 0
            return nil
        }

        return result
    }

    // MARK: - Action Implementations
    
    private func executeMoveFleet(_ fleetID: EntityID, _ targetSystemID: EntityID) -> String? {
        guard var fleet = state.fleets[fleetID] else { return "Fleet not found." }
        guard fleet.faction == state.currentFaction else { return "Not your fleet." }
        guard fleet.destinationSystemID == nil else { return "Fleet already moving." }
        guard state.systems[targetSystemID] != nil else { return "Target system not found." }
        guard targetSystemID != fleet.systemID else { return "Fleet is already at this system." }
        guard !fleet.ships.isEmpty else { return "Fleet has no ships." }
        
        // Must be connected.
        let isConnected = state.connections.contains {
            ($0.a == fleet.systemID && $0.b == targetSystemID) ||
            ($0.b == fleet.systemID && $0.a == targetSystemID)
        }
        guard isConnected else { return "Target system not connected." }
        
        // Can't move to your own starbase system (it's occupied).
        _ = state.systems[targetSystemID]!
        
        // Check if enemy fleet is already there.
        let enemyAtTarget = state.fleets.values.contains {
            $0.id != fleet.id && $0.systemID == targetSystemID && $0.faction != fleet.faction
        }
        if enemyAtTarget {
            // Combat will be triggered when the fleet arrives.
        }
        
        fleet.destinationSystemID = targetSystemID
        state.fleets[fleetID] = fleet
        state.actionsRemaining -= 1
        
        // Extra turn bonus: if fleet is at a colonized friendly system, gain an action.
        let currentSystem = state.systems[fleet.systemID]!
        if currentSystem.owner == fleet.faction && currentSystem.hasColony {
            state.actionsRemaining += 1
        }
        
        return nil
    }
    
    private func executeBuildShip(_ shipIndex: Int) -> String? {
        guard let cost = getShipCost(shipIndex) else { return "Invalid ship index." }
        guard let resources = state.resources[state.currentFaction] else { return "No resources." }
        guard resources >= cost else { return "Not enough resources." }
        
        // Must have starbase.
        guard let starbaseSystemID = findStarbaseSystem(state.currentFaction) else {
            return "Starbase destroyed."
        }
        
        state.resources[state.currentFaction] = resources - cost
        
        // Create a fleet with the new ship at the starbase.
        let newFleetID = EntityID(state.nextFleetID)
        state.nextFleetID += 1
        
        let shipDef = ShipRoster.all[shipIndex]
        state.fleets[newFleetID] = FleetUnit(
            id: newFleetID,
            systemID: starbaseSystemID,
            faction: state.currentFaction,
            ships: [FleetShipEntry(shipIndex: shipIndex, crew: shipDef.startingCrew)]
        )
        
        state.actionsRemaining -= 1
        return nil
    }
    
    private func executeColonize(_ systemID: EntityID) -> String? {
        guard var system = state.systems[systemID] else { return "System not found." }
        guard system.type == .life else { return "Not a life world." }
        guard !system.hasColony else { return "Already colonized." }
        guard system.owner == nil || system.owner == state.currentFaction else {
            return "Cannot colonize an enemy system."
        }
        
        // Must have a friendly fleet at the system.
        let hasFleet = state.fleets.values.contains {
            $0.systemID == systemID && $0.faction == state.currentFaction
        }
        guard hasFleet else { return "No friendly fleet at system." }
        
        if system.currentAction != nil {
            return "Build action already in progress."
        }
        
        system.currentAction = .colony
        system.actionTurnsRemaining = buildTime
        state.systems[systemID] = system
        state.actionsRemaining -= 1
        return nil
    }
    
    private func executeMine(_ systemID: EntityID) -> String? {
        guard var system = state.systems[systemID] else { return "System not found." }
        guard system.type == .mineral else { return "Not a mineral world." }
        guard !system.hasMine else { return "Already mined." }
        guard system.owner == nil || system.owner == state.currentFaction else {
            return "Cannot mine an enemy system."
        }
        
        let hasFleet = state.fleets.values.contains {
            $0.systemID == systemID && $0.faction == state.currentFaction
        }
        guard hasFleet else { return "No friendly fleet at system." }
        
        if system.currentAction != nil {
            return "Build action already in progress."
        }
        
        system.currentAction = .mine
        system.actionTurnsRemaining = buildTime
        state.systems[systemID] = system
        state.actionsRemaining -= 1
        return nil
    }
    
    private func executeFortify(_ systemID: EntityID) -> String? {
        guard var system = state.systems[systemID] else { return "System not found." }
        guard system.type == .dead else { return "Only dead worlds can be fortified." }
        guard !system.isFortified else { return "Already fortified." }
        guard system.owner == nil || system.owner == state.currentFaction else {
            return "Cannot fortify an enemy system."
        }
        
        let hasFleet = state.fleets.values.contains {
            $0.systemID == systemID && $0.faction == state.currentFaction
        }
        guard hasFleet else { return "No friendly fleet at system." }
        
        if system.currentAction != nil {
            return "Build action already in progress."
        }
        
        system.currentAction = .fortification
        system.actionTurnsRemaining = buildTime
        state.systems[systemID] = system
        state.actionsRemaining -= 1
        return nil
    }
    
    private func executeRecruitCrew(_ systemID: EntityID) -> String? {
        guard let system = state.systems[systemID] else { return "System not found." }
        guard system.hasColony && system.owner == state.currentFaction else {
            return "No friendly colony at this system."
        }
        
        // Find friendly fleets at this system and restore crew.
        var didRecruit = false
        for fleetID in Array(state.fleets.keys) {
            guard var fleet = state.fleets[fleetID],
                  fleet.systemID == systemID,
                  fleet.faction == state.currentFaction else { continue }
            
            var changed = false
            fleet.ships = fleet.ships.map { ship in
                guard ship.shipIndex >= 0 && ship.shipIndex < ShipRoster.all.count else { return ship }
                let def = ShipRoster.all[ship.shipIndex]
                if ship.crew < def.maxCrew {
                    changed = true
                    return FleetShipEntry(
                        shipIndex: ship.shipIndex,
                        crew: min(ship.crew + recruitAmount, def.maxCrew)
                    )
                }
                return ship
            }
            if changed {
                state.fleets[fleetID] = fleet
                didRecruit = true
            }
        }
        
        guard didRecruit else { return "All ships at full crew." }
        state.actionsRemaining -= 1
        return nil
    }
    
    private func executeBesiege(_ systemID: EntityID) -> String? {
        guard let system = state.systems[systemID] else { return "System not found." }
        guard system.isFortified && system.owner != state.currentFaction else {
            return "Nothing to besiege."
        }
        
        let hasFleet = state.fleets.values.contains {
            $0.systemID == systemID && $0.faction == state.currentFaction
        }
        guard hasFleet else { return "No friendly fleet at system." }
        
        let roll = rng.nextInt(upperBound: besiegeDenominator)
        if roll == 0 {
            var sys = system
            sys.isFortified = false
            state.systems[systemID] = sys
            state.actionsRemaining -= 1
            return "Fortifications destroyed!"
        }
        
        state.actionsRemaining -= 1
        return "Siege attempt failed."
    }
    
    private func executeScuttle(_ fleetID: EntityID, shipSlot: Int) -> String? {
        guard var fleet = state.fleets[fleetID] else { return "Fleet not found." }
        guard fleet.faction == state.currentFaction else { return "Not your fleet." }
        guard shipSlot >= 0 && shipSlot < fleet.ships.count else {
            return "Invalid ship slot in fleet."
        }
        
        fleet.ships.remove(at: shipSlot)
        state.fleets[fleetID] = fleet
        state.actionsRemaining -= 1
        return nil
    }
    
    private func executeMergeFleets(_ fleetID1: EntityID, _ fleetID2: EntityID) -> String? {
        guard var fleet1 = state.fleets[fleetID1] else { return "Fleet 1 not found." }
        guard let fleet2 = state.fleets[fleetID2] else { return "Fleet 2 not found." }
        guard fleet1.faction == state.currentFaction else { return "Fleet 1 is not yours." }
        guard fleet2.faction == state.currentFaction else { return "Fleet 2 is not yours." }
        guard fleet1.systemID == fleet2.systemID else { return "Fleets must be at the same system." }
        guard fleet1.destinationSystemID == nil else { return "Fleet 1 is still moving." }
        guard fleet2.destinationSystemID == nil else { return "Fleet 2 is still moving." }
        
        // Merge fleet2's ships into fleet1
        fleet1.ships.append(contentsOf: fleet2.ships)
        state.fleets[fleetID1] = fleet1
        state.fleets.removeValue(forKey: fleetID2)
        state.actionsRemaining -= 1
        return nil
    }
    
    // MARK: - End Turn & Processing
    
    /// End the current faction's turn and process game state.
    /// Returns true if a combat has been triggered and melee should be launched.
    /// When combat is triggered, build processing and income still happen,
    /// but faction switch is deferred until after combat resolves.
    public func endTurn() -> Bool {
        // Process fleet arrivals and combat.
        let combatTriggered = processFleetArrivals()
        
        // Process build completions (always, even if combat was triggered).
        processBuildActions()
        
        // Generate resources (always).
        generateIncome()
        
        // Check victory conditions (always, even if combat was triggered).
        checkVictory()
        
        if combatTriggered {
            return true
        }
        
        // Switch factions only if no combat was triggered.
        if state.currentFaction == .compact {
            state.currentFaction = .dominion
        } else {
            state.currentFaction = .compact
            state.currentTurn += 1
        }
        
        state.actionsRemaining = 3
        
        // Check for story events.
        if !state.isOver {
            checkStoryEvents()
        }
        
        return false
    }
    
    /// Run the AI opponent's turn. Returns true if combat is triggered.
    /// Should be called after endTurn() to play the opponent's turn.
    public func runAITurn() -> Bool {
        let aiFaction = state.currentFaction
        
        // Temporarily switch to AI faction.
        state.currentFaction = aiFaction
        state.actionsRemaining = 3
        
        let combatTriggered = executeAITurn()
        
        return combatTriggered
    }
    
    // MARK: - Fleet Movement & Combat
    
    private func processFleetArrivals() -> Bool {
        var combatTriggered = false
        
        for fleetID in Array(state.fleets.keys) {
            guard var fleet = state.fleets[fleetID],
                  let destID = fleet.destinationSystemID else { continue }
            
            fleet.systemID = destID
            fleet.destinationSystemID = nil
            state.fleets[fleetID] = fleet
            
            // Check for enemy fleet at the same system.
            for otherFleetID in state.fleets.keys where otherFleetID != fleetID {
                guard let otherFleet = state.fleets[otherFleetID],
                      otherFleet.systemID == destID,
                      otherFleet.faction != fleet.faction,
                      otherFleet.destinationSystemID == nil else { continue }
                
                // Combat!
                state.pendingCombat = PendingCombat(
                    attackerFleetID: fleetID,
                    defenderFleetID: otherFleetID,
                    systemID: destID
                )
                combatTriggered = true
                break
            }
            
            if combatTriggered { break }
            
            // If arriving at enemy-owned system without enemy fleet, capture it.
            let system = state.systems[destID]
            if let sys = system, sys.owner != nil && sys.owner != fleet.faction {
                var updatedSys = sys
                if !updatedSys.isFortified {
                    updatedSys.owner = fleet.faction
                    state.systems[destID] = updatedSys
                }
            }
        }
        
        return combatTriggered
    }
    
    /// Resolve a combat encounter after returning from melee.
    /// The meleeOutcome determines which ships survive.
    /// After the melee, proportional losses are applied to the rest of each fleet
    /// so that multi-ship fleets lose ships based on the overall battle outcome.
    public func resolveCombat(attackerFleetID: EntityID, defenderFleetID: EntityID,
                              result: CombatResult) {
        state.pendingCombat = nil
        
        // Update attacker fleet.
        if var attackerFleet = state.fleets[attackerFleetID] {
            // The first ship's outcome is determined by the melee result.
            // Apply proportional losses to the rest of the fleet.
            attackerFleet.ships = applyFleetLosses(
                ships: attackerFleet.ships,
                firstShipCrew: result.attackerShips.first?.crew ?? 0,
                firstShipSurvived: !result.attackerShips.isEmpty,
                winnerFaction: result.winnerFaction,
                ownFaction: attackerFleet.faction
            )
            if attackerFleet.ships.isEmpty {
                state.fleets.removeValue(forKey: attackerFleetID)
            } else {
                state.fleets[attackerFleetID] = attackerFleet
            }
        }
        
        // Update defender fleet.
        if var defenderFleet = state.fleets[defenderFleetID] {
            defenderFleet.ships = applyFleetLosses(
                ships: defenderFleet.ships,
                firstShipCrew: result.defenderShips.first?.crew ?? 0,
                firstShipSurvived: !result.defenderShips.isEmpty,
                winnerFaction: result.winnerFaction,
                ownFaction: defenderFleet.faction
            )
            if defenderFleet.ships.isEmpty {
                state.fleets.removeValue(forKey: defenderFleetID)
            } else {
                state.fleets[defenderFleetID] = defenderFleet
            }
        }
    }
    
    /// Apply proportional losses to a fleet after the lead ship's melee outcome is known.
    /// - Parameters:
    ///   - ships: All ship entries in the fleet
    ///   - firstShipCrew: Crew remaining on the first ship after melee (0 = destroyed)
    ///   - firstShipSurvived: Whether the first ship survived
    ///   - winnerFaction: The winning faction (nil = draw)
    ///   - ownFaction: The fleet's faction
    /// - Returns: Updated ship entries with losses applied
    private func applyFleetLosses(
        ships: [FleetShipEntry],
        firstShipCrew: Int,
        firstShipSurvived: Bool,
        winnerFaction: Faction?,
        ownFaction: Faction
    ) -> [FleetShipEntry] {
        guard ships.count > 1 else {
            // Single-ship fleet: just return what the melee gave us
            return firstShipSurvived ? [ships[0].withCrew(firstShipCrew)] : []
        }
        
        let ownMaxCrew = ships.reduce(0) { $0 + (ShipRoster.all.indices.contains($1.shipIndex) ? ShipRoster.all[$1.shipIndex].maxCrew : 0) }
        guard ownMaxCrew > 0 else { return ships }
        
        let didWin = winnerFaction == ownFaction
        let didLose = winnerFaction != nil && winnerFaction != ownFaction
        
        var result = ships
        
        // Update the first ship based on melee outcome
        if firstShipSurvived {
            result[0] = ships[0].withCrew(firstShipCrew)
        } else {
            result.removeFirst()
        }
        
        let firstShipMaxCrew = ShipRoster.all.indices.contains(ships[0].shipIndex)
            ? ShipRoster.all[ships[0].shipIndex].maxCrew
            : max(1, ships[0].crew)
        
        if didWin {
            // Winner: remaining ships take light damage (reduced crew)
            let winRatio = Double(firstShipCrew) / Double(firstShipMaxCrew)
            let damageRatio = 0.3 + winRatio * 0.4
            let healFactor = damageRatio
            for i in (result.startIndex ..< result.endIndex) {
                if i == result.startIndex && firstShipSurvived { continue } // Already updated above
                let maxCrew = ShipRoster.all.indices.contains(result[i].shipIndex)
                    ? ShipRoster.all[result[i].shipIndex].maxCrew
                    : result[i].crew
                let newCrew = Int(Double(maxCrew) * healFactor)
                result[i] = result[i].withCrew(max(newCrew, maxCrew / 4))
            }
        } else if didLose {
            // Loser: remaining ships take heavy damage
            let firstShipCrewRatio = Double(firstShipCrew) / Double(firstShipMaxCrew)
            let survivalChance = max(0.0, firstShipCrewRatio * 0.6)
            
            var newShips: [FleetShipEntry] = []
            for i in (result.startIndex ..< result.endIndex) {
                let roll = rng.nextDouble(in: 0.0...1.0)
                if roll < survivalChance {
                    let maxCrew = ShipRoster.all.indices.contains(result[i].shipIndex)
                        ? ShipRoster.all[result[i].shipIndex].maxCrew
                        : result[i].crew
                    let newCrew = Int(Double(maxCrew) * survivalChance * 0.6)
                    newShips.append(result[i].withCrew(max(newCrew, 1)))
                }
            }
            result = newShips
        } else {
            // Draw: both sides take moderate damage
            for i in (result.startIndex ..< result.endIndex) {
                let maxCrew = ShipRoster.all.indices.contains(result[i].shipIndex)
                    ? ShipRoster.all[result[i].shipIndex].maxCrew
                    : result[i].crew
                let newCrew = Int(Double(maxCrew) * 0.5)
                result[i] = result[i].withCrew(max(newCrew, maxCrew / 4))
            }
        }
        
        return result
    }
    
    // MARK: - Build Actions & Income
    
    private func processBuildActions() {
        for systemID in Array(state.systems.keys) {
            guard var system = state.systems[systemID] else { continue }
            guard system.actionTurnsRemaining > 0 else { continue }
            
            system.actionTurnsRemaining -= 1
            
            if system.actionTurnsRemaining <= 0 {
                switch system.currentAction {
                case .mine:
                    system.hasMine = true
                case .colony:
                    system.hasColony = true
                    system.owner = system.owner ?? (
                        state.fleets.values.first {
                            $0.systemID == systemID
                        }?.faction
                    )
                case .fortification:
                    system.isFortified = true
                case .none:
                    break
                }
                system.currentAction = nil
            }
            
            state.systems[systemID] = system
        }
    }
    
    private func generateIncome() {
        for faction in Faction.allCases {
            var income = 0
            
            // Starbase income.
            if findStarbaseSystem(faction) != nil {
                income += starbaseIncome
            }
            
            // Mine income.
            for system in state.systems.values where system.owner == faction && system.hasMine {
                income += mineIncome
            }
            
            state.resources[faction] = (state.resources[faction] ?? 0) + income
        }
    }
    
    // MARK: - Victory
    
    /// Check victory conditions. Public so GameController can call it after
    /// combat resolution.
    ///
    /// A faction is defeated only when it has NEITHER a starbase NOR any
    /// surviving fleet. Losing a starbase alone is not instant defeat — the
    /// faction can still fight on with its fleets (and a starbase-less faction
    /// simply cannot build new ships, which is the strategic cost). This avoids
    /// the old redundant clause that treated "no starbase" as automatic loss.
    public func checkVictory() {
        guard !state.isOver else { return }
        
        let dominionLost = findStarbaseSystem(.dominion) == nil &&
            !state.fleets.values.contains { $0.faction == .dominion && !$0.isEmpty }
        let compactLost = findStarbaseSystem(.compact) == nil &&
            !state.fleets.values.contains { $0.faction == .compact && !$0.isEmpty }
        
        if dominionLost {
            state.isOver = true
            state.winner = .compact
            fireVictoryStoryEvent()
        } else if compactLost {
            state.isOver = true
            state.winner = .dominion
            fireVictoryStoryEvent()
        }
    }
    
    private func fireVictoryStoryEvent() {
        let events = CampaignStory.checkEvents(
            turn: state.currentTurn,
            faction: state.currentFaction,
            firedEvents: state.firedStoryEvents,
            isVictory: true,
            winner: state.winner
        )
        
        if let event = events.first {
            state.pendingStoryEvent = event.id
            state.firedStoryEvents.insert(event.id)
        }
    }
    
    // MARK: - Story Events
    
    private func checkStoryEvents() {
        let events = CampaignStory.checkEvents(
            turn: state.currentTurn,
            faction: state.currentFaction,
            firedEvents: state.firedStoryEvents,
            isVictory: state.isOver,
            winner: state.winner
        )
        
        if let event = events.first {
            state.pendingStoryEvent = event.id
            state.firedStoryEvents.insert(event.id)
        }
    }
    
    // MARK: - Helpers
    
    private func findStarbaseSystem(_ faction: Faction) -> EntityID? {
        for system in state.systems.values where system.owner == faction && system.hasStarbase {
            return system.id
        }
        return nil
    }
    
    private func getShipCost(_ index: Int) -> Int? {
        guard index >= 0 && index < ShipRoster.all.count else { return nil }
        let def = ShipRoster.all[index]
        guard def.faction == state.currentFaction else { return nil }
        return def.cost
    }
    
    // MARK: - Query Helpers (for UI)
    
    /// Systems adjacent to the given system.
    public func connectedSystems(to systemID: EntityID) -> [EntityID] {
        var result: [EntityID] = []
        for conn in state.connections {
            if conn.a == systemID { result.append(conn.b) }
            if conn.b == systemID { result.append(conn.a) }
        }
        return result
    }
    
    /// Fleets belonging to the current faction.
    public func currentFactionFleets() -> [EntityID: FleetUnit] {
        Dictionary(uniqueKeysWithValues: state.fleets
            .filter { $0.value.faction == state.currentFaction }
            .map { ($0.key, $0.value) })
    }

    // MARK: - Fog of War

    /// Returns systems currently visible to the given faction
    /// (systems where the faction has a fleet, plus all adjacent systems).
    ///
    /// A fleet that is *in transit* also reveals its **destination** system and
    /// that destination's neighbors. Without this, moving a fleet into the fog
    /// would reveal nothing until End Turn (when `systemID` finally updates),
    /// which made exploration feel broken: the player sends a scout and the map
    /// doesn't lift. Revealing the destination as the fleet travels is what
    /// scouting is supposed to do.
    public func visibleSystems(for faction: Faction) -> Set<EntityID> {
        var visible: Set<EntityID> = []
        for fleet in state.fleets.values where fleet.faction == faction {
            // Current system + its neighbors.
            visible.insert(fleet.systemID)
            for neighbor in connectedSystems(to: fleet.systemID) {
                visible.insert(neighbor)
            }
            // Destination system + its neighbors, while the fleet is en route.
            if let destID = fleet.destinationSystemID {
                visible.insert(destID)
                for neighbor in connectedSystems(to: destID) {
                    visible.insert(neighbor)
                }
            }
        }
        // Also reveal owned systems (starbases, colonies, mines)
        for system in state.systems.values where system.owner == faction {
            visible.insert(system.id)
        }
        return visible
    }

    /// Reveal systems to the player's faction (Compact). Call each turn.
    @discardableResult
    public func updateRevealedSystems() -> Bool {
        let visible = visibleSystems(for: .compact)
        let before = state.revealedSystems.count
        state.revealedSystems.formUnion(visible)
        return state.revealedSystems.count > before
    }

    /// Whether a system is visible (currently in sight) to the current faction.
    public func isSystemVisible(_ systemID: EntityID) -> Bool {
        visibleSystems(for: state.currentFaction).contains(systemID)
    }

    /// Whether a system has ever been revealed to the current faction.
    public func isSystemRevealed(_ systemID: EntityID) -> Bool {
        state.revealedSystems.contains(systemID)
    }
}

// MARK: - Campaign AI

/// Strategic phase for AI decision-making.
private enum AITurnPhase {
    case early   // turns 1-5
    case mid     // turns 6-14
    case late    // turns 15+
}

/// Evaluated strategic situation for AI decisions.
private struct AISituation {
    let myFleetPower: Int
    let enemyFleetPower: Int
    let myShipCount: Int
    let enemyShipCount: Int
    let myResources: Int
    let myHeavyShips: Int
    let myScoutShips: Int
    let turnPhase: AITurnPhase
    let isBehindOnResources: Bool
}

private let aiFeintChance: Double = 0.3
private let aiSupplyTargetThreshold: Int = 3
private let aiScoutFleetSize: Int = 1

extension CampaignSimulation {

    private func executeAITurn() -> Bool {
        let aiFaction = state.currentFaction
        let enemyFaction: Faction = aiFaction == .compact ? .dominion : .compact
        var actionsLeft = 3

        let situation = evaluateSituation(aiFaction, enemy: enemyFaction)

        // Phase 1: Move fleets
        for fleetID in Array(state.fleets.keys) {
            guard let fleet = state.fleets[fleetID],
                  fleet.faction == aiFaction,
                  fleet.destinationSystemID == nil,
                  actionsLeft > 0 else { continue }

            let isFeintCandidate = fleet.ships.count > aiScoutFleetSize &&
                                   rng.nextDouble() < aiFeintChance &&
                                   situation.turnPhase == .mid

            // Skip move if current system has economy to build
            let currentSys = state.systems[fleet.systemID]
            let hasEconomyToBuild = currentSys != nil &&
                ((currentSys!.type == .life && !currentSys!.hasColony && currentSys!.currentAction == nil) ||
                 (currentSys!.type == .mineral && !currentSys!.hasMine && currentSys!.currentAction == nil))

            if isFeintCandidate && !hasEconomyToBuild {
                if executeFeint(fleetID, enemyFaction) {
                    actionsLeft -= 1
                }
            } else if hasEconomyToBuild {
                // Stay and develop this system; economy phase will handle it
            } else if situation.isBehindOnResources {
                if let targetID = findSupplyDisruptionTarget(fleet.systemID, enemyFaction: enemyFaction) {
                    if self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID)) == nil {
                        actionsLeft -= 1
                    } else if let targetID = findBestTarget(fleet.systemID, aiFaction: aiFaction, situation: situation) {
                        if self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID)) == nil {
                            actionsLeft -= 1
                        }
                    }
                } else if let targetID = findBestTarget(fleet.systemID, aiFaction: aiFaction, situation: situation) {
                    if self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID)) == nil {
                        actionsLeft -= 1
                    }
                }
            } else if let targetID = findBestTarget(fleet.systemID, aiFaction: aiFaction, situation: situation) {
                if self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID)) == nil {
                    actionsLeft -= 1
                }
            }
        }

        // Phase 2: Build ships based on fleet composition needs
        while let resources = state.resources[aiFaction],
              resources > 0, actionsLeft > 0 {
            if let shipIndex = selectShipToBuild(aiFaction, situation: situation),
               self.execute(.buildShip(shipIndex: shipIndex)) == nil {
                actionsLeft -= 1
            } else {
                break
            }
        }

        // Phase 3: Economy
        let sortedSystems = state.systems.values.sorted {
            aiEconomyValue($0, aiFaction) > aiEconomyValue($1, aiFaction)
        }
        for system in sortedSystems {
            guard actionsLeft > 0 else { break }

            let hasFleet = state.fleets.values.contains {
                $0.systemID == system.id && $0.faction == aiFaction
            }
            guard hasFleet else { continue }

            if system.type == .life && !system.hasColony {
                if self.execute(.colonize(systemID: system.id)) == nil {
                    actionsLeft -= 1
                }
            } else if system.type == .mineral && !system.hasMine {
                if self.execute(.mine(systemID: system.id)) == nil {
                    actionsLeft -= 1
                }
            } else if system.type == .dead && !system.isFortified && situation.turnPhase == .late {
                if self.execute(.fortify(systemID: system.id)) == nil {
                    actionsLeft -= 1
                }
            }
        }

        return false  // processFleetArrivals will be called by endTurn().
    }

    // MARK: - Situation Evaluation

    private func evaluateSituation(_ aiFaction: Faction, enemy: Faction) -> AISituation {
        let myFleets = state.fleets.values.filter { $0.faction == aiFaction }
        let enemyFleets = state.fleets.values.filter { $0.faction == enemy }

        let myFleetPower = fleetPower(myFleets)
        let enemyFleetPower = fleetPower(enemyFleets)
        let myShipCount = myFleets.reduce(0) { $0 + $1.ships.count }
        let enemyShipCount = enemyFleets.reduce(0) { $0 + $1.ships.count }

        let myHeavy = countByRole(myFleets, minCost: 15)
        let myScout = countByRole(myFleets, maxCost: 10)

        let myResources = state.resources[aiFaction] ?? 0
        let enemyResources = state.resources[enemy] ?? 0

        let phase: AITurnPhase
        if state.currentTurn <= 5 { phase = .early }
        else if state.currentTurn <= 14 { phase = .mid }
        else { phase = .late }

        return AISituation(
            myFleetPower: myFleetPower,
            enemyFleetPower: enemyFleetPower,
            myShipCount: myShipCount,
            enemyShipCount: enemyShipCount,
            myResources: myResources,
            myHeavyShips: myHeavy,
            myScoutShips: myScout,
            turnPhase: phase,
            isBehindOnResources: myResources < enemyResources - aiSupplyTargetThreshold
        )
    }

    private func fleetPower(_ fleets: [FleetUnit]) -> Int {
        fleets.reduce(0) { sum, f in
            sum + f.ships.reduce(0) { s, entry in
                guard entry.shipIndex >= 0 && entry.shipIndex < ShipRoster.all.count else { return s }
                return s + ShipRoster.all[entry.shipIndex].maxCrew
            }
        }
    }

    private func countByRole(_ fleets: [FleetUnit], minCost: Int? = nil, maxCost: Int? = nil) -> Int {
        fleets.reduce(0) { sum, f in
            sum + f.ships.filter { entry in
                guard entry.shipIndex >= 0 && entry.shipIndex < ShipRoster.all.count else { return false }
                let cost = ShipRoster.all[entry.shipIndex].cost
                if let minC = minCost, cost < minC { return false }
                if let maxC = maxCost, cost > maxC { return false }
                return true
            }.count
        }
    }

    // MARK: - Ship Selection

    private func selectShipToBuild(_ aiFaction: Faction, situation: AISituation) -> Int? {
        let affordable = ShipRoster.all.enumerated()
            .filter { $1.faction == aiFaction && $1.cost <= situation.myResources }

        guard !affordable.isEmpty else { return nil }

        let scored = affordable.map { (index: $0.offset, score: shipBuildPriority($0.element, situation: situation)) }
        let best = scored.max(by: { $0.score < $1.score })
        return best?.index
    }

    private func shipBuildPriority(_ def: ShipDefinition, situation: AISituation) -> Int {
        var score = 0

        if def.cost >= 15 {
            score += situation.myHeavyShips < 2 ? 30 : 0
            if situation.turnPhase == .late { score += 10 }
        }

        if def.cost <= 10 {
            score += situation.myScoutShips < 2 ? 20 : 0
            if situation.turnPhase == .early { score += 15 }
        }

        if situation.myFleetPower < situation.enemyFleetPower {
            score += def.maxCrew / 5
        }

        if situation.myShipCount < situation.enemyShipCount {
            score += (30 - def.cost) / 3
        }

        score += def.maxCrew * 10 / max(def.cost, 1)
        return score
    }

    // MARK: - Target Selection

    private func findBestTarget(_ fromID: EntityID, aiFaction: Faction, situation: AISituation) -> EntityID? {
        let connected = connectedSystems(to: fromID)
        let enemyFaction: Faction = aiFaction == .compact ? .dominion : .compact

        var bestID: EntityID?
        var bestScore = Int.min

        for sysID in connected {
            guard let sys = state.systems[sysID] else { continue }
            var score = 0

            let hasEnemyFleet = state.fleets.values.contains {
                $0.systemID == sysID && $0.faction == enemyFaction
            }

            if hasEnemyFleet {
                if situation.myFleetPower >= situation.enemyFleetPower {
                    score = 80
                } else if situation.turnPhase == .late {
                    score = 50
                } else {
                    score = 20
                }
                if sys.hasStarbase { score += 120 }
            } else if sys.owner == enemyFaction {
                score = 60
                if sys.hasMine { score += 40 }
                if sys.hasColony { score += 30 }
            } else if sys.owner == nil {
                score = 30
                if sys.type == .life { score += 25 }
                if sys.type == .mineral { score += 20 }
                let enemyXBias: Double
                if enemyFaction == .dominion { enemyXBias = 1.0 } else { enemyXBias = -1.0 }
                score += Int(sys.position.x * enemyXBias / 50)
            } else {
                score = 5
            }

            if score > bestScore {
                bestScore = score
                bestID = sysID
            }
        }

        return bestID
    }

    // MARK: - Feint Tactics

    private func executeFeint(_ fleetID: EntityID, _ enemyFaction: Faction) -> Bool {
        guard var fleet = state.fleets[fleetID],
              fleet.ships.count > aiScoutFleetSize else { return false }

        let connected = connectedSystems(to: fleet.systemID)
        guard !connected.isEmpty else { return false }

        let decoyTargets = connected.filter { sysID in
            guard let sys = state.systems[sysID] else { return false }
            return sys.owner != enemyFaction || (!sys.hasStarbase && !sys.isFortified)
        }

        guard let decoyID = decoyTargets.first else { return false }

        let cheapestIdx = fleet.ships.indices.min {
            ShipRoster.all[fleet.ships[$0].shipIndex].cost <
            ShipRoster.all[fleet.ships[$1].shipIndex].cost
        }

        guard let idx = cheapestIdx else { return false }
        let decoyShip = fleet.ships.remove(at: idx)

        if fleet.ships.isEmpty {
            state.fleets.removeValue(forKey: fleetID)
        } else {
            state.fleets[fleetID] = fleet
        }

        let decoyFleetID = EntityID(state.nextFleetID)
        state.nextFleetID += 1
        state.fleets[decoyFleetID] = FleetUnit(
            id: decoyFleetID,
            systemID: fleet.systemID,
            faction: fleet.faction,
            ships: [decoyShip]
        )

        _ = self.execute(.moveFleet(fleetID: decoyFleetID, targetSystemID: decoyID))
        return true
    }

    // MARK: - Supply Line Disruption

    private func findSupplyDisruptionTarget(_ fromID: EntityID, enemyFaction: Faction) -> EntityID? {
        let connected = connectedSystems(to: fromID)

        for sysID in connected {
            guard let sys = state.systems[sysID] else { continue }
            guard sys.owner == enemyFaction else { continue }
            if sys.hasMine || sys.hasColony {
                return sysID
            }
        }

        for sysID in connected {
            guard let sys = state.systems[sysID] else { continue }
            if sys.owner == enemyFaction && (sys.hasMine || sys.hasColony || sys.isFortified) {
                return sysID
            }
        }

        return nil
    }

    // MARK: - Economy Value

    private func aiEconomyValue(_ system: StarSystem, _ aiFaction: Faction) -> Int {
        guard system.owner == aiFaction || system.currentAction != nil else { return 0 }

        var score = 0
        if system.type == .life && !system.hasColony { score = 30 }
        if system.type == .mineral && !system.hasMine { score = 25 }
        if system.type == .dead && !system.isFortified { score = 10 }

        let frontLineBias: Double
        if aiFaction == .dominion { frontLineBias = -1.0 } else { frontLineBias = 1.0 }
        score += Int(system.position.x * frontLineBias / 100)

        return score
    }
}
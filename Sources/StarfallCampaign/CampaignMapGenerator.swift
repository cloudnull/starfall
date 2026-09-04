import Foundation
import StarfallCore
import StarfallData

/// Generates a deterministic campaign star map.
///
/// Creates a set of star systems arranged in a left-to-right progression,
/// with the Compact starting on the left and the Dominion on the right.
/// Systems are connected by travel routes forming a graph.
public struct CampaignMapGenerator {
    
    private let rng: SeededRNG
    
    public init(seed: UInt64 = 42) {
        self.rng = SeededRNG(seed: seed)
    }
    
    /// Generate a campaign map with the given number of systems.
    /// Returns (systems, connections).
    public func generate(systemCount: Int = 25) -> ([EntityID: StarSystem], [SystemConnection]) {
        let systems: [EntityID: StarSystem]
        let connections: [SystemConnection]
        
        (systems, connections) = generateMap(count: systemCount)
        
        return (systems, connections)
    }
    
    private func generateMap(count: Int) -> ([EntityID: StarSystem], [SystemConnection]) {
        var systems: [EntityID: StarSystem] = [:]
        var connections: [SystemConnection] = []
        
        // Layout: columns left-to-right, ~5 systems per column.
        let columns = max(3, Int(ceil(Double(count) / 5)))
        let rows = max(3, min(7, (count + columns - 1) / columns))
        let mapWidth: Double = 1200
        let mapHeight: Double = 800
        let margin: Double = 80
        
        var idCounter: UInt32 = 100
        let systemNames = generateSystemNames(count: count)
        var nameIndex = 0
        
        // Place systems in a grid with jitter.
        var placedIDs: [EntityID] = []
        
        for col in 0..<columns {
            for row in 0..<rows {
                guard placedIDs.count < count else { break }
                
                let id = EntityID(idCounter)
                idCounter += 1
                
                let xBase = Double(col) / Double(max(1, columns - 1)) * (mapWidth - 2 * margin) + margin
                let yBase = Double(row) / Double(max(1, rows - 1)) * (mapHeight - 2 * margin) + margin
                
                let jitterX = rng.nextDouble() * 60 - 30
                let jitterY = rng.nextDouble() * 60 - 30
                
                let pos = Vec2(x: xBase + jitterX, y: yBase + jitterY)
                
                // Determine system type: life/mineral/dead.
                // Compact side (left columns) get more life worlds, Dominion side gets more mineral.
                let columnFrac = Double(col) / Double(max(1, columns - 1))
                let typeRoll = rng.nextDouble()
                let type: SystemType
                if columnFrac < 0.3 {
                    type = typeRoll < 0.5 ? .life : (typeRoll < 0.8 ? .mineral : .dead)
                } else if columnFrac > 0.7 {
                    type = typeRoll < 0.3 ? .life : (typeRoll < 0.7 ? .mineral : .dead)
                } else {
                    type = typeRoll < 0.35 ? .life : (typeRoll < 0.7 ? .mineral : .dead)
                }
                
                let name = nameIndex < systemNames.count ? systemNames[nameIndex] : "System-\(placedIDs.count)"
                nameIndex += 1
                
                let system = StarSystem(id: id, name: name, position: pos, type: type)
                systems[id] = system
                placedIDs.append(id)
            }
        }
        
        // Connect systems: grid neighbors + some diagonals for interesting routes.
        let idsPerCol = (count + columns - 1) / columns
        
        for col in 0..<columns {
            for row in 0..<rows {
                let idx = col * idsPerCol + row
                guard idx < placedIDs.count else { continue }
                let currentID = placedIDs[idx]
                
                // Connect to right neighbor.
                let rightIdx = (col + 1) * idsPerCol + row
                if rightIdx < placedIDs.count {
                    connections.append(SystemConnection(currentID, placedIDs[rightIdx]))
                }
                
                // Connect to down neighbor.
                let downIdx = col * idsPerCol + (row + 1)
                if downIdx < placedIDs.count {
                    connections.append(SystemConnection(currentID, placedIDs[downIdx]))
                }
                
                // Diagonal connections (sparse).
                if rng.nextDouble() < 0.3 {
                    let diagIdx = (col + 1) * idsPerCol + (row + 1)
                    if diagIdx < placedIDs.count {
                        connections.append(SystemConnection(currentID, placedIDs[diagIdx]))
                    }
                }
            }
        }
        
        return (systems, connections)
    }
    
    private func generateSystemNames(count: Int) -> [String] {
        let prefixes = [
            "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
            "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
            "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega",
            "Nova", "Vega", "Rigel", "Altair", "Deneb", "Sirius", "Arcturus",
            "Polaris", "Cassiopeia", "Andromeda", "Lyra", "Cygnus", "Orion",
            "Draco", "Phoenix", "Sagitta", "Corvus", "Aquila", "Hydra",
            "Pegasus", "Centaure"
        ]
        
        let suffixes = [
            "Prime", "Major", "Minor", "Alpha", "Secundus", "Tertia",
            "Nexus", "Vale", "Reach", "Breach", "Hollow", "Gate",
            "Hold", "Point", "Station", "Cross", "Drift", "Fall"
        ]
        
        var names: [String] = []
        for i in 0..<count {
            let prefix = prefixes[i % prefixes.count]
            let suffix = suffixes[(i / prefixes.count) % suffixes.count]
            names.append("\(prefix) \(suffix)")
        }
        return names
    }
}
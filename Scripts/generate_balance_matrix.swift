#!/usr/bin/env swift
/// Balance Matrix Generator for Starfall
///
/// Runs every ship against every other ship with AI on both sides at
/// all three difficulty levels. Produces a win-rate matrix written to
/// docs/balance-matrix.md.
///
/// Usage:
///   swift Scripts/generate_balance_matrix.swift
/// Or:
///   swift run gen-balance-matrix (if added as a target)
///
/// The harness uses deterministic seeds so results are reproducible.

import Foundation

// We need to import the Starfall modules. Since this is a script run from
// the project root, we can use swift run or build & execute.
// For simplicity, we'll re-implement the core simulation here using
// the public API from the built modules.

/// Runs a balance tournament between all 14 ships.
/// Each matchup plays N games at each difficulty level.
/// Results are written to docs/balance-matrix.md.

let projectRoot = FileManager.default.currentDirectoryPath
let matchCount = 20  // matches per matchup per difficulty
let arena = ArenaState(
    bounds: Rect(min: Vec2(x: -400, y: -300), max: Vec2(x: 400, y: 300)),
    planetPosition: Vec2.zero,
    planetRadius: 50,
    gravityStrength: 18_000
)

// Import the modules from the built package
let buildDir = "\(projectRoot)/.build/debug"

print("Building modules...")
let build = Process.run("swift", args: ["build"], cwd: projectRoot)
if !build {
    print("ERROR: Build failed")
    exit(1)
}

print("Running balance tournament...")
print("Matchups: 14 ships × 13 opponents × 3 difficulties × \(matchCount) matches = \(14 * 13 * 3 * matchCount) games")

// Results structure: [attacker][defender][difficulty] = wins
var results: [String: [String: [String: Int]]] = [:]

// Initialize results for all ships
let allShips = ShipRoster.all
for attacker in allShips {
    results[attacker.name] = [:]
    for defender in allShips where defender.name != attacker.name {
        results[attacker.name]![defender.name] = [:]
        for diff in ["easy", "medium", "hard"] {
            results[attacker.name]![defender.name]![diff] = 0
        }
    }
}

// Run tournaments
var matchIndex = 0
let totalMatches = 14 * 13 * 3 * matchCount

for attackerShip in allShips {
    for defenderShip in allShips where defenderShip.name != attackerShip.name {
        for difficulty in [AIDifficulty.easy, AIDifficulty.medium, AIDifficulty.hard] {
            let diffStr: String
            switch difficulty {
            case .easy: diffStr = "easy"
            case .medium: diffStr = "medium"
            case .hard: diffStr = "hard"
            }
            
            for gameIndex in 0..<matchCount {
                let seed1 = UInt64(matchIndex * 1000 + gameIndex * 31)
                let seed2 = UInt64(matchIndex * 1000 + gameIndex * 31 + 1)
                
                let s1Pos = Vec2(x: arena.bounds.min.x + 100, y: arena.bounds.min.y + 100)
                let s2Pos = Vec2(x: arena.bounds.max.x - 100, y: arena.bounds.max.y - 100)
                
                let sim = MeleeSimulation(
                    arena: arena,
                    ship1Def: attackerShip,
                    ship1Pos: s1Pos,
                    ship1Facing: .zero,
                    ship2Def: defenderShip,
                    ship2Pos: s2Pos,
                    ship2Facing: Angle(.pi)
                )
                
                // Clear asteroids for consistent testing
                sim.asteroids = []
                
                let pilot1 = AIPilot(difficulty: difficulty, seed: seed1)
                let pilot2 = AIPilot(difficulty: difficulty, seed: seed2)
                
                let maxFrames = 60 * 24  // 60 seconds
                for _ in 0..<maxFrames {
                    if sim.outcome != nil { break }
                    
                    let p1Intent = pilot1.think(
                        own: sim.ship1,
                        opponent: sim.ship2,
                        projectiles: sim.projectiles,
                        arena: sim.arena
                    )
                    let p2Intent = pilot2.think(
                        own: sim.ship2,
                        opponent: sim.ship1,
                        projectiles: sim.projectiles,
                        arena: sim.arena
                    )
                    sim.step(p1Input: p1Intent, p2Input: p2Intent)
                }
                
                if let outcome = sim.outcome {
                    if let winner = outcome.winnerID {
                        if winner == sim.ship1.id {
                            results[attackerShip.name]![defenderShip.name]![diffStr]! += 1
                        }
                    }
                    // Ties don't increment either side
                }
                
                matchIndex += 1
                let progress = Double(matchIndex) / Double(totalMatches) * 100
                if matchIndex % 100 == 0 || matchIndex == totalMatches {
                    print("  Progress: \(matchIndex)/\(totalMatches) (\(String(format: "%.1f", progress))%)")
                }
            }
        }
    }
}

// Generate report
generateReport(results: results, matchCount: matchCount)
print("\nBalance matrix written to docs/balance-matrix.md")

// MARK: - Report Generation

func generateReport(results: [String: [String: [String: Int]]], matchCount: Int) {
    let outputPath = "\(projectRoot)/docs/balance-matrix.md"
    
    var lines: [String] = []
    lines.append("# Starfall Balance Matrix")
    lines.append("")
    lines.append("Generated by `Scripts/generate_balance_matrix.swift`")
    lines.append("")
    lines.append("- **Matches per matchup:** \(matchCount)")
    lines.append("- **Difficulty levels:** Easy, Medium, Hard")
    lines.append("- **AI pilots:** Both sides use AIPilot at the same difficulty")
    lines.append("- **Asteroids:** Disabled for consistent testing")
    lines.append("- **Arena:** bounds=[-400,-300]×[400,300], planet at origin, radius=50, gravity=18,000")
    lines.append("- **Duration:** 60 seconds max (24 FPS × 60 = 1440 frames)")
    lines.append("- **Total games:** \(14 * 13 * 3 * matchCount)")
    lines.append("")
    lines.append("## Ship Index")
    lines.append("")
    for (i, ship) in allShips.enumerated() {
        let side = ship.faction == .compact ? "Compact" : "Dominion"
        lines.append("\(i + 1). **\(ship.name)** (\(ship.species), \(side)) — Cost: \(ship.cost)")
    }
    lines.append("")
    lines.append("## Win Rate Matrix (Medium Difficulty)")
    lines.append("")
    lines.append("Rows = attacker ship, Columns = defender ship. Values are win rates (0-100%).")
    lines.append("Diagonal = N/A (ships don't fight themselves).")
    lines.append("")

    // Header row
    let headerShips = allShips.map { $0.name }
    var header = "| Attacker \\ Defender |"
    for name in headerShips {
        header += " \(name) |"
    }
    lines.append(header)
    
    // Separator
    var separator = "|---------------------|"
    for _ in headerShips {
        separator += "-------|"
    }
    lines.append(separator)
    
    // Data rows
    for attacker in allShips {
        var row = "| \(attacker.name) |"
        for defender in allShips {
            if attacker.name == defender.name {
                row += " — |"
            } else {
                let wins = results[attacker.name]?[defender.name]?["medium"] ?? 0
                let rate = Double(wins) / Double(matchCount) * 100
                row += " \(String(format: "%.0f", rate))% |"
            }
        }
        lines.append(row)
    }
    lines.append("")
    
    // Also generate Easy and Hard matrices
    for diff in ["easy", "medium", "hard"] {
        lines.append("## Win Rate Matrix (")
        lines.append("\(diff.capitalized) Difficulty)")
        lines.append("")
        lines.append("| Attacker \\ Defender |")
        for name in headerShips {
            lines.append("| \(name) |")
        }
        lines.append("")
        
        let sep = "|---------------------|"
        lines.append(sep)
        
        for attacker in allShips {
            var row = "| \(attacker.name) |"
            for defender in allShips {
                if attacker.name == defender.name {
                    row += " — |"
                } else {
                    let wins = results[attacker.name]?[defender.name]?[diff] ?? 0
                    let rate = Double(wins) / Double(matchCount) * 100
                    row += " \(String(format: "%.0f", rate))% |"
                }
            }
            lines.append(row)
        }
        lines.append("")
    }
    
    // Cost-effectiveness analysis
    lines.append("## Cost-Effectiveness Analysis")
    lines.append("")
    lines.append("Win rate weighted by strategic cost. A cheaper ship with good win rates")
    lines.append("is more cost-effective than an expensive one with similar rates.")
    lines.append("")
    lines.append("| Ship | Cost | Avg Win Rate (Med) | Cost-Effectiveness |")
    lines.append("|------|------|---------------------|--------------------|")
    
    for ship in allShips {
        var totalWins = 0
        var totalGames = 0
        for defender in allShips where defender.name != ship.name {
            totalWins += results[ship.name]?[defender.name]?["medium"] ?? 0
            totalGames += matchCount
        }
        let avgRate = Double(totalWins) / Double(totalGames) * 100
        let effectiveness = avgRate / Double(ship.cost)
        lines.append("| \(ship.name) | \(ship.cost) | \(String(format: "%.0f", avgRate))% | \(String(format: "%.2f", effectiveness)) |")
    }
    lines.append("")
    
    // Notes
    lines.append("## Notes")
    lines.append("")
    lines.append("- The original Star Control was deliberately asymmetric: expensive ships")
    lines.append("are expected to beat cheaper ships. Cost-effectiveness, not pure win rate,")
    lines.append("is the proper balance metric.")
    lines.append("- Regenerate this matrix whenever you change combat parameters:")
    lines.append("  `swift Scripts/generate_balance_matrix.swift`")
    lines.append("")
    
    let content = lines.joined(separator: "\n")
    try? content.write(toFile: outputPath, atomically: true, encoding: .utf8)
}

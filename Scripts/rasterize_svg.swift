#!/usr/bin/env swift
/// SVG Asset Verification for Starfall
///
/// Verifies that all required SVG assets exist in Assets/svg/.
/// Also generates a manifest listing all available assets.
///
/// Usage: swift Scripts/rasterize_svg.swift
///
/// Note: The SVGTextureLoader in StarfallRender loads these SVGs at runtime
/// using Core Graphics Image I/O. No pre-rasterization is required — the
/// SVG source files are the authoritative assets.

import Foundation
#if canImport(AppKit)
import AppKit
#endif

let projectRoot = FileManager.default.currentDirectoryPath
let svgRoot = projectRoot + "/Assets/svg"

let requiredShips = [
    "broodstone", "striker", "shifter", "dart", "veil", "runner", "spark",
    "dread_command", "sporepod", "kesha_runner", "warden", "harasser", "reaver", "skirmisher"
]

let requiredProjectiles = ["laser", "missile", "cone", "spread", "projectile"]

let requiredEffects = ["explosion", "thrust_flame", "impact_flash", "shield"]

let requiredPlanets = ["planet_default", "planet_desert", "planet_ice", "planet_gas"]

let requiredUI = ["starfield", "hud_bar_bg", "hud_bar_fill_crew", "hud_bar_fill_energy",
                  "hud_bar_fill_shield", "hud_bar_fill_heat"]

let allRequired: [(String, [String])] = [
    ("ships", requiredShips),
    ("projectiles", requiredProjectiles),
    ("effects", requiredEffects),
    ("planets", requiredPlanets),
    ("ui", requiredUI),
]

var allFound = true
var totalFound = 0
var totalRequired = 0

print("=== Starfall SVG Asset Verification ===")
print()

for (subdir, files) in allRequired {
    print("[\(subdir)]")
    for file in files {
        totalRequired += 1
        let path = "\(svgRoot)/\(subdir)/\(file).svg"
        if FileManager.default.fileExists(atPath: path) {
            print("  ✓ \(file).svg")
            totalFound += 1
        } else {
            print("  ✗ \(file).svg -- MISSING")
            allFound = false
        }
    }
    print()
}

print("Total: \(totalFound)/\(totalRequired) SVG files found")
print(allFound ? "✅ All required SVG assets present" : "❌ Some assets are missing")

// Write manifest
let manifestPath = "\(svgRoot)/manifest.json"
let manifest = [
    "generated_at": ISO8601DateFormatter().string(from: Date()),
    "total_files": totalRequired,
    "categories": Dictionary(uniqueKeysWithValues: allRequired.map { ($0, $1.count) }),
    "files": allRequired.flatMap { category, files in
        files.map { file in
            ["category": category, "name": file, "path": "svg/\(category)/\(file).svg"]
        }
    }
] as [String : Any]

if let manifestData = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted) {
    try? manifestData.write(to: URL(fileURLWithPath: manifestPath))
    print("\nManifest written to \(manifestPath)")
}

exit(allFound ? 0 : 1)

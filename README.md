# Starfall

A native macOS recreation of the gameplay of the original *Star Control* (Accolade, 1990), set in a story inspired by the *Star Control* universe. Built entirely in Swift using SpriteKit and the Swift Package Manager.

## Overview

Starfall faithfully recreates the two halves of the original *Star Control*:

- **Melee** — Real-time, top-down, two-dimensional one-on-one starship combat in an arena with planetary gravity. Each of the 14 ships has a distinct hull, crew complement, energy pool, primary weapon, and special ability. Two-player local combat and single-player campaign battles.
- **Campaign** — A turn-based strategic layer played on a star map. Two rival powers expand across star systems, gather resources, build and move fleets, and engage in battles that drop into the Melee layer. Win by destroying the enemy starbase or eliminating all enemy fleets.

## Features

### Melee Combat
- 14 unique ships with distinct weapons and special abilities
- Planetary gravity that affects both ships and asteroids
- Wrap-around arena (ships and projectiles loop around edges)
- Layered damage system: shields → armor → hull
- Weapon heat and overheat mechanics
- Input recording and playback for replaying matches
- Two-player local combat (keyboard vs keyboard)

### Campaign Mode
- Turn-based strategic layer with 3 actions per turn
- Resource generation from starbases and mining colonies
- Fleet construction with 2-turn build times
- AI opponents with three difficulty levels (Easy, Medium, Hard) scaled by campaign turn
- Progressive difficulty: early turns easier, late turns harder
- Species-specific victory and defeat cinematics

### Technical Highlights
- **Deterministic simulation** — Seeded RNG (splitmix63) ensures reproducible results for replays and campaign outcomes
- **Model-generated SVG assets** — 33 original vector art files authored as the authoritative asset source, loaded at runtime via Core Graphics
- **Procedural audio** — Sound effects and music synthesized in real-time without external audio files
- **Key remapping** — Fully configurable controls persisted via UserDefaults
- **16:9 aspect ratio** — Rendered at 1440×810 to match modern displays
- **113 passing tests** covering physics, combat, AI, campaign, and audio

## Project Structure

```
Sources/
├── StarfallApp/          # App entry point and high-level state machine
├── StarfallCore/         # Core types, math, RNG, enums
├── StarfallData/         # Ship definitions, roster, weapon data
├── StarfallMelee/        # Melee simulation, physics, combat
├── StarfallCampaign/     # Campaign map, turns, fleet management
├── StarfallAI/           # AI pilot for melee and campaign
├── StarfallInput/        # Input handling and key binding management
├── StarfallRender/       # SpriteKit rendering, UI scenes, HUD
└── StarfallAudio/        # Procedural audio synthesis

Scripts/                   # Build, packaging, asset tools
Assets/svg/                # Authoritative SVG assets (33 files)
Tests/                     # 113 unit/integration tests
docs/                      # Design docs, decisions, progress tracking
```

## Building

### Prerequisites
- macOS 14.0+ (Sonoma)
- Swift 6.0+ toolchain

### Build
```bash
swift build
```

### Run Tests
```bash
swift test --disable-swift-testing
```

> Note: The Swift Testing framework crashes on this macOS/Xcode version. The project uses XCTest instead.

### Build App Bundle
```bash
./Scripts/build_app_bundle.sh
```

This creates a distributable `.app` bundle with proper icon, entitlements, and embedded SVG assets.

## Playing

### Controls (Player 1)
- **W** — Thrust
- **A / D** — Turn left / right
- **Space** — Fire primary weapon
- **Control** — Fire special ability
- **Enter** — Confirm / advance (in menus and post-match)

### Controls (Player 2)
- **Up Arrow** — Thrust
- **Left / Right Arrows** — Turn
- **0** — Fire primary weapon
- **=** — Fire special ability

### Key Remapping
Access key bindings through the Settings menu from the main menu. Binds are persisted in UserDefaults.

## Ship Roster

The 14 ships are inspired by the original *Star Control* roster:

| Ship | Role | Special Ability |
|------|------|-----------------|
| Dart | Balanced scout | Speed boost |
| Broodthor | Heavy assault | Shield charge |
| Dread Command | Capital ship | Point defense |
| Harasser | Fast attacker | Cloak |
| Kesha Runner | Support | Energy transfer |
| Reaver | Gunship | Weapon upgrade |
| Runner | Scout | Extra turn |
| Shifter | Utility | Shape-shift |
| Skirmisher | Artillery | Long-range shot |
| Spark | Fragile glass cannon | Power shot |
| Sporepod | Defensive | Spawn fighters |
| Striker | Assault | Ramming speed |
| Veil | Stealth | Invisibility |
| Warden | Defender | Area shield |

## Development

### Physics Model
- **Simulation:** 24 FPS fixed timestep
- **Rendering:** 60 FPS target with interpolation
- **Friction:** Per-frame velocity damping `0.02 + 0.02/(mass+1)`
- **Thrust:** Applied directly to velocity (no mass division)
- **Gravity:** Central gravity well at 18,000 strength
- **Asteroids:** Velocity capped at 3.0 px/frame

### Combat System
- **Shields:** Energy weapons fully absorbed; ballistics split 60/40
- **Armor:** Flat damage reduction
- **Heat:** Overheat hysteresis prevents firing when overheated
- **Crew:** Hull health; ship destroyed when crew reaches 0

### Campaign Progression
- 3 actions per turn per side
- Starbases generate 1 resource per turn
- Mining colonies take 2 turns to build, then generate 1 resource per turn
- Build actions take 2 turns to complete
- Extra turn when moving from colonized friendly systems

## Documentation

- [`docs/DECISIONS.md`](docs/DECISIONS.md) — Design decisions and rationale
- [`docs/PROGRESS.md`](docs/PROGRESS.md) — Development progress and status
- [`docs/balance-matrix.md`](docs/balance-matrix.md) — Ship balance test results
- [`docs/follow-up.md`](docs/follow-up.md) — Post-phase 10 follow-up work
- [`docs/ASSET-LICENSES.md`](docs/ASSET-LICENSES.md) — Asset licensing verification
- [`prompt.md`](prompt.md) — Full development prompt and scope

## License

This is a from-scratch recreation. All assets, code, and audio are first-party original work. No copyrighted assets from the original *Star Control* are used.

---

*Starfall is a learning/exercise project, not a commercial product.*

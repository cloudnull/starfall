# Decisions Log

Every design decision not dictated by the project brief is recorded here.
This file mirrors the tracked decisions in the workspace.

---

## Arena boundary rule: wrap-around
**Outcome:** Arena boundary uses wrap-around. Ships crossing one edge appear at the opposite edge.
**Reasoning:** The official Star Control website explicitly states this behavior. Hard walls would break the gravity-whip mechanic.
**Alternatives rejected:** Hard wall (not original behavior), Bounce (not original behavior).

## SC2 ship properties table as authoritative reference
**Outcome:** Ship stats from the SC2/Ur-Quan Masters table are the authoritative baseline.
**Reasoning:** Only complete, published stat table available. SC1 values not documented anywhere. Differences described as "slight."
**Alternatives rejected:** Guessing SC1 values (violates research mandate), approximate values (forbids fabrication).

## Original names and story under IP guardrail
**Outcome:** All names and story content are original. Kaelen Compact vs Vexari Dominion.
**Reasoning:** Star Control trademark unavailable. Story inspired by source structure, not content.
**Alternatives rejected:** Using source names (trademark risk), thin retelling (violates IP guardrail).

## Added mechanics: shields, heat, and armor (intentional enhancement)
**Outcome:** Shields, weapon heat/overheat, and armor damage reduction were added on top of the original Star Control mechanics.
**Reasoning:** These systems add tactical depth without breaking the core gameplay loop. The original SC1 had only crew/energy/weapons/specials; adding a third resource (energy management between weapons and specials) is the existing tension. Shields add a reactive layer (dodge vs block), heat adds weapon management, and armor adds damage mitigation variety. These are enhancements, not replacements, for the original crew/energy tension.
**Alternatives rejected:** Exact SC1 mechanics only (too sparse for a modern audience), removing crew entirely (loses the HP/strategic cost link).

## Ship stat changes from research dossier (intentional balance)
**Outcome:** Several ships have stat changes from the cited SC2 values:
- **Dart (Paelin/Arilou):** crew 6→12, maxThrust 40→22, thrustIncrement 40→18. Rationale: The original Dart was extremely fragile (6 HP) and overpowered in thrust (40/0 = instant max speed). Doubling crew and reducing thrust makes it survivable and balanced for the enhanced combat system.
- **Kesha Runner (Spathi):** crew 6→10, energy 4→8. Rationale: 4 energy was too restrictive for a ship meant to escape. 6 crew was too fragile in the enhanced damage model.
- **Harasser (Vokk/VUX):** crew 42→30, energy 42→35. Rationale: Original VUX Intruder was overpowered in the "big target with big stats" archetype. 42 crew took too long to whittle down with the added shield system.
**Alternatives rejected:** Using exact original values (creates balance issues with added mechanics), proportional scaling (too complex to reason about).

## Thrust physics model: maxThrust and thrustIncrement used directly
**Outcome:** Thrust increment is added directly to velocity (not divided by mass). MaxThrust is the absolute speed cap (not divided by mass). Mass only affects turn rate and gravity.
**Reasoning:** The original Star Control physics treats thrustIncrement as the per-step acceleration added to velocity, and maxThrust as its speed cap. Mass affects turning (turnWait) and gravity susceptibility, not thrust acceleration. The original implementation divided by mass, which was incorrect and caused ships to barely move.
**Alternatives rejected:** Dividing by mass (original implementation bug), using mass as acceleration modifier (doesn't match source).

## Friction model: velocity-only damping
**Outcome:** Friction is applied only to the velocity vector at the end of each simulation step, not to the speed scalar independently.
**Reasoning:** The `applyFriction` function was being called twice — once on the speed scalar and once on velocity. The speed scalar is only used for display and thrust cap checks, not for actual physics. Applying friction to velocity alone is sufficient and prevents double-damping.
**Status:** Fixed from the implementation (was a confirmed bug).

## isUnderFire AI fix: proximity check
**Outcome:** `isUnderFire` now checks if enemy projectiles are within 150 world units of the target, rather than returning true whenever any enemy projectile exists.
**Reasoning:** The original implementation `projectiles.contains { $0.ownerShipID != targetID }` returned true for any enemy projectile in the arena, regardless of distance. This caused the AI to waste energy on defensive specials (shields, cloaks, point defense) even when not actually under threat.
**Status:** Fixed from a confirmed bug.

## Campaign combat: deterministic RNG
**Outcome:** `applyFleetLosses` in CampaignSimulation uses the seeded `SeededRNG` instead of `Double.random(in:)`.
**Reasoning:** Campaign combat resolution must be deterministic for replay and test reproducibility. Using the system RNG broke this.
**Status:** Fixed from a confirmed bug.

## SVG assets: model-generated vector art
**Outcome:** All ship sprites, projectiles, effects, planets, and UI elements are authored as original SVG files in Assets/svg/. The SVGTextureLoader reads these at runtime and converts them to SKTextures via Core Graphics Image I/O.
**Reasoning:** Section 9 of the spec requires original model-generated SVG as the authoritative art source. The SVG files are committed to the repo and are regenerable by a single script (Scripts/rasterize_svg.swift).
**Alternatives rejected:** Sourced raster sprites (IP risk, no zoom fidelity), hand-coded CGPath (not SVG, not in spec).

## App bundle packaging: script-based
**Outcome:** App bundle is created by Scripts/build_app_bundle.sh, which builds in release mode, creates the .app structure, copies Info.plist/entitlements/icon, and copies SVG assets into the bundle's Resources.
**Reasoning:** Section 13 requires a distributable .app bundle. SPM doesn't create .app bundles natively, so a shell script wraps the release binary.
**Alternatives rejected:** Xcode project (adds complexity, SPM is the build system), manual packaging (not reproducible).

## Planet collision: position and velocity must be applied
**Outcome:** `applyPlanetCollision` now modifies the inout position and velocity parameters to push the ship clear of the planet and remove inward momentum.
**Reasoning:** The function computed newPos and newVel but only returned them in the tuple — the inout parameters were never assigned. This meant ships stayed inside the planet and relied on `ensureShipClearOfPlanet` as a separate safety net, which could cause inconsistent behavior.
**Status:** Fixed from a confirmed bug.

## Unverified items from research dossier
1. **Exact gravity formula** — Using gravityStrength=18,000 with inverse-square law: force = strength / max(distSquared, 2500). This produces a usable slingshot at moderate distances while preventing singularity at close range.
2. **Ship-to-ship collision damage** — Proportional to overlap depth (max(1, overlap/2)), with full momentum reflection.
3. **Camera zoom algorithm** — Linear interpolation between 1.0x (far) and 1.4x (close) based on inverse ship separation.
4. **Starting fleet compositions** — Two ships per faction at campaign start: Compact gets Striker + Runner, Dominion gets Sporepod + Reaver.
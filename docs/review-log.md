# Adversarial Review Log

Reviews are recorded at each phase gate per section 11 of the project brief.

---

## Phase 0 Review

### Correctness
- [x] Ship stats cross-referenced between wiki table and weapon list page -- consistent
- [x] Faction membership verified against multiple wiki pages -- consistent
- [x] No fabricated numbers; all stats sourced from wiki.starcontrol.com Table of ship properties

### Design Fidelity
- [x] All 14 SC1 ships accounted for in research dossier
- [x] Each ship's primary weapon and special ability documented with behavior
- [x] Melee physics (wrap-around, gravity, inertia) verified from official site
- [x] Campaign mechanics verified from multiple sources

### Findings
None. Research phase -- no code to review.

---

## Phase 10 Review -- Finalization Sweep

### Correctness
- [x] Double endTurn() call found and fixed in CampaignScene/GameController
- [x] endTurn() early return on combat found and fixed -- builds/income/victory now processed
- [x] Campaign turn cycle resumption after combat found and fixed via state machine
- [x] checkVictory() visibility fixed (made public) for post-combat calls
- [x] Invalid starting fleet crew values found and corrected (Runner 22 > max 18)
- [x] Kamikaze damage using stale speed scalar fixed (now uses velocity.length)
- [x] Camera zoom ignoring arena wrap-around found and fixed
- [x] Force-unwrap crash in CampaignScene tooltip parsing fixed
- [x] Force-unwrap on aiDifficulty in GameController fixed

### Determinism
- [x] No wall-clock reads in simulation modules
- [x] All RNG uses SeededRNG with explicit seeds
- [x] Replay system verified: MeleeReplayPlayer re-simulates from recorded inputs
- [x] Campaign map generation is deterministic (seeded)

### Concurrency and Safety
- [x] No force-unwraps in simulation core
- [x] All public types are Sendable or properly isolated
- [x] @MainActor isolation on SKScene subclasses
- [x] No unhandled errors (all try? used with clear intent for non-fatal paths)

### Design Fidelity
- [x] All 14 ships implemented with correct stats from research dossier
- [x] All 14 special abilities implemented (shield, cloak, specialForm, teleport, kamikaze, launchFighters, regrowCrew, rearWeapon, pointDefense, parasiteMine, retroPulse, crystalSwarm, morphShift, sirenCall, none)
- [x] Arena wrap-around implemented per official Star Control documentation
- [x] Gravity slingshot mechanics work (gravity whip tested in AI)
- [x] Ship-to-ship collision causes damage
- [x] Ship-to-planet collision causes damage
- [x] Asteroids implemented (occasional asteroids in arena)

### Player Experience
- [x] HUD shows shield, hull, heat, energy, primary cooldown, special cooldown
- [x] Match mode label shows (2P, vs AI, REPLAY, Campaign)
- [x] Pause menu with Resume/Quit
- [x] Replay controls (D to cycle speed, Space to step, Z to rewind)
- [x] Campaign tooltips on hover for systems and fleets
- [x] End Turn button visible on campaign screen
- [x] Build progress indicators on systems
- [x] Victory and defeat cinematic scenes with story text
- [x] Opening briefing on campaign start

### Performance
- [x] Build succeeds with zero warnings
- [x] Test suite runs in <0.02 seconds (103 tests)
- [x] No unnecessary computation in simulation loop

### Findings from Finalization Sweep
1. **Double endTurn()** (Confirmed) -- CampaignScene.handleEndTurn() and GameController.campaignEndTurn() both called sim.endTurn(). Fixed.
2. **Combat interrupt drops turn state** (Confirmed) -- endTurn() returned early on combat, skipping income, builds, and victory check. Fixed by processing all steps before the combat check.
3. **Campaign turn not resumed** (Confirmed) -- After melee combat, campaignEndTurn() was not re-invoked. Fixed with campaignTurnStep state machine.
4. **checkVictory() private** (Confirmed) -- Could not be called from GameController after combat resolution. Made public.
5. **Invalid starting crew** (Confirmed) -- Runner had crew=22 but maxCrew=18. Corrected to valid values.
6. **Stale speed in kamikaze** (Confirmed) -- ship.speed was updated at end of frame, so collision detection used stale value. Fixed to use velocity.length.
7. **Camera zoom ignored wrap** (Confirmed) -- Ships on opposite sides of arena showed maximum separation instead of wrap distance. Fixed.
8. **Force-unwrap crash** (Confirmed) -- CampaignScene tooltip parsing used `UInt32(...)!`. Replaced with guard let.
9. **Missing macOS menu bar** (Confirmed) -- App had no menu bar. Added standard macOS menu with all required shortcuts.
10. **Dead code** (Confirmed) -- GameScene enum, autoAdvanceTimer, prevShipPosition, applyFriction comment all removed.
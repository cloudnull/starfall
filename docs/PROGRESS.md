# Starfall Progress

## Current Phase: Phase 10 -- FINALIZATION SWEEP (complete)

## What is Done
- [x] Phase 0: Research dossier, story bible, asset licenses, decisions, review log
- [x] Phase 1: SPM project, all 9 modules, Core types, Data (14 ships), stubs, App entry, 28 tests
- [x] Phase 2: `Vec2` compound assignment operators (`+=`, `-=`)
- [x] Phase 2: `MeleePhysics.swift` -- thrust, turn, friction, gravity, arena wrap, planet collision, projectile collision, special timers
- [x] Phase 2: `MeleeSimulation.swift` -- full simulation engine with two ships, projectiles, input processing, weapon firing, tracking projectiles, special abilities, ship-ship collision, match outcome detection
- [x] Phase 2: `InputProcessor` in StarfallInput -- maps key codes to InputIntent for P1 (W/S + A/D + Space + Control) and P2 (arrow keys + 0 + =)
- [x] Phase 2: `MeleeScene` in StarfallRender -- SpriteKit scene with star field, planet, ship rendering (triangle shapes colored by faction), projectile dots, HUD (crew/energy bars, timer, match-over label)
- [x] Phase 2: `MeleeRenderer` -- bridges SKView and MeleeScene
- [x] Phase 2: `MeleeGameController` in StarfallApp -- game loop via Timer at 60fps → FixedTimestep at 24fps → simulation step → render update
- [x] Phase 2: `StarfallApp` entry point launches a Broodstone vs Dread Command match
- [x] Phase 2: 11 MeleeSimulation unit tests (initial state, thrust, turn, firing, match end, determinism, arena wrap, energy recharge, timer, tie)
- [x] 39 total tests pass, `swift build` clean

### Phase 3
- [x] `SpecialType` enum added to `ShipDefinition.swift` with 14 special ability types
- [x] All 14 ships in `ShipRoster.swift` wired to their respective `SpecialType`
- [x] `ShipState` extended with new fields: `pointDefenseTimer`, `parasiteTimer`, `sirenCallTimer`, `retroPulseSlowTimer`, `isKamikaze`, `kamikazeTimer`, `isMorphLocked`
- [x] `updateSpecialTimers` in `MeleePhysics.swift` handles all new timers
- [x] `activateSpecial` rewritten as switch on `SpecialType` with distinct behavior per ship
- [x] Per-frame effects: parasite drain (1 crew/12 frames), retro-pulse slow (95% speed), point defense (auto-intercept), kamikaze mutual destruction on collision
- [x] `SelectScene` in StarfallRender -- SpriteKit ship select screen with clickable buttons for both factions
- [x] `MeleeGameController` state machine: Select → Play → Match Over (Enter to return) → Select
- [x] `InputProcessor` extended with `isEnterPressed` for match-over restart
- [x] HUD shows "Press Enter to return" on match over
- [x] `ShipShape` enum with 14 path-based silhouettes in `ShipDefinition.swift`
- [x] `MeleeScene.shipShapePath()` draws all shapes. Visual effect overlays: kamikaze glow, parasite dot, point defense field, retro-pulse ring, morph/special form ring.

### Phase 3d -- AI Pilot + Single-Player Mode
- [x] `AIPilot` in StarfallAI -- decision logic for thrust, turn, fire primary, fire special, evasive maneuvers, and hard-mode tactics (gravity whip, kiting)
- [x] `CircularBuffer` delays AI input by difficulty-dependent frames (easy=12, medium=6, hard=2)
- [x] `AIDifficulty` moved to `StarfallCore` so `StarfallRender` can reference it without depending on `StarfallAI`
- [x] `SelectScene` updated with 1P/2P mode toggle, difficulty selector (Easy/Medium/Hard), LAUNCH button
- [x] `SelectResult` struct carries ship picks + AI difficulty
- [x] `MeleeGameController` wired to create `AIPilot` for single-player; P2 input comes from `pilot.think(...)` instead of `InputProcessor`
- [x] `MeleeSimulation.arena` made public for AI access
- [x] `StarfallApp` links against `StarfallAI`
- [x] `StarfallAITests` target with 12 tests (basic behavior, fire, evasion, special decisions, reaction delay, determinism)
- [x] Fixed `isUnderFire` bug: was checking projectile owner == target (own projectiles), now checks != (incoming)
- [x] 51 total tests pass, `swift build` clean

### Phase 4 -- Procedural Audio
- [x] `AudioEngine` manages `AVAudioEngine` graph with separate SFX/music mixer nodes
- [x] `SoundSynthesizer` generates one-shot buffers: weapon fire, impact, explosion, thruster, UI click, victory, defeat
- [x] `MusicSynthesizer` generates looping stereo buffers: menu, combat, campaign, victory, defeat
- [x] `AudioEngine.play(.weaponFire)`, `.impact`, `.explosion`, `.victory`, `.defeat` wired into `MeleeGameController`
- [x] Music transitions: menu music on select screen, combat music on match start, menu music on return to select
- [x] Volume baked into buffer samples (macOS `AVAudioMixerNode` lacks `outputParameters`)
- [x] Fixed `arc4random()` type conversion for macOS/Swift 6

### Phase 5 -- HUD Polish
- [x] Crew and energy **number labels** (e.g. "18/36", "30/30") beside each bar
- [x] **Primary cooldown bar** (thin white bar under crew bar, fades when ready)
- [x] **Special cooldown bar** (thin orange bar under energy bar, fades when ready)
- [x] **Special ability name label** per player (e.g. "D.O.G.I.", "Force Shield")
- [x] **Match mode label** on P2 side: shows "2P" or "vs AI (Hard)" etc.
- [x] `MeleeRenderer.render()` accepts optional `matchMode` string, passed from `MeleeGameController`
- [x] `MeleeScene` stores `matchMode` on first frame, persists across updates
- [x] Cooldown bars fill left-to-right as cooldown expires (1 - cooldown/max)
- [x] Cooldown bars alpha=0 when not on cooldown
- [x] Cleaned up unused `prevShip1Crew`/`prevShip2Crew` fields from `MeleeGameController`

### Phase 6 -- Campaign Mode
- [x] `CampaignTypes.swift`: `StarSystem`, `FleetShipEntry`, `FleetUnit`, `CampaignAction`, `CombatResult`, `CampaignState`, `PendingCombat`
- [x] `CampaignMapGenerator.swift`: Deterministic map generation — grid layout with jitter, life/mineral/dead distribution biased by side, diagonal route connections
- [x] `CampaignSimulation.swift`: Turn-based engine — 3 actions/turn, resource income (1/starbase + 1/mine), fleet movement on connected systems, build actions (mine/colony/fort, 2-turn completes), recruit fleet, besiege (combat handoff), scuttle, pass, AI turn logic, combat handoff/resolution, victory conditions (destroy enemy starbase or eliminate all enemy fleets)
- [x] `CampaignScene.swift`: SpriteKit star map renderer — connection lines, fleet markers, system markers (life/mineral/dead/starbase/colony/mine/fort), click interaction (fleet select → adjacent system click to move), End Turn button, combat trigger, HUD
- [x] `MainMenuScene.swift`: Main menu with Melee and Campaign mode buttons
- [x] `GameController.swift`: High-level app controller managing flow: MainMenu → MeleeSelect/Melee OR Campaign → Combat Handoff → Melee → Return to Campaign
- [x] `main.swift` updated to instantiate `GameController`
- [x] Colony bonus: extra turn when moving from a colonized friendly system
- [x] Besiege triggers melee combat; result resolves back into campaign simulation
- [x] AI turn: build ships, move fleets toward enemy systems, besiege when in range, colonize life stars, build mines
- [x] `StarfallCampaignTests` target with 17 tests (map generation, simulation setup, movement, build, turn logic, income, victory)
- [x] 68 total tests pass, `swift build` clean

### Phase 7 -- Story Delivery + Campaign UI Polish
- [x] `CampaignStory.swift`: 9 story events — opening briefing, first loss, Kesh-Varr defector, first barrier world, mid-crisis, glory run, final push, compact victory, dominion defeat
- [x] `StoryEvent` struct: id, title, paragraphs, speaker. `CampaignStory.checkEvents()` fires events by turn number and game state
- [x] `CampaignState` extended with `firedStoryEvents: Set<String>` and `pendingStoryEvent: String?`
- [x] `CampaignSimulation.endTurn()` checks for story events after turn processing; `checkVictory()` fires epilogue events
- [x] `BriefingScene.swift`: SpriteKit briefing scene — dim overlay, title, speaker, paginated body text, click-to-advance
- [x] `GameController` wiring: opening briefing on campaign start, mid-campaign briefings between turns, victory/defeat epilogues with return-to-main-menu path
- [x] `GameController.Screen` extended with `.briefing` case. `showBriefing()` / `closeBriefing()` manage transitions
- [x] Campaign over state now shows epilogue scene (not bare status text), then returns to main menu on click
- [x] CampaignScene UI polish: mouse-move tooltips for systems (name, type, owner, starbase/colony/mine/fort badges)
- [x] CampaignScene UI polish: mouse-move tooltips for fleets (faction, ship count, system, ship names)
- [x] Build progress indicators show action type and turns remaining (e.g. "colony (1)")
- [x] `CampaignStoryTests` with 11 tests (event existence, turn triggers, fired skip, victory/defeat, uniqueness, count)
- [x] 79 total tests pass, `swift build` clean

### Phase 8 -- Campaign AI Refinement + Melee Replay
- [x] Melee replay system: `ReplayTypes.swift` (`MeleeReplayFrame`, `MeleeReplay`), `ReplayPlayer.swift`, `ReplayRecorder.swift`, `ReplayDemo.swift`
- [x] `generateDemoReplay()` creates deterministic AI-vs-AI demo (seed=42)
- [x] `SelectScene` "DEMO" button launches replay mode; `GameController` drives `MeleeReplayPlayer` at 24 FPS
- [x] Campaign AI replaced with three-tier strategic AI:
  - **Fleet composition**: evaluates heavy/scout/support roles, fills gaps based on current fleet vs enemy
  - **Feint tactics**: mid-game decoy detachments split from larger fleets, targeting neutral systems
  - **Supply disruption**: when behind on resources, AI targets enemy mines and colonies
  - **Economy priority**: AI stays at systems with pending builds rather than moving away
- [x] `AIStrategicSituation` struct and `AITurnPhase` enum for AI decision-making
- [x] 7 new AI tests. 95 total tests pass. `swift build` clean.

## What is Next
- No more planned phases — arena polish complete.

## Known Broken Things
- Swift Testing framework crashes on this macOS/Xcode (signal 5). Workaround: `swift test --disable-swift-testing`
- Xorshift128+ bit-shift pattern causes Swift 6.3.2 optimizer to hang. Replaced with splitmix63.
- `CADisplayLink(target:selector:)` is unavailable on modern macOS with strict concurrency. Using `Timer` at 60fps instead.
- `SKShapeNode.lineDashPattern` / `lineDash` are iOS-only — dashed lines omitted on macOS.
- `AVAudioUnitGain` is iOS-only. Volume applied by multiplying buffer samples in-place.
- `AVAudioMixerNode.outputParameters` is iOS-only. Cannot adjust mixer volume after connection — volume is baked into buffer.
- `AVAudioPCMBuffer.numberChannels` is not available — use `buffer.format.channelCount` instead.
- `arc4random() / Double(UInt32.max)` fails type check — cast explicitly: `Double(arc4random()) / 4294967295.0`

## Build Status
- `swift build` -- succeeds, zero warnings
- `swift test --disable-swift-testing` -- 103 tests, 0 failures

## Notes for Resumption
- Arena uses wrap-around, not walls or bounce
- Frame rate: 24 FPS simulation, 60 FPS render target
- SeededRNG uses splitmix63, not Xorshift128+ (compiler bug)
- Tests use XCTest, not Swift Testing (framework crash bug)
- `ShipDefinition` has `primaryWeapon`, `specialAbility`, and `shape` only.
- `ShipState` uses `primaryCooldown`, `specialCooldown` and 7 effect timers.
- `MeleeScene` is `@MainActor` to satisfy SKScene actor isolation
- `MeleeGameController` is `@MainActor` to work with AppKit on main thread
- P1 controls: W=thrust, A/D=turn, Space=fire, Control=special
- P2 controls: Up=thrust, Left/Right=turn, 0=fire, =special
- Input uses `NSEvent.addLocalMonitorForEvents` for key-down capture
- Match flow: MainMenu → MeleeSelect (click ships, choose mode, LAUNCH) → MeleeScene → match over (Enter returns to main menu)
- `GameController` owns the high-level state machine: MainMenu ↔ Melee ↔ Campaign
- `MeleeGameController` owns the state machine between `SelectScene` and `MeleeScene`
- `AIDifficulty` lives in `StarfallCore` (moved from `StarfallAI` to avoid dependency cycle)
- AI seed is random per match (`UInt64.random`), not user-configurable
- `isUnderFire` checks for opponent projectiles (`ownerShipID != targetID`), not own projectiles
- Audio engine uses `AVAudioMixerNode` sub-mixers (not `AVAudioUnitGain`) for volume control on macOS
- `MeleeRenderer.render()` accepts optional `matchMode` string; scene stores it on first non-nil call
- HUD layout: special name → mode label → name → crew bar + # → primary cooldown → energy bar + # → special cooldown
- Campaign: 3 actions/turn per side. Starbases generate 1 resource/turn, mines generate 1/turn after 2-turn build. Build actions take 2 turns. Extra turn bonus when moving from a colonized friendly system.
- Campaign victory: destroy enemy starbase or eliminate all enemy fleets.
- Campaign combat: `besiege` action hands off to a melee match via `GameController`, result resolves back into `CampaignSimulation`
- `CampaignSimulation` owns turn logic, resource income, fleet management, build processing, AI turn, combat resolution, and victory checks
- `CampaignMapGenerator` produces deterministic maps: grid-based layout with jitter, life/mineral/dead biased toward respective sides, diagonal connections
- Story events fire by turn number: opening (1), Kesh-Varr (5), first loss (3-6), barrier world (8), mid-crisis (12), glory run (18), final push (20), victory/defeat (game over)
- `BriefingScene` handles all story text: opening, mid-campaign, and epilogue. `isEpilogue=true` routes to main menu on close.
- CampaignScene tooltips: system hover shows name/type/owner/badges, fleet hover shows faction/count/ships
- `CampaignScene.mouseMoved(with:)` handles tooltip display; `tooltipLabel` alpha=0 when not hovering
- Replay system: input-recording approach. `MeleeReplayFrame` stores `(p1Input, p2Input)` per frame. `MeleeReplayPlayer` drives fresh `MeleeSimulation`. `generateDemoReplay()` creates deterministic demo (seed=42).
- Campaign AI: `AIStrategicSituation` evaluates fleet power, ship counts by role (heavy >= 15 cost, scout <= 10), and resources. `AITurnPhase` (early/mid/late) gates tactics. Feints trigger mid-game with 30% chance on fleets > 1 ship. Supply disruption triggers when AI is 3+ resources behind. AI avoids moving from systems with pending economy builds.

### Phase 9 -- Arena Polish (Asteroids + Camera Zoom)
- [x] `Asteroid` struct in `MeleeTypes.swift`: position, velocity, radius, mass
- [x] Asteroid physics in `MeleePhysics.swift`: `applyAsteroidGravity()` (weaker planet pull), `applyShipAsteroidCollision()` (bounce + damage), `projectileHitsAsteroid()`
- [x] `MeleeSimulation.asteroids` — generated on init (8 asteroids, deterministic seed), updated each frame with gravity + wrap
- [x] Ship-asteroid collision: bounce ship, damage crew, transfer momentum to asteroid
- [x] Projectile-asteroid collision: projectile destroyed on impact
- [x] Camera zoom in `MeleeScene.swift`: `cameraNode` holds planet/ships/projectiles/asteroids. Zoom factor ranges 1.0x (ships far) to 1.4x (ships close). Camera centers on ship midpoint.
- [x] `worldToScreen()` returns offset from arena center; `cameraNode.position` handles screen offset
- [x] Asteroid rendering: gray circles with stroke, rendered on `asteroidLayer`
- [x] 6 new asteroid tests: generation, movement, wrap, ship collision damage, projectile destruction, determinism
- [x] 101 total tests pass, `swift build` clean

### Phase 10 -- Finalization Sweep
- [x] Fixed double `endTurn()` call: `CampaignScene.handleEndTurn()` called `sim.endTurn()` directly AND `GameController.campaignEndTurn()` called it again
- [x] Fixed `endTurn()` early return on combat: now processes build actions, income, and victory checks even when combat is triggered
- [x] Fixed campaign turn cycle not resuming after combat: added `campaignTurnStep` state machine with `resumeCampaignTurn()` and `finishCampaignTurn()`
- [x] Made `checkVictory()` public so `GameController` can call it after combat resolution
- [x] Fixed invalid starting fleet crew values (Runner had 22 crew but max 18)
- [x] Fixed kamikaze damage to use `velocity.length` instead of stale `speed` scalar
- [x] Fixed camera zoom to account for arena wrap-around (`wrapDelta` for separation and midpoint)
- [x] Fixed force-unwrap crash in `CampaignScene` tooltip system ID parsing
- [x] Fixed `GameController.aiDifficulty!` force-unwrap → proper `if let` binding
- [x] Added complete macOS menu bar: About, Services, Preferences (Cmd+,), Hide (Cmd+H), Hide Others (Cmd+Shift+H), Show All, Quit (Cmd+Q), Window menu with Minimize (Cmd+M), Zoom, and Bring All to Front
- [x] Fixed indentation bug in `showCampaign()`
- [x] Made `wrapDelta` public for use by `MeleeScene` camera zoom
- [x] Removed dead code: unused `GameScene` enum, `autoAdvanceTimer`/`autoAdvanceInterval`, `prevShipPosition` fields, dead comment in `applyFriction`, `titledCopy()` helper
- [x] 103 total tests pass, `swift build` clean with zero warnings
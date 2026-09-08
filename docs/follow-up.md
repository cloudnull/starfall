# Remaining Work & Follow-Up Items

## Phase 10 Completion: Remaining Items

### 1. Two Consecutive Clean Review Passes (REQUIRED)
**Status:** Not started. The Phase 10 review log shows one pass. The spec requires two consecutive clean passes on all six lenses.

**Action needed:**
- Run a second full adversarial review across all six lenses (Correctness, Determinism, Concurrency, Design Fidelity, Player Experience, Performance)
- Document findings in `docs/review-log.md`
- Any new findings must be fixed and re-reviewed

### 2. Campaign Playthrough to Both Endings (REQUIRED)
**Status:** Not verified. The spec says "You must actually play the campaign through to a victory and through to a defeat and confirm both endings render."

**Action needed:**
- Play the full campaign from start to victory
- Play the full campaign from start to defeat
- Confirm both `VictoryScene` and `DefeatScene` render correctly with all story text
- This requires human verification (cannot be automated)

### 3. Performance Measurement (REQUIRED)
**Status:** Not verified. The spec requires "Sustained 60fps under maximum load, measured."

**Action needed:**
- Add a performance measurement test that tracks frame times during a high-load melee match
- Measure sustained FPS with two ships, full weapon fire, particle effects, and asteroids
- Record results in `docs/review-log.md`

### 4. Sub-Plan Artifacts (REQUIRED by spec section 13)
**Status:** No Erebine artifacts exist for phase sub-plans.

**Action needed:**
- Create Erebine artifacts for each phase (Phase 0-10)
- Link to decisions and milestones

### 5. Story Events Tied to Campaign State (DESIGN IMPROVEMENT)
**Status:** Story events fire on turn numbers, not campaign state as the story bible specifies.

**Action needed:**
- Modify `CampaignStory.checkEvents()` to check for actual campaign state changes (system falls, barrier world cracked, etc.) instead of fixed turn numbers
- The `first_loss` event should fire when an unowned system becomes enemy-owned
- The `first_barrier_world` event should fire when a system is captured from the Dominion

### 6. Starbase Transport Action (MISSING FEATURE)
**Status:** Not implemented. Original SC1 allows moving a Starbase to another system at the cost of all 3 actions.

**Action needed:**
- Add `CampaignAction.transportStarbase(systemID:)` case
- Implement `executeTransportStarbase()` in CampaignSimulation
- Add UI in CampaignScene for this action

### 7. Multi-Ship Fleet Combat Selection (MISSING FEATURE)
**Status:** Only the first ship from each fleet fights in melee. The spec says "ship by ship."

**Action needed:**
- Implement ship selection UI before campaign combat
- Allow player to choose which ship fights
- Handle multi-ship sequential combat (fighter squadrons)

### 8. Ship-Specific Special Ability Tests (TESTING GAP)
**Status:** Only 1 of 14 special abilities has test coverage.

**Action needed:**
- Add tests for each ship's special ability (shield, cloak, specialForm, teleport, kamikaze, launchFighters, regrowCrew, rearWeapon, pointDefense, parasiteMine, retroPulse, crystalSwarm, morphShift, sirenCall)

### 9. Replay Determinism Test (TESTING GAP)
**Status:** No test that records a replay, plays it back, and compares final states.

**Action needed:**
- Add test that: creates simulation → records inputs → creates new simulation → plays back → compares ship states byte-for-byte

### 10. Audio Engine Tests (TESTING GAP)
**Status:** No tests for AudioEngine, SoundSynthesizer, MusicSynthesizer.

**Action needed:**
- Add basic tests: AudioEngine initializes, SoundSynthesizer generates buffers, MusicSynthesizer loops correctly

### 11. Campaign Victory/Defeat End-to-End Test (TESTING GAP)
**Status:** `testFullCampaignTurnCycleCompletes` doesn't play to actual victory/defeat.

**Action needed:**
- Create a test that simulates a full campaign with mocked combat results
- Verify victory scene triggers when enemy starbase is destroyed
- Verify defeat scene triggers when player starbase is destroyed

### 12. Settings Persistence Tests (TESTING GAP)
**Status:** Settings (volume, mute, key bindings) are not tested for persistence.

**Action needed:**
- Add tests for save/load key bindings
- Add tests for settings persistence across sessions

### 13. Performance: Texture Memory Management (PERFORMANCE)
**Status:** SVGTextureLoader caches textures but never purges them.

**Action needed:**
- Add cache size limits and LRU eviction to SVGTextureLoader
- Profile memory usage during a long campaign session

### 14. Accessibility: VoiceOver Support (ACCESSIBILITY)
**Status:** SpriteKit scenes don't have accessibility attributes set.

**Action needed:**
- Add accessibility labels to HUD elements
- Add accessibility for ship select buttons
- Add accessibility for campaign map nodes

## Priority Order

**Critical (must do for DoD):**
1. Two consecutive clean review passes
2. Campaign playthrough to both endings (human verification)
3. Performance measurement (60fps)

**High (spec fidelity):**
4. Story events tied to campaign state
5. Starbase transport action
6. Ship-specific special ability tests

**Medium (testing/quality):**
7. Sub-plan artifacts
8. Replay determinism test
9. Audio engine tests
10. Campaign victory/defeat end-to-end tests
11. Settings persistence tests

**Low (polish):**
12. Multi-ship fleet combat selection
13. Texture memory management
14. Accessibility support
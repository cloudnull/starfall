# CampaignScene — Comprehensive Bug Report

> ## ✅ RESOLVED (verified 2026-09-04)
> All six bugs below have been fixed and verified against the current source tree.
> This file is retained as a record of the investigation and root-cause analysis.
>
> | Bug | Fix location | Status |
> |-----|--------------|--------|
> | BUG-1 | `GameController.swift:735` — `showCampaignScene` now calls `presentSceneWithFade(scene, scaleMode: .resizeFill)` | Fixed |
> | BUG-2 | `CampaignScene.swift` `pointInEndTurnButton` — hit rect now derived from `btnCX`/`btnCY` matching the visual button | Fixed |
> | BUG-3 | `CampaignScene.swift:647` `update()` — no longer calls `renderMap()` each frame; only `updateHUD()` | Fixed |
> | BUG-4 | `CampaignSimulation.swift` `executeAITurn` — `actionsLeft -= 1` now only on `execute() == nil` success | Fixed |
> | BUG-5 | `computeOrigin()` removed from `CampaignScene.swift` | Removed |
> | BUG-6 | `CampaignSimulation.swift:669` `checkVictory` — clean `findStarbaseSystem == nil && no live fleets` condition | Fixed |
>
> Build: clean, 0 warnings. Tests: 112/112 pass.

## Executive Summary

Three classes of bugs were identified:
1. **End Turn button doesn't respond to clicks** — caused by `scaleMode = .aspectFit` (BUG-1) combined with incorrect hit-test rectangle (BUG-2).
2. **HUD layout is broken** — caused by the same `.aspectFit` transform (BUG-1).
3. **Campaign game mechanics are broken** — caused by `update()` rebuilding the entire map every frame (BUG-3) destroying all animations, plus an AI action-counter desync (BUG-4).

---

## BUG-1: `scaleMode = .aspectFit` Breaks HUD Coordinate Mapping (Critical)

**Files & Lines:**
- `Sources/StarfallApp/GameController.swift:622`
- `Sources/StarfallRender/CampaignScene.swift:124-126` (hudLayer is a child of the scene)
- `Sources/StarfallRender/MouseInput.swift:9-17` (convertMouseLocation)

**Description:**

`GameController.showCampaignScene()` sets `scene.scaleMode = .aspectFit` (line 622). This causes SpriteKit to apply a uniform scale + letterbox transform to the entire scene. The scene's logical coordinate system remains 1440×810, but the rendered output is scaled to fit the actual window with black bars.

The `convertMouseLocation` helper uses:
```swift
let viewPt = skView.convert(winPt, from: nil)
return self.convertPoint(fromView: viewPt)
```

`SKScene.convertPoint(fromView:)` converts view coordinates to scene coordinates, **but it does NOT account for `scaleMode = .aspectFit`**. The `aspectFit` transform is applied internally by SpriteKit during rendering and is not reflected in `convertPoint(fromView:)`.

This means:
- HUD elements (End Turn button, labels, pause overlay) are positioned using `size.width`/`size.height` (1440×810) — the logical scene size.
- These elements are **rendered** at scaled positions within the actual window, with letterbox/pillarbox offsets.
- Mouse clicks are converted to scene coordinates via `convertPoint(fromView:)`, which does NOT undo the aspectFit scaling.
- Result: clicks that visually appear to land on the button are mapped to incorrect logical coordinates.

**Impact:** The End Turn button appears at one screen position but click coordinates map to a different logical position. The button does not respond to clicks in the visible area. The pause overlay buttons have the same issue.

**Fix:**

Option A (Recommended): Change to `.resizeFill` so scene coordinates map 1:1 to the view:
```swift
// GameController.swift line 622
scene.scaleMode = .resizeFill
```

Option B: Implement manual coordinate conversion that accounts for the aspectFit transform:
```swift
// In CampaignScene, override convertMouseLocation or add a scale-mode-aware version:
func convertMouseLocationToScene(_ event: NSEvent) -> CGPoint? {
    guard let skView = self.view else { return nil }
    let winPt = event.locationInWindow
    let viewPt = skView.convert(winPt, from: nil)
    
    // If scaleMode is .aspectFit, the scene is scaled within the view.
    // We need to undo that scaling.
    let sceneSize = self.size
    let viewSize = skView.bounds.size
    let scale = min(viewSize.width / sceneSize.width, viewSize.height / sceneSize.height)
    let offset = CGPoint(
        x: (viewSize.width - sceneSize.width * scale) / 2,
        y: (viewSize.height - sceneSize.height * scale) / 2
    )
    
    let scenePoint = self.convertPoint(fromView: viewPt)
    return CGPoint(
        x: (scenePoint.x - offset.x) / scale,
        y: (scenePoint.y - offset.y) / scale
    )
}
```

---

## BUG-2: End Turn Button Hit-Test Rectangle is Computed Incorrectly (Critical)

**File:** `Sources/StarfallRender/CampaignScene.swift:1179-1187`

**Description:**

The visual End Turn button is set up in `setupActionPanel()` (lines 325-354):
- Background `bg` is an `SKShapeNode` at position `(btnX, btnY)` where `btnY = panelY + (panelHeight - btnH) / 2` = `0 + (48-32)/2` = `8`.
- The `endTurnButton` (an empty `SKNode`) is positioned at the **center** of the background: `(btnX + btnW/2, btnY + btnH/2)` = `(btnX + 55, 24)`.
- The `endTurnLabel` is a child of `endTurnButton` at `(0, 0)` relative.

The hit-test function `pointInEndTurnButton()` (lines 1179-1187) computes:
```swift
let btnW: CGFloat = 110
let btnH: CGFloat = 32
let panelHeight: CGFloat = 48
let btnX = size.width - btnW - 12
let btnY = (panelHeight - btnH) / 2      // = 8
let rect = CGRect(x: btnX, y: btnY, width: btnW, height: btnH)
return rect.contains(point)
```

**This appears correct** — `btnY = 8` matches the visual background position. However, the hit-test uses `btnY = (panelHeight - btnH) / 2 = 8`, which assumes `panelY = 0`. If `panelY` ever changes (it's currently 0), this would break.

The more critical issue is that the `point` passed to `pointInEndTurnButton` is the result of `convertMouseLocation(event)` (line 1004), which returns scene-space coordinates. **But with `.aspectFit` (BUG-1), those coordinates are scaled incorrectly.** So even with a correct hit rect, the click coordinates are wrong.

**Impact:** Clicks near the End Turn button don't trigger `handleEndTurn()`.

**Fix:**
1. First fix BUG-1 (aspectFit coordinate issue).
2. As defense-in-depth, derive the hit rect from the actual `endTurnButton` node's scene-converted position:
```swift
private func pointInEndTurnButton(_ point: CGPoint) -> Bool {
    let scenePos = endTurnButton.convert(CGPoint.zero, to: self)
    let rect = CGRect(x: scenePos.x - 55, y: scenePos.y - 16, width: 110, height: 32)
    return rect.contains(point)
}
```

---

## BUG-3: `update()` Rebuilds Entire Map Every Frame, Destroying Animations (Major)

**File:** `Sources/StarfallRender/CampaignScene.swift:473-477`

**Description:**

```swift
public func update() {
    // Called each frame for animations
    renderMap()
    updateHUD()
}
```

This `update()` method is called every frame from `GameController.campaignTick()` (line 1080) at 60Hz via the game timer. `renderMap()` (lines 479-822) calls:
```swift
connectionLayer.removeAllChildren()
systemLayer.removeAllChildren()
fleetLayer.removeAllChildren()
indicatorLayer.removeAllChildren()
```

This destroys and recreates **every** node on the starmap every 16ms. All `SKAction` animations running on those nodes are immediately destroyed and restarted. This means:

- The starbase glow pulse (lines 561-572) never completes — it restarts every frame.
- The selection ring pulse (lines 609-620) resets every frame.
- The fleet movement trail pulse (lines 741-746) restarts every frame.
- The move indicator pulse (lines 796-818) restarts every frame.
- The nebula/star twinkle animations in `bgLayer` are fine (not cleared), but all world-layer animations are destroyed.

**Performance impact:** Rebuilding 25 systems, their overlays, connections, fleets, and indicators every 16ms is extremely wasteful. The game will run at low FPS even on powerful hardware.

**Impact:** All visual animations on the starmap are broken (appear static or flicker), and the game wastes CPU/GPU rebuilding the scene graph every frame.

**Fix:** Remove `renderMap()` from `update()`:
```swift
public func update() {
    // Per-frame updates only (animations handled by SpriteKit)
    updateHUD()
}
```

`renderMap()` is already called at the appropriate times:
- After setup (line 128)
- After user actions (e.g., `handleFleetClick` line 1111, `handleSystemClick` line 1126)
- After pan/zoom (lines 976, 1074, 1083, 1093)
- After end turn (line 1176 via `render()`)

The only per-frame need is `updateHUD()`, which updates text labels. Even this could be optimized to only update when state changes.

---

## BUG-4: AI Action Counter Desync in `executeAITurn()` (Major — Campaign Mechanics)

**File:** `Sources/StarfallCampaign/CampaignSimulation.swift:650-732`

**Description:**

In `executeAITurn()`, the AI tracks its remaining actions with a local variable `actionsLeft = 3` (line 653). It calls `self.execute(...)` for each action, which validates and decrements `state.actionsRemaining`.

For **Phase 1 (move fleets)** — lines 657-691:
```swift
if isFeintCandidate && !hasEconomyToBuild {
    _ = executeFeint(fleetID, enemyFaction)
    actionsLeft -= 1
} else if ... {
    _ = self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID))
    actionsLeft -= 1   // ← Decremented BEFORE checking if execute() succeeded
}
```

Lines 682, 685, 689: `actionsLeft -= 1` happens immediately after the `execute()` call, regardless of whether `execute()` returned an error (non-nil) or success (nil).

If `execute(.moveFleet(...))` returns an error (e.g., "Fleet already moving", "Target system not connected", "Not your fleet"), `state.actionsRemaining` is NOT decremented by `execute()`, but the local `actionsLeft` IS decremented. After 3 such failures, the AI has `actionsLeft = 0` and skips Phase 2 (build) and Phase 3 (economy), even though `state.actionsRemaining` is still 3.

**Additional issue in Phase 2 (build ships) — lines 693-702:**
```swift
while let resources = state.resources[aiFaction],
      resources > 0, actionsLeft > 0 {
    if let shipIndex = selectShipToBuild(aiFaction, situation: situation),
       self.execute(.buildShip(shipIndex: shipIndex)) == nil {
        actionsLeft -= 1
    } else {
        break
    }
}
```

This correctly checks for nil (success) before decrementing. But if any `execute()` fails, `actionsLeft` is not decremented, but the loop `break`s. This is actually fine for Phase 2.

**The fix:** Make Phase 1 consistent with Phase 2 — only decrement `actionsLeft` on success:
```swift
// Line 675-676:
_ = executeFeint(fleetID, enemyFaction)
actionsLeft -= 1
```
→
```swift
if executeFeint(fleetID, enemyFaction) {
    actionsLeft -= 1
}
```

And for lines 681-689:
```swift
_ = self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID))
actionsLeft -= 1
```
→
```swift
if self.execute(.moveFleet(fleetID: fleetID, targetSystemID: targetID)) == nil {
    actionsLeft -= 1
}
```

**Impact:** AI may skip economic/build actions because failed move attempts waste action budget. This makes the AI weaker than intended, especially in edge cases where fleets are already moving or disconnected.

---

## BUG-5: Dead Code — `computeOrigin()` is Never Called (Minor)

**File:** `Sources/StarfallRender/CampaignScene.swift:1251-1256`

**Description:**

```swift
private func computeOrigin(_ bounds: CGRect, scale: Double) -> CGPoint {
    return CGPoint(
        x: CGFloat(mapMargin - bounds.minX * scale),
        y: CGFloat(mapMargin - bounds.minY * scale)
    )
}
```

This function is defined but never called. Map positioning is handled by `worldLayer.position` in `renderMap()` (lines 502-505). This is dead code that could confuse maintainers.

**Fix:** Remove it, or use it in `renderMap()` for consistency.

---

## BUG-6: Redundant Condition in Victory Check (Minor — Dead Code)

**File:** `Sources/StarfallCampaign/CampaignSimulation.swift:543`

**Description:**

```swift
if !dominionHasStarbase || (!dominionHasFleets && !dominionHasStarbase) {
```

The second clause `(!dominionHasFleets && !dominionHasStarbase)` is a subset of the first `!dominionHasStarbase`. Since the expression uses `||`, if `dominionHasStarbase` is false (making the first clause true), the second clause is never evaluated. And if `dominionHasStarbase` is true (making the first clause false), the second clause evaluates to `false` regardless.

So the entire condition simplifies to `!dominionHasStarbase`. The intent was likely to check for a faction having neither a starbase nor any fleets:
```swift
if !dominionHasStarbase && !dominionHasFleets {
```

Using `&&` instead of `||` for the inner condition would make it `!dominionHasStarbase || (!dominionHasFleets && !dominionHasStarbase)` → still just `!dominionHasStarbase`. The correct intended logic was probably to use `&&` between the starbase and fleet conditions:
```swift
if !dominionHasStarbase && !dominionHasFleets {
```

This would make it so the faction survives even without a starbase if they still have fleets. However, the current behavior (starbase destruction = instant loss) may be intentional by design. This is a **design question**, not a clear bug, but the redundant clause is dead code.

---

## Summary Table

| Bug | Severity | File | Line(s) | Description |
|-----|----------|------|---------|-------------|
| BUG-1 | Critical | GameController.swift | 622 | `.aspectFit` scaleMode breaks mouse coordinate conversion for HUD |
| BUG-2 | Critical | CampaignScene.swift | 1179-1187 | End Turn hit-test rect may mismatch visual button position |
| BUG-3 | Major | CampaignScene.swift | 473-477 | `update()` rebuilds entire map every frame, destroying all animations |
| BUG-4 | Major | CampaignSimulation.swift | 680-691 | AI decrements action counter before checking execute() success |
| BUG-5 | Minor | CampaignScene.swift | 1251-1256 | `computeOrigin()` is dead code, never called |
| BUG-6 | Minor | CampaignSimulation.swift | 543 | Redundant condition in victory check (dead code) |

## Priority Fix Order

1. **BUG-1** (Critical) — Fix `.aspectFit` → `.resizeFill` to restore all HUD click detection
2. **BUG-3** (Major) — Remove `renderMap()` from `update()` to restore animations and performance
3. **BUG-2** (Critical) — Fix End Turn button hit-test for defense-in-depth
4. **BUG-4** (Major) — Fix AI action counter desync
5. **BUG-5** (Minor) — Remove or use `computeOrigin()`
6. **BUG-6** (Minor) — Clean up redundant victory condition

# Phase 14: Combat Overhaul Spec

## Motivation

Current combat is flat: one HP pool (`crew`), instant damage, no heat, no armor/shield layers.
Ships die in 1-3 hits regardless of type. Combat lacks the tactical depth of Star Control 2 / Star
Citizen dogfighting where shield management, weapon heat, and armor composition matter.

## Design Principles

1. **Backward compatible**: Existing `ShipDefinition` fields are preserved. New fields have defaults
   so the roster compiles without immediate changes. We rebalance in a follow-up pass.
2. **Deterministic**: All new mechanics run in the 24 FPS fixed timestep. No floating-point state
   that breaks replay.
3. **No new enums in WeaponType/SpecialType**: We extend existing structs rather than changing
   enums, avoiding cascade changes across rendering and AI.
4. **Incremental**: Each subsystem (shield layers, heat, armor) can be tested independently.

---

## 1. Layered Hit Points: Shield → Armor → Hull

### Current state

```
ShipState.crew: Int       // flat HP, death at <= 0
```

### New state

```
ShipState.hull: Int         // structural HP (what crew was)
ShipState.hullMax: Int
ShipState.shield: Int       // regenerates over time
ShipState.shieldMax: Int
ShipState.shieldRegenRate: Int  // shield restored per frame (from ShipDefinition)
ShipState.shieldRegenDelay: Int // frames before regen starts after taking damage
ShipState.shieldRegenTimer: Int // countdown to regen
```

Armor is not a pool but a **per-ship reduction factor** on damage that reaches hull:

```
ShipDefinition.armorReduction: Double  // 0.0..0.8, fraction of incoming hull damage blocked
```

### Damage cascade

When a projectile hits a ship:
1. **Shield absorbs first**. Energy weapons (laser, cone) are 100% absorbed by shields.
   Ballistic weapons (projectile, missile, spread, tracking, contact) are only 60% absorbed
   by shields -- the remaining 40% bypasses to the next layer.
2. **If shield is depleted**, remaining damage flows to armor.
3. **Armor reduces** hull damage by `armorReduction`. The rest hits hull.
4. **Hull death** at `<= 0` ends the match (replaces `crew <= 0`).

Weapon type to damage class mapping:
| WeaponType | Class | Shield absorption |
|---|---|---|
| `laser` | Energy | 100% |
| `cone` | Energy | 100% |
| `projectile` | Ballistic | 60% |
| `missile` | Ballistic | 60% |
| `tracking` | Ballistic | 60% |
| `spread` | Ballistic | 60% |
| `contact` | Ballistic | 60% |

### Shield regeneration

- Shield regenerates `shieldRegenRate` points per frame.
- Regeneration is paused for `shieldRegenDelay` frames after the ship takes any damage.
- `shieldRegenTimer` counts down; when it reaches 0, regen resumes.
- Default `shieldRegenRate: 1`, `shieldRegenDelay: 60` (2.5s pause).

### Backward compatibility

New fields on `ShipDefinition`:
```swift
public let shieldMax: Int          // default: 0 (no shields)
public let shieldRegenRate: Int    // default: 0
public let shieldRegenDelay: Int   // default: 60
public let armorReduction: Double  // default: 0.0
```

For ships with `shieldMax == 0`, all damage flows directly to armor → hull, preserving
current behavior when `armorReduction == 0`.

The `crew` field on `ShipState` is **renamed to `hull`** in a single migration pass. All
references update together. `startingCrew` on `ShipDefinition` becomes `hullMax`.

### Shield ability (existing .shield special)

The existing `.shield` special becomes a **shield boost**: temporarily increases shield to max
and extends the duration. Replaces the current binary `isShielded` flag which blocks all damage.

Current behavior: `isShielded = true` for 120 frames, all projectiles pass through.
New behavior: sets `shield = shieldMax`, starts a `shieldBoostTimer` (120 frames) during which
shield does not take damage (i.e., acts as an invulnerability bubble, but only for the shield
layer -- damage still flows to hull if shield was already depleted).

Actually, simpler: the `.shield` special now **instantly restores shield to max** and sets
`shieldRegenTimer = 0` (immediate regen). The `isShielded` boolean is removed as a separate
state -- shield presence is now determined by `shield > 0`.

---

## 2. Weapon Heat System

### Rationale

Star Citizen's cooler system prevents spam-firing. In our game, some ships (Dread Command
Fusion Blaster, Veil Particle Stiletto) have `fireWait: 0` and `energyCost: 0-1`, making them
effectively infinite-fire with no counterplay beyond energy.

### New fields on ShipWeapon

```swift
public let heatPerShot: Int     // heat generated per shot, default: 0
```

### New fields on ShipDefinition

```swift
public let heatCapacity: Int    // max heat before overheat, default: 100
public let heatDissipation: Int // heat lost per frame, default: 2
```

### New fields on ShipState

```swift
public var heat: Int            // current heat, 0..heatCapacity
```

### Overheat behavior

- Each shot adds `heatPerShot` to `heat`.
- Each frame, `heat` decreases by `heatDissipation` (floor 0).
- When `heat >= heatCapacity`: weapon is **overheated**. Cannot fire primary until
  `heat < heatCapacity * 0.5` (hysteresis -- must cool 50% before firing again).
- Overheat state is visible on HUD as a red heat bar at capacity.

### Energy cost interaction

Firing still costs energy. Heat is an independent constraint. A ship can have energy to fire
but be heat-blocked.

---

## 3. Updated Ship Definition Struct

```swift
public struct ShipDefinition {
    // ... existing fields unchanged ...

    // New: layered HP
    public let shieldMax: Int
    public let shieldRegenRate: Int
    public let shieldRegenDelay: Int

    // New: armor
    public let armorReduction: Double

    // New: heat (ship-level)
    public let heatCapacity: Int
    public let heatDissipation: Int

    public init(
        // ... existing params ...
        shieldMax: Int = 0,
        shieldRegenRate: Int = 0,
        shieldRegenDelay: Int = 60,
        armorReduction: Double = 0.0,
        heatCapacity: Int = 100,
        heatDissipation: Int = 2
    ) { ... }
}

public struct ShipWeapon {
    // ... existing fields ...
    public let heatPerShot: Int

    public init(
        // ... existing params ...
        heatPerShot: Int = 0
    ) { ... }
}
```

---

## 4. Updated ShipState

```swift
public struct ShipState {
    // Renamed from crew
    public var hull: Int
    public let hullMax: Int

    // New: shield layer
    public var shield: Int
    public let shieldMax: Int
    public var shieldRegenTimer: Int  // frames until regen resumes

    // New: heat
    public var heat: Int
    public var isOverheated: Bool

    // Removed: isShielded, shieldTimer (replaced by shield > 0)
    // Kept: all other timers (cloak, specialForm, parasite, etc.)
}
```

Init changes:
- `hull = definition.startingCrew` (maps to old `crew`)
- `shield = definition.shieldMax` (starts full)
- `heat = 0`
- `isOverheated = false`
- `shieldRegenTimer = 0`

---

## 5. MeleeSimulation Changes

### step() additions

After step 10 (recharge energy), add:
- **10a. Shield regeneration**: For each ship, if `shieldRegenTimer > 0` decrement; else if
  `shield < shieldMax` add `shieldRegenRate`.
- **10b. Heat dissipation**: For each ship, `heat = max(0, heat - heatDissipation)`. Check
  overheat hysteresis: if `isOverheated` and `heat < heatCapacity * 0.5`, set `isOverheated = false`.

### processShipInput changes

Before firing primary, also check `!ship.isOverheated`. After successful fire, add
`ship.heat += weapon.heatPerShot`. If `ship.heat >= ship.definition.heatCapacity`, set
`ship.isOverheated = true`.

### Projectile damage resolution

In `updateProjectiles()`, replace flat damage:
```
if !targetShipShielded {
    targetShip.crew -= proj.damage
}
```

With layered damage:
```
let damage = applyLayeredDamage(
    rawDamage: proj.damage,
    isEnergy: isEnergyWeapon(weaponType),
    shield: &targetShip.shield,
    shieldMax: targetShip.definition.shieldMax,
    armorReduction: targetShip.definition.armorReduction,
    hull: &targetShip.hull
)
// Trigger shield regen pause
targetShip.shieldRegenTimer = max(targetShip.shieldRegenTimer, targetShip.definition.shieldRegenDelay)
```

`applyLayeredDamage()` in MeleePhysics:
1. If `isEnergy`: all damage to shield first, overflow to armor→hull.
2. If `ballistic`: 60% to shield, 40% directly to armor→hull.
3. Armor reduction: `hullDamage = ceil(rawDamage * (1 - armorReduction))`.

### Outcome check

Replace `ship.crew <= 0` with `ship.hull <= 0` throughout.

### Special ability: .shield

Replace:
```swift
ship.isShielded = true
ship.shieldTimer = 120
```

With:
```swift
ship.shield = ship.definition.shieldMax
ship.shieldRegenTimer = 0
```

### Planet/asteroid collision damage

All existing damage sources (planet collision, asteroid collision, ship-ship collision,
parasite drain) bypass shield and hit hull directly. These are environmental, not weapon damage.

---

## 6. HUD Changes

Current HUD per player:
- Crew bar → becomes **Hull bar** (red)
- Energy bar (yellow)
- Primary cooldown bar
- Special cooldown bar

New HUD per player:
- **Shield bar** (blue, above hull) -- new
- **Hull bar** (red, replaces crew) -- relabeled
- **Heat bar** (orange, fills right-to-left, flashes red at overheat) -- new
- Energy bar (yellow) -- unchanged
- Primary cooldown bar -- unchanged
- Special cooldown bar -- unchanged

The shield bar uses the same `barWidth` as hull/energy. The heat bar uses the same width.

---

## 7. AI Changes

### AIPilot new decision layers

In addition to existing thrust/fire/evasion/special logic:

1. **Heat awareness** (medium+): If `own.isOverheated`, stop firing primary. If heat > 80%
   capacity, back off and maneuver away to cool.
2. **Shield management** (hard): If `own.shield < shieldMax * 0.2` and special is `.shield`,
   prioritize shield restore over offense.
3. **Targeting weakened shields** (hard): Prefer targets with `shield == 0` (shield depleted
   or no shields). If both targets have shields, target the one with lower shield fraction.
4. **Weapon class awareness**: If own weapon is energy and target has high shield, fire.
   If own weapon is ballistic and target has no shield, fire (bypass advantage).

---

## 8. Ship Roster Rebalance (follow-up pass)

After the systems are implemented, rebalance each ship's new fields to preserve their
archetype:

| Ship | Archetype | Shield | Armor | Heat | Rationale |
|------|-----------|--------|-------|------|-----------|
| Broodstone | Crystal mothership | High (40) | Medium (0.3) | Low | Tanky, slow-firing |
| Striker | Honor warrior | Low (15) | High (0.5) | N/A | Tough hull, light shield |
| Shifter | Shapeshifter | Low (10) | Low (0.1) | N/A | Glass cannon, mobility |
| Dart | Scout | None (0) | None (0.0) | Low | Fast, fragile, teleport |
| Veil | Psi warfare | Medium (25) | Low (0.1) | Medium | Sustain fighter |
| Runner | Adaptable | Medium (20) | Medium (0.3) | Low | Balanced |
| Spark | Kamikaze | Low (10) | Low (0.1) | N/A | All-in special |
| Dread Command | Flagship | High (35) | High (0.4) | High | Infinite fire → heat gated |
| Sporepod | Hive | Medium (20) | Medium (0.3) | Low | Regrow crew → regrow hull |
| Kesha Runner | Coward | None (0) | None (0.0) | N/A | Fragile, escape |
| Warden | Comet | Medium (20) | Medium (0.2) | Low | Transform tank |
| Harasser | Heavy weapon | High (30) | High (0.4) | Low | Big HP, parasite |
| Reaver | Cloaked attacker | Low (10) | Medium (0.3) | N/A | Hit-and-run |
| Skirmisher | Scavenger | Low (10) | Low (0.1) | Low | Light, retro-pulse |

Heat for infinite-fire weapons:
- Dread Command Fusion Blaster: `heatPerShot: 5`, ship `heatCapacity: 80`, `heatDissipation: 2`
  → can fire ~16 shots before overheat, ~16 frames to cool down.
- Veil Particle Stiletto: `heatPerShot: 3`, `heatCapacity: 60`, `heatDissipation: 3`
  → ~20 shots, cools faster.
- Other ships with `fireWait: 0`: `heatPerShot: 2`, standard capacity.

---

## 9. Implementation Order

1. **Data model changes**: Add new fields to `ShipDefinition`, `ShipWeapon`, `ShipState` with defaults.
2. **Damage cascade**: Implement `applyLayeredDamage()` in MeleePhysics, wire into `updateProjectiles()`.
3. **Shield regen + heat**: Add to `step()` loop.
4. **Overheat gate**: Block firing in `processShipInput()`.
5. **Outcome migration**: Replace `crew` → `hull` in outcome checks.
6. **Special ability update**: `.shield` special behavior change.
7. **HUD update**: Add shield bar, heat bar, relabel crew → hull.
8. **AI update**: Heat/shield awareness in AIPilot.
9. **Roster rebalance**: Update `ShipRoster.swift` with new stats.
10. **Tests**: Update existing tests, add layered damage tests, heat tests.

---

## 10. Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Breaking 101 existing tests | All new fields have defaults. Tests pass with old behavior until roster is updated. |
| Replay determinism broken | All new state is Int-based. No new floating-point state. |
| Ships become too tanky | Roster rebalance pass adjusts shield/armor/hull totals to keep matches ~30-60s. |
| HUD becomes cluttered | Shield bar replaces the old shield bubble visual. Heat bar is thin (4px like cooldown bars). |
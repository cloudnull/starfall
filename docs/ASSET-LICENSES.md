# Asset Licenses

## First-Party Original Assets

All ship sprites, projectile art, effects, planets, UI chrome, and audio are
original, model-generated assets created for Starfall. No content from the
original Star Control, Star Control II, or any descendant product is used.

### SVG Vector Art (Authoritative Source)

All SVG files live in `Assets/svg/` and are the authoritative art source.
They are loaded at runtime by `SVGTextureLoader.swift` via Core Graphics Image I/O.
Verification: `swift Scripts/rasterize_svg.swift` (checks all 33 files exist).

| Asset | Type | License | Notes |
|-------|------|---------|-------|
| Ship SVG art (14 ships) | Original vector art | First-party, original work | `Assets/svg/ships/*.svg` — one per ship class |
| Projectile SVG art (5 weapons) | Original vector art | First-party, original work | `Assets/svg/projectiles/*.svg` |
| Effect SVG art (4 effects) | Original vector art | First-party, original work | `Assets/svg/effects/*.svg` — explosion, thrust, impact, shield |
| Planet SVG art (4 variants) | Original vector art | First-party, original work | `Assets/svg/planets/*.svg` |
| UI SVG art (6 elements) | Original vector art | First-party, original work | `Assets/svg/ui/*` — starfield, HUD bars |
| SVG manifest | JSON metadata | First-party, original work | `Assets/svg/manifest.json` |
| SVG texture loader | Source code | First-party, original work | `Sources/StarfallRender/SVGTextureLoader.swift` |

### Ship SVG Files
| Ship | File | Species | Faction |
|------|------|---------|---------|
| Broodstone | broodstone.svg | Ossari | Compact |
| Striker | striker.svg | Vaelen | Compact |
| Shifter | shifter.svg | Krr-tk | Compact |
| Dart | dart.svg | Paelin | Compact |
| Veil | veil.svg | Sireth | Compact |
| Runner | runner.svg | Terrani | Compact |
| Spark | spark.svg | Xhofi | Compact |
| Dread Command | dread_command.svg | Vexari | Dominion |
| Sporepod | sporepod.svg | Fungor | Dominion |
| Kesha Runner | kesha_runner.svg | Kesha | Dominion |
| Warden | warden.svg | Synthari | Dominion |
| Harasser | harasser.svg | Vokk | Dominion |
| Reaver | reaver.svg | Gorth | Dominion |
| Skirmisher | skirmisher.svg | Drul | Dominion |

### Procedural Audio
| Asset | Type | License | Notes |
|-------|------|---------|-------|
| Weapon fires | Original synthesized audio | First-party, original work | Generated programmatically |
| Impacts/explosions | Original synthesized audio | First-party, original work | Generated programmatically |
| Thrusters | Original synthesized audio | First-party, original work | Generated programmatically |
| UI sounds | Original synthesized audio | First-party, original work | Generated programmatically |
| Menu theme | Original composed music | First-party, original work | Composed programmatically |
| Combat theme | Original composed music | First-party, original work | Composed programmatically |

### App Icon
| Asset | Type | License | Notes |
|-------|------|---------|-------|
| AppIcon.icns | Original icon art | First-party, original work | `Resources/AppIcon.icns` |

## Third-Party Assets

(None. Any third-party asset added must include source URL, license name,
license text or link, and required attribution.)

## Research Notes on Source Licensing

- Star Control II / The Ur-Quan Masters open-source project distributes its
  _code_ under a permissive license but its _content_ (art, music, voice) under
  a non-commercial license. Verified from the Ur-Quan Masters project page.
  We use zero sourced assets from this project.
- The Star Control trademark is contested between multiple parties. We do not
  use the "Star Control" name in our game title, species names, or marketing.
  Our game is titled "Starfall."
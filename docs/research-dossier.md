# Starfall Research Dossier

## Source Material: Star Control (Accolade, 1990)

This dossier records every game mechanic, ship stat, and narrative element researched from external sources. Each section cites its source URL.

---

## 1. Melee Ship Roster

The original Star Control features 14 ships: 7 for the Alliance of Free Stars, 7 for the Ur-Quan Hierarchy.

**Note on data source:** The numerical stats below come from the SC2 / Ur-Quan Masters engine, which the wiki notes are "slightly different" from SC1. Where SC1-specific values are known, they are noted. The SC2 values serve as the authoritative baseline because they are the only complete, published stat table for the SC1 ships.

Source: <https://wiki.starcontrol.com/index.php/Table_of_ship_properties>

### Alliance of Free Stars

| Ship | Race | Cost (Starbucks) | Max Crew | Max Energy | Energy Regen | Energy Wait (frames) | Weapon Cost | Weapon Wait | Special Cost | Special Wait | Max Thrust | Thrust Inc | Thrust Wait | Turn Wait | Mass |
|------|------|------------------|----------|------------|--------------|----------------------|-------------|-------------|--------------|--------------|------------|------------|-------------|-----------|------|
| Broodhome | Chenjesu | 26 | 36 | 30 | 1 | 4 | 5 | 0 | 30 | 0 | 27 | 3 | 4 | 6 | 10 |
| Terminator | Yehat | 23 | 20 | 10 | 2 | 6 | 1 | 0 | 3 | 2 | 30 | 6 | 2 | 2 | 3 |
| Transformer (X-Form) | Mmrnmhrm | 19 | 20 | 10 | 1 | 6 | 1 | 0 | 10 | 0 | 50 | 10 | 0 | 14 | 3 |
| Skiff | Arilou | 16 | 6 | 20 | 1 | 6 | 2 | 1 | 3 | 2 | 40 | 40 | 0 | 0 | 1 |
| Penetrator | Syreen | 12 | 30 | 10 | 1 | 10 | 2 | 0 | 3 | 7 | 48 | 12 | 1 | 1 | 7 |
| Cruiser | Earthling | 9 | 18 | 18 | 1 | 8 | 9 | 10 | 4 | 9 | 24 | 3 | 4 | 1 | 6 |
| Scout | Shofixti | 5 | 20 | 40 | 1 | 4 | 20 | 5 | 40 | 0 | 27 | 9 | 6 | 6 | 7 |

### Ur-Quan Hierarchy

| Ship | Race | Cost (Starbucks) | Max Crew | Max Energy | Energy Regen | Energy Wait (frames) | Weapon Cost | Weapon Wait | Special Cost | Special Wait | Max Thrust | Thrust Inc | Thrust Wait | Turn Wait | Mass |
|------|------|------------------|----------|------------|--------------|----------------------|-------------|-------------|--------------|--------------|------------|------------|-------------|-----------|------|
| Dreadnought | Ur-Quan | 30 | 10 | 30 | 30 | 150 | 0 | 0 | 1 | 2 | 18 | 6 | 3 | 4 | 1 |
| Podship | Mycon | 23 | 20 | 16 | 1 | 6 | 1 | 8 | 5 | 10 | 36 | 9 | 1 | 1 | 7 |
| Eluder (Discriminator) | Spathi | 18 | 6 | 4 | 1 | 9 | 1 | 3 | 0 | 0 | 35 | 5 | 0 | 1 | 1 |
| Guardian | Androsynth | 15 | 20 | 24 | 1 | 8 | 3 | 0 | 2 | 0 | 24 | 3 | 4 | 6 | 10 |
| Intruder | VUX | 12 | 42 | 42 | 1 | 8 | 1 | 0 | 8 | 7 | 21 | 7 | 4 | 6 | 6 |
| Avenger | Ilwrath | 10 | 22 | 16 | 4 | 0 | 1 | 0 | 3 | 13 | 25 | 5 | 0 | 2 | 7 |
| Drone | Umgah | 7 | 12 | 16 | 1 | 6 | 1 | 0 | 5 | 10 | 30 | 6 | 2 | 2 | 3 |

**Notes:**
- The Ur-Quan Dreadnought has Energy Regen = 30 and Energy Wait = 150 frames. This means it recharges very large amounts but very slowly (150 frames = 6.25s at 24fps).
- The Drone's primary weapon (Antimatter Cone) takes no energy cost (0 in table above is weapon energy cost, but the wiki says "takes no energy, however restarts the battery recharge counter"). Correction: the table shows Weapon Energy Cost = 0 for Dreadnought and Drone. The wiki text says: "The delay timer to regenerate a Umgah Drone's batteries resets every time it uses its primary weapon."
- Pkunk Fury recharges 2 energy per use of its special (Insult). Not in SC1 roster.
- Slylandro Probe recharges energy by absorbing asteroids. Not in SC1 roster.
- Utwig Jugger regenerates energy by absorbing damage with shields. Not in SC1 roster.

---

## 2. Ship Weapons and Special Abilities

Source: <https://wiki.starcontrol.com/index.php/List_of_weapons>
Tactics: <https://www.star-control.com/hosted/scsaga/shipspic.htm>

### Alliance Ships

#### Chenjesu Broodhome
- **Primary:** Photon Crystal Shard - Fires outward until fire button released, then shatters into pieces. 6 damage direct hit, 2 for shattered fragments.
- **Special:** D.O.G.I. (Destructive Organic Growth Inhibitor) - Follows foe and saps battery power. High energy cost (30).

#### Yehat Terminator
- **Primary:** Twin Ion Pulse Cannons - Rapid-fire, 1 damage per shot.
- **Special:** Force Shield - Blocks all damage for a short duration. Low energy cost.

#### Mmrnmhrm X-Form (Transformer)
- **Primary:** Missiles (in Y-Wing form) - Tracking, 1 damage.
- **Primary alt:** Lasers (in X-Wing form) - Continuous laser, 1 damage.
- **Special:** Transform between slow/heavy Y-Wing form and fast/light X-Wing form. Cannot fire while transforming.

#### Arilou Skiff
- **Primary:** Ventral Laser - 1 damage, automatically aims at foe.
- **Special:** Random Teleport - Teleports to a random point on battlefield.

#### Syreen Penetrator
- **Primary:** Particle Beam Stiletto (Electron Dagger) - 2 damage.
- **Special:** Syreen Song - Causes enemy crew to jump ship; defected crew can be picked up by either side.

#### Earthling Cruiser
- **Primary:** MX Nuclear Missile - 4 damage, tracking "fire-and-forget" missile.
- **Special:** SDI Point Defense Laser - 1 damage, auto-targets nearby incoming projectiles.

#### Shofixti Scout
- **Primary:** Mendokusai Energy Dart - 1 damage.
- **Special:** Glory Device - Kamikaze attack, up to 14 damage maximum. Destroys the Scout. Must press 3 times to activate.

### Hierarchy Ships

#### Ur-Quan Dreadnought
- **Primary:** Fusion Blaster - 6 damage.
- **Special:** Launch Fighters - Launches 2 crew in autonomous fighters that attack foe. Each fighter shot does 1 damage. Crew is sacrificed if fighters are destroyed.

#### Mycon Podship
- **Primary:** Homing Plasmoid - 1-10 damage, dissipates over time, hits the shot.
- **Special:** Regrow Crew - Regrows 4 crew members. Costs 5 energy.

#### Spathi Eluder (Discriminator)
- **Primary:** Fast, weak, forward gun - 1 damage.
- **Special:** B.U.T.T. (Booster Ultra-Thrust Technology) - 2 damage, fires from rear, tracking. Allows escape.

#### Androsynth Guardian
- **Primary:** Molecular Acid Bubbles - 2 damage, follows using Chaos(TM) tracking. Poor tracking but can block enemy projectiles.
- **Special:** Blazer Mode - Becomes a high-speed, inertialess comet. Does 3 damage per hit on contact. Cannot be escaped before battery is drained. Devastating on impact, cannot turn.

#### VUX Intruder
- **Primary:** Gigawatt Laser - 1 damage.
- **Special:** Limpet Parasite Cocoon - Slows down foe.

#### Ilwrath Avenger
- **Primary:** Hellfire Spout - 1 damage, very fast-firing. Disengages cloak and turns ship to face opponent.
- **Special:** Cloaking Field - Makes ship invisible and untargetable by tracking weapons.

#### Umgah Drone
- **Primary:** Antimatter Cone - 1 damage, continuous, takes no energy but restarts battery recharge counter.
- **Special:** Retro-propulsion System - Launches Drone backwards and cancels all momentum.

---

## 3. Melee Physics and Arena Rules

Sources:
- <https://www.star-control.com/sc1/> - "The game arena isn't unlimited, as a ship draws close to the edge it wraps around to the opposite edge."
- <https://www.hardcoregaming101.net/star-control/> - "Each playing field also has a planet, with its own center of gravity, which can be harnessed to slingshot your ship around the arena."
- <https://wiki.starcontrol.com/index.php?title=Super-Melee> - Frame rate: 24 FPS. World units = 1/4 pixel at 320x240 full zoom. 16 facings (22.5 degree increments).
- <https://starships.fandom.com/wiki/Star_Control> - "Once they get closer they will get bigger and the players will have less time to react." Camera zooms based on ship separation.
- <https://www.old-games.com/download/5582/star-control-1> - "The planet was both a curse and a blessing. It devastated your ship's crew if you accidentally ran into it, but a carefully plotted course would [allow a slingshot]."

### Physics Model
- **Inertia-based:** Ships accelerate along their facing. No automatic deceleration.
- **Thrust:** Each ship has max thrust, thrust increment, and thrust wait. Thrust is not continuous acceleration; it increments speed in steps.
- **Turning:** Rate-limited per ship. Turn wait determines frames between orientation changes (from 0 = instant to 14 = very slow).
- **Mass:** Affects how thrust and gravity affect the ship. Higher mass = harder to accelerate, harder to turn.
- **Frame rate:** 24 FPS simulation (1/24s per frame).

### Gravity
- A single planet exists in the arena with gravitational pull on both ships.
- The gravity can be used for slingshot maneuvers (the "gravity whip" technique).
- Colliding with the planet causes crew damage.

### Arena Boundary
- **Wrap-around:** Ships that reach the arena edge wrap to the opposite side. This is explicitly stated on the official site.

### Collisions
- **Ship-to-ship:** Ships collide and it hurts (implied by Guardian blazer ram mechanics, and the general design).
- **Ship-to-planet:** Crew damage.
- **Asteroids:** Occasional asteroids fly through the arena and can be destroyed by either player's fire.

### Camera
- Frames both ships, zooms in as they approach, zooms out as they separate.
- Must never lose a ship off-screen without warning.

### Match End
- A ship dies when its crew reaches zero.
- If both ships die simultaneously, it's a tie (in full game context).

---

## 4. Strategic / Campaign Layer

Sources:
- <https://wiki.starcontrol.com/index.php/Star_Control>
- <https://starships.fandom.com/wiki/Star_Control>
- <https://www.hardcoregaming101.net/star-control/>
- <https://en.wikipedia.org/wiki/Star_Control>

### Map
- A rotating 3D star map with stars connected by travel routes.
- Stars have planets that can be: life worlds (colonizable), mineral worlds (minable), or dead worlds (neither, but can be fortified).
- Each side starts at opposite ends of the map with a Starbase.

### Turn Structure
- Each player gets up to **3 actions per turn** (except moving a Starbase, which costs the entire turn).
- Actions include: move ship, build ship, colonize, mine, fortify, recruit crew, besiege planet, scuttle ship, pass.
- Extra turns are earned when moving from a colonized planet on your side.

### Resources
- **Starbucks** (the in-game currency): Generated by mines (1 per turn once built) and Starbases (1 per turn).
- Mines take 2 turns to build before producing.
- Ships cost Starbucks to build at your Starbase.

### Planets
- **Life worlds:** Can be colonized. After 2 turns, provides crew recruitment for damaged ships.
- **Mineral worlds:** Can be mined. After 2 turns, produces 1 Starbucks per turn.
- **Dead worlds:** Cannot be mined or colonized. Can be fortified.
- **Fortifications:** Take 2 turns to build. Enemy ships get stuck at fortified planets (1 in 15 chance to destroy by besieging, unless Ur-Quan Dreadnought which has better odds).

### Fleet Engagements
- When opposing fleets meet, the game drops into Melee, ship by ship.
- Surviving ships retain their crew count (damage persists).
- Crew can be replenished at friendly colonies.

### Special Tactical Powers
- Different scenarios and ships may have special tactical abilities on the strategic layer.
- Ancient artifacts/technologies can boost ship capabilities when discovered by exploring unknown stars.

### Victory Conditions
- **Destroy the enemy Starbase** (primary victory condition).
- **Total destruction** of the enemy fleet is also mentioned as a win path.
- The game had 9 scenarios (15 in Genesis port), each with brief introductions.
- No persistent campaign: each scenario is standalone.

---

## 5. Narrative and Lore

Sources:
- <https://wiki.starcontrol.com/index.php/Ur-Quan_Hierarchy>
- <https://wiki.starcontrol.com/index.php/Alliance_of_Free_Stars>
- <https://wiki.starcontrol.com/index.php?title=Ilwrath>
- <https://www.hardcoregaming101.net/star-control/>
- <https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/StarControl>
- <https://retro-replay.com/the-stars-our-destination-history-of-the-star-control-universe/>

### The Ur-Quan Hierarchy

The Ur-Quan Kzer-Za are massive, caterpillar-like alien overlords pursuing the "Path of Now and Forever" - systematic conquest and subjugation of every sentient species in the galaxy. The Hierarchy consists of:

**Leaders:** Ur-Quan Kzer-Za

**Battle Thralls** (subjugated but retain some autonomy, forced to conquer):
- **Ilwrath** - Arachnoid, red, spider-like. Violent, religiously fanatical, worship twin dark gods Dogar and Kazon. Extremely bloodthirsty. First race enslaved by Ur-Quan.
- **Mycon** - Fungal, plant-like beings. Slow-moving, hive-mind adjacent.
- **Spathi** - Cowardly, religious species. Fast ship, large crew that tends to flee.
- **Thraddash** - Warlike, prone to nuclear conflict (Ur-Quan had to replace their entire culture to prevent self-destruction).
- **Umgah** - Small, fast, bird-like. Battle-cry oriented.
- **VUX** - Scientific, paranoid, anti-technology species. Clumsy but heavily armed.
- **Yehat** - Clan-based warriors. Defected from Alliance to Hierarchy as Battle Thralls.

**Fallow Slaves** (fully subjugated, homeworlds under slave-shield):
- **Humans (Earth)** - Had all structures older than 500 years destroyed by Ur-Quan.
- **Syreen** - Seductive alien beings (banned from recruiting crew normally).
- **Chenjesu** - Crystalline beings, leaders of the Alliance, encased in slave-shield.
- **Mmrnmhrm** - Communicate in sounds, linked with Chenjesu on a single enslaved world.

### The Alliance of Free Stars

Formed circa 2110 as a mutual defense pact. Defeated in 2134.

**Members:**
- **Chenjesu** - Crystalline, ancient, founding members. Led the Alliance.
- **Mmrnmhrm** - Non-verbal communicators, Chenjesu allies from founding.
- **Yehat** - Clan warriors, joined early. (Defected to Hierarchy after defeat.)
- **Shofixti** - Fox-like, foster species of the Yehat. Kamikaze tendencies (Scout's Glory Device). Sacrificed themselves rather than be enslaved.
- **Humans** - Joined in 2116, 4 years after first contact with Chenjesu.
- **Arilou** - Appeared day after Earth joined. Fast, mysterious, disappeared after the war.
- **Syreen** - Joined last (2120), somewhat loosely.

### Central Conflict Arc
1. Alliance forms to resist Ur-Quan expansion (~2110).
2. War ensues. Alliance fights valiantly but is ultimately defeated (2134).
3. Survivors continue resistance from scattered positions.
4. SC2 picks up 20 years later with the "New Alliance."

### Tone
- Mix of epic space opera and quirky humor.
- Species have distinct personalities: comedic (Shofixti, Pkunk), terrifying (Ilwrath, Ur-Quan), mysterious (Chenjesu, Slylandro).
- Despite the war setting, there's warmth and camaraderie among Alliance species.
- The "small fish in a big universe" theme: humans are not the center of the story.

---

## 6. Frame Rate and Simulation Details

Source: <https://wiki.starcontrol.com/index.php?title=Super-Melee>

- **Frame rate:** 24 FPS (each frame = 1/24 second).
- **World units:** 1/4 pixel at full zoom with 320x240 resolution.
- **Facings:** 16 discrete directions (22.5 degree increments).
- Ships have: Max Thrust (world units/frame), Thrust Increment, Thrust Wait (frames between speed increases), Turn Wait (frames between facing changes).

---

## 7. Unverified or Contested

The following details could not be precisely verified and are subject to design decision:

1. **Exact SC1 vs SC2 stat differences:** The wiki states SC2 stats are "slightly different" from SC1, but does not document the SC1-specific values. We will use SC2 values as the authoritative reference since they are the only complete, published table.

2. **Exact arena dimensions:** The world unit system is described but the total arena size in world units is not explicitly stated for SC1 (SC2's Super-Melee uses specific dimensions that may differ).

3. **Exact gravity formula:** The gravity well's strength and fall-off curve are not documented numerically. We will derive values that make the slingshot mechanic work as described.

4. **Ship-to-ship collision damage:** The mechanics of ship-to-ship collision damage are not precisely quantified. We will implement a collision that causes crew damage proportional to relative velocity.

5. **Asteroid frequency and behavior:** Asteroids are mentioned as occurring occasionally in melee but their spawn rate, trajectory, and properties are not documented.

6. **Camera zoom algorithm:** The zoom behavior is described qualitatively ("zooms in as ships approach") but no formula is documented.

7. **Exact wrap-around point:** When exactly a ship wraps (at what coordinate threshold) is not specified.

8. **Turn-based action timing:** The "3 actions per turn" is documented, but the exact resolution order and whether the AI can interleave actions is unclear.

9. **Fortified planet siege mechanics:** The "1 in 15 chance" is stated, but whether this is per-turn, per-action, or requires specific conditions is ambiguous. The Dreadnought having "better odds" is stated but not quantified.

10. **Starting fleet compositions for scenarios:** The 9 scenarios each had specific starting positions and fleet compositions, but these are not fully documented. We will design our own scenario layout inspired by the documented structure.
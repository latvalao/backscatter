# BACKSCATTER — Game Design & Technical Spec

> Realistic West-vs-East RTS in a radioactive exclusion zone.
> Engine: **Godot 4.x (latest stable)** · Platform: **PC (Steam)** · Modes: single-player campaign, PvE co-op (1–4), versus with friends (1v1 / 2v2, invite-only).

---

## 0. How to use this document (for Claude Code)

- This is the **source of truth** for design and architecture. When a request conflicts with this doc, ask before deviating.
- Build in the **milestone order in §12**. Each milestone has acceptance criteria — a milestone is done only when all criteria pass.
- **Hard rules** (never break these):
  1. The **simulation is deterministic**: integer / fixed-point math only, no `float` in sim state, no Godot physics in sim, no `randf()` — only the seeded sim RNG.
  2. **Simulation and presentation are separate.** Sim code never touches Nodes, scenes, or rendering. Presentation reads sim state and interpolates.
  3. **All gameplay input is a Command** applied on a sim tick. No direct state mutation from UI.
  4. **All unit/building/weapon stats are data** (`.tres` Resources or JSON under `data/`), never hard-coded.
- Keep systems small and testable. Every sim system gets headless unit tests (GUT or gdUnit4).
- Placeholder art is fine until M8. Use simple meshes/boxes with team colors.

---

## 1. Vision

**Pitch:** A realistic West-vs-East RTS set years after a reactor disaster on a northern border. Two cut-off military remnants fight over abandoned depots, the border corridor and the plant itself — in fallout that doesn't care which side you're on.

**Tone references:** Broken Arrow / WARNO (realism), Men of War (scale, intimacy), Road to Vostok (Nordic border atmosphere), S.T.A.L.K.E.R. / Chernobyl (exclusion zone), classic C&C (readable base-building RTS controls).

**Market position:** Broken Arrow proved demand for realistic modern West-vs-East RTS but was criticized for weak solo content. Backscatter leads with **single-player and co-op**, adds **base building, logistics and radiation**, and supports **versus with friends** (no ranked ladder, no matchmaking).

### Design pillars
1. **Authentic, not simulation.** Real hardware, doctrine and radiation physics — abstracted into readable RTS rules.
2. **Fallout is the third army.** Wind, rain and hot spots reshape the battlefield every match.
3. **Seeing gives you away.** Every emitter (radar, radio, drone link, jammer) creates an electromagnetic signature the enemy can find — the *backscatter* system.
4. **Crews matter.** Units are crewed, accumulate dose, gain veterancy and can be lost for good.
5. **Logistics win wars.** Fuel, ammunition, spare parts and manpower — not abstract minerals.

---

## 2. Setting

- **Place:** fictional Nordic–Eastern border region (Karelia-like): pine and birch forest, bogs, lakes, granite outcrops, border posts, collective-farm ruins, a small closed town, and the **Kaarnavaara Nuclear Power Plant** (fictional) with a half-built sarcophagus.
- **Event:** a reactor accident ~12 years ago created an exclusion zone straddling the border. The states on both sides collapsed or retreated; their militaries fragmented.
- **Why fight here:** pre-war military depots (fuel, ammo, vehicles), the only intact border road/rail corridor, and control of the plant.
- **Nations are fictional** (own names, flags, insignia). Hardware is realistic but uses **generic designations** in-game (e.g. "MBT-72", not trademarked product names).
- **Languages:** Western radio barks in a Nordic-style language + English; Eastern in a Russian-style language. Subtitled.

---

## 3. Factions

### 3.1 Northern Coalition (Western remnant)
Professional, few, well-equipped. *Eyes and precision.*
- **Strengths:** thermal optics, long-range precision fires, best drones, best dosimetry/decontamination, high-quality infantry.
- **Weaknesses:** expensive, slow to replace, heavy fuel/spare-part demand; drones and radars raise EM signature.
- **Faction mechanic — Networked Fires:** units sharing a radio net can hand targets to artillery/ATGM teams out of their own line of sight. Requires emitting (raises signature).

### 3.2 Eastern Command (Eastern remnant)
Mass, armour, artillery. *Steel and fire.*
- **Strengths:** cheap, fast-replaced units; heavy rocket artillery; strong electronic warfare; vehicles with collective NBC overpressure and anti-radiation liners (best shielding).
- **Weaknesses:** older optics and night fighting, weaker recon, conscript infantry with low morale and high dose uptake.
- **Faction mechanic — Barrage Doctrine:** pre-planned fire missions on map grids are cheaper and faster; EW trucks can jam enemy radio nets (cuts Networked Fires) and mask friendly signatures.

### 3.3 Non-player forces (PvE)
- **Marauders:** deserters and bandit militias with technicals, captured old armour (MBT-55), RPGs, mortars.
- **Rogue remnant units:** AI-controlled detachments of either faction with proper doctrine.
- **Local self-defence:** neutral/variable; can be traded with or turned hostile.
- **Salvage traders (base camp):** sell parts, captured vehicles, intel; recruit contractors.

### 3.4 Unit rosters (v1)

Costs: **SUP** = supply points (abstracts fuel+ammo+parts for purchase), **MP** = manpower. Upkeep (fuel/ammo consumption) is handled by logistics (§5.1). PF = radiation protection factor (§5.4). Numbers are starting tunables.

**Northern Coalition**

| ID | Name | Role | SUP | MP | PF | Notes |
|---|---|---|---|---|---|---|
| `nc_rifle_sqd` | Rifle Squad (8) | Infantry | 60 | 8 | 1 | Thermal scopes, LAW |
| `nc_atgm_team` | ATGM Team (3) | AT infantry | 120 | 3 | 1 | Fire-and-forget, 2.5 km |
| `nc_recon_team` | Recon Team (4) | Scout | 80 | 4 | 1 | Long optics, laser designator, low signature |
| `nc_mortar_team` | Mortar Team (4) | Indirect | 90 | 4 | 1 | 81 mm |
| `nc_decon_sqd` | CBRN Squad (4) | Support | 70 | 4 | 2 | Decontaminates units/areas, detailed dose readout |
| `nc_ifv_90` | IFV-90 | IFV | 260 | 3 | 8 | 40 mm autocannon, carries 7 |
| `nc_apc_8x8` | APC 8x8 | APC | 160 | 2 | 5 | Fast, carries 10 |
| `nc_mbt_2a` | MBT-2A | MBT | 520 | 4 | 12 | Best optics/accuracy, high fuel use |
| `nc_spg_155` | SPG-155 | Artillery | 480 | 4 | 6 | Shoot-and-scoot, counter-battery radar link |
| `nc_cbr_radar` | Counter-Battery Radar | Sensor | 300 | 3 | 3 | Locates firing artillery; **high signature** |
| `nc_uav_quad` | Quadcopter UAV | Recon drone | 40 | 0 | – | 6 min battery, operator required |
| `nc_uav_fixed` | Fixed-wing UAV | Recon drone | 150 | 0 | – | 20 min, wide view, high link signature |
| `nc_heli_util` | Utility Helicopter | Transport | 380 | 3 | 3 | Carries 11 |
| `nc_supply_truck` | Supply Truck | Logistics | 50 | 1 | 2 | Carries supply to units |
| `nc_engineer_veh` | Engineering Vehicle | Builder | 180 | 3 | 8 | Builds FOB structures, clears mines |

**Eastern Command**

| ID | Name | Role | SUP | MP | PF | Notes |
|---|---|---|---|---|---|---|
| `ec_motor_rifle` | Motor-Rifle Squad (9) | Infantry | 40 | 9 | 1 | RPG, PKM; low morale, cheap |
| `ec_rpg_team` | AT Team (3) | AT infantry | 70 | 3 | 1 | Wire-guided ATGM, 2 km, operator must keep LOS |
| `ec_recon_sqd` | Razvedka Squad (5) | Scout | 70 | 5 | 1 | Night vision (weaker than thermal) |
| `ec_mortar_team` | Mortar Team (4) | Indirect | 70 | 4 | 1 | 120 mm |
| `ec_chem_sqd` | Chemical Troops (4) | Support | 50 | 4 | 2 | Decon, smoke generation |
| `ec_ifv_2` | IFV-2 | IFV | 180 | 3 | 10 | 30 mm, ATGM, carries 7 |
| `ec_apc_80` | APC-80 | APC | 110 | 2 | 6 | Amphibious, carries 8 |
| `ec_mtlb` | MT-LB | Tracked utility | 80 | 2 | 6 | Tows guns, carries 10 |
| `ec_mbt_72` | MBT-72 | MBT | 340 | 3 | 18 | Autoloader, anti-rad liner, weaker optics |
| `ec_mbt_80` | MBT-80 | MBT | 440 | 3 | 18 | Faster, better FCS, high fuel use |
| `ec_spaa_23` | SPAA-23 | Air defence | 220 | 4 | 6 | Shreds drones/helis |
| `ec_mlrs_21` | MLRS-21 | Rocket artillery | 380 | 3 | 4 | 40-rocket salvo, long reload |
| `ec_spg_122` | SPG-122 | Artillery | 300 | 4 | 8 | |
| `ec_ew_truck` | EW Truck | Electronic warfare | 260 | 3 | 3 | Jams radio nets and drone links in radius; **very high signature while active** |
| `ec_heli_attack` | Attack Helicopter | Air | 520 | 2 | 4 | Rockets + ATGM |
| `ec_supply_truck` | Supply Truck | Logistics | 35 | 1 | 2 | |
| `ec_engineer_veh` | Engineering Vehicle | Builder | 140 | 3 | 10 | |

**Marauders (PvE only):** `mr_militia` (rifles), `mr_rpg`, `mr_technical` (HMG pickup), `mr_mortar`, `mr_mbt_55` (old captured tank), `mr_ifv_captured`.

---

## 4. Modes

| Mode | Players | Description |
|---|---|---|
| **Campaign** | 1 (co-op optional later) | Story operations through the Zone, both factions. Persistent roster between missions. |
| **Operations** | 1–4 co-op | Replayable procedural missions: secure depot, hold corridor, recover convoy, raid plant. Persistent company roster (crews, dose, veterancy). |
| **Containment** | 1–4 co-op | Hold a defensive position at the plant against escalating AI assaults while fallout worsens. |
| **Skirmish** | 1–4 vs AI, or 1v1/2v2 friends | Classic match: FOB, logistics, destroy HQ or hold objectives. |
| **Zone War** | 1v1 / 2v2 friends | Versus with fallout and optional AI marauders as third party; win by HQ kill or **victory points** from holding depots/objectives when the timer ends. |

Versus rules: no persistent progression, no ranked play, invite-only Steam lobbies.

---

## 5. Core systems

### 5.1 Economy & logistics
- **Resources:** `SUPPLY` (spent to buy units/structures), `MANPOWER` (crew pool, slow regen + captured/recruited), plus per-unit **fuel** and **ammo** levels.
- **Income:** captured **depots** (map objectives) generate SUPPLY per tick to the owner, but only if connected to the FOB by a **supply route** (road path not cut by enemy presence) or served by supply trucks.
- **Upkeep:** vehicles consume fuel while moving; weapons consume ammo. Units resupply in range of the FOB, a supply depot structure, or a supply truck.
- **Out of fuel:** vehicle immobile. **Out of ammo:** can't fire that weapon.
- **Repair:** at repair yard or by engineering vehicle; requires SUPPLY. **Contaminated vehicles can't be repaired until decontaminated.**

### 5.2 Forward Operating Base (building)
Buildings are placed on a grid by engineering vehicles (and slowly by infantry for trenches).

| ID | Structure | Function |
|---|---|---|
| `hq` | Command Post | Required. Loss = defeat in skirmish. Radio net hub. |
| `supply_depot` | Supply Depot | Resupply radius, stores supply |
| `motor_pool` | Motor Pool | Produces vehicles |
| `barracks` | Barracks | Produces infantry |
| `repair_yard` | Repair Yard | Repairs vehicles |
| `field_hospital` | Field Hospital | Heals infantry, treats radiation sickness, recovers crews |
| `decon_point` | Decontamination Point | Removes contamination from units (time + supply) |
| `helipad` | Helipad | Produces/rearms helicopters |
| `artillery_park` | Artillery Park | Unlocks/rearms artillery |
| `trench` / `vehicle_pit` / `bunker` | Fortifications | Cover + radiation shielding |
| `minefield` / `wire` / `tank_trap` | Obstacles | |

No tech tree in v1 — production buildings unlock their unit lists; some units require HQ upgrades (one-time SUPPLY cost).

### 5.3 Combat model
- **Line of sight** on a heightmap grid + forest/building occlusion layer. Forests block LOS beyond ~50 m and give cover.
- **Spotting:** each unit has optics range (day/night/thermal values). Targets have **concealment** (terrain, moving/stationary, firing reveals). Spotted state is per team.
- **Armour:** vehicles have front/side/rear/top armour values. Weapons have penetration and damage. Hit angle (relative facing) selects armour face.
  - `pen >= armour` → penetrating hit: damage + chance of **component damage** (engine/tracks/turret/optics) or **crew casualty**.
  - `pen < armour` → non-penetrating: small damage, suppression.
- **Accuracy:** base accuracy × range falloff × moving penalty × target size × veterancy × suppression.
- **Infantry:** squads of individual soldiers (HP each), **suppression** (0–100) reduces accuracy and movement; at high suppression the squad pins or retreats. **Morale** per faction quality.
- **Indirect fire:** artillery fires at a map position with dispersion; requires a spotter's LOS or a pre-planned grid. Firing artillery creates a large signature pulse (counter-battery).
- **ATGMs:** fire-and-forget (Coalition) vs wire-guided (Eastern: operator must keep LOS until impact; suppressing operator can miss).
- **Smoke:** blocks LOS (not thermal for Coalition thermal-equipped units — reduces it).
- **Air:** helicopters fly over the grid, vulnerable to SPAA/MANPADS; drones are low-HP spotters with battery timers.

### 5.4 Radiation (fallout) system
Realistic but abstracted. All values integer, stored in sim.

- **Contamination grid:** each map cell has `dose_rate` (µSv/h-scaled integer). Sources:
  - static **hot spots** baked into maps (plant, forest pockets, bogs, ditches),
  - dynamic **plumes** (scripted events: sarcophagus breach, plant fires) that advect with **wind** direction/speed and decay over time,
  - **rain** washes contamination out of the air into the ground → raises ground cells along the plume path.
- **Unit dose:** every sim tick, each unit's crew accrues `dose += cell_dose_rate / protection_factor`. Protection factor from unit (table above), modified by: inside trench/bunker (×2–4), buttoned-up vs open hatch, NBC overpressure active (Eastern vehicles, costs fuel).
- **Contamination on units:** driving through hot cells makes the vehicle itself `contaminated` (adds small ongoing dose to its crew and to infantry riding/adjacent) until decontaminated.
- **Dose effects (per soldier/crew, cumulative mSv):**

| Dose (mSv) | State | Effect |
|---|---|---|
| 0–249 | Normal | — |
| 250–999 | Exposed | −5% accuracy; flagged for rotation |
| 1000–1999 | Mild ARS | −15% accuracy, −10% speed (infantry), morale −1 |
| 2000–3999 | Severe ARS | −35% accuracy, can't capture objectives, morale −2; needs hospital |
| 4000+ | Critical | soldier incapacitated after delay; likely lost permanently |

- **Treatment:** field hospital slows progression and can recover Exposed/Mild crews over time. Iodine stocks (consumable) reduce dose uptake during plume events.
- **Tools:** dosimetry overlay (toggle) shows dose-rate heatmap; Coalition sees exact numbers, Eastern sees coarser bands unless chem troops are nearby.
- **Persistent modes:** dose carries over between missions in Campaign/Operations. Crews above thresholds must rest/retire.

### 5.5 Backscatter — electromagnetic signature & EW
The game's namesake. Emitters create detectable signatures.

- **Emitters & signature strength (tunables):** radio net link (low, continuous), drone control link (medium), counter-battery radar (high), EW jammer (very high), artillery firing (pulse, high, short), HQ (medium, constant).
- **Signature map:** each team's emitters write to an enemy-visible "signal" layer. Enemy units with **direction-finding (DF)** capability (HQ, recon, EW truck, CB radar for artillery) get **bearing lines / uncertainty ellipses**, not exact positions. Multiple DF sources triangulate → smaller ellipse.
- **Consequences:** an ellipse small enough becomes a valid **artillery target**. Fire-and-move is core gameplay.
- **EMCON toggle per unit/group:** `EMIT` / `RESTRICTED` / `SILENT`. Silent units don't emit, but lose radio net features (no Networked Fires, no shared spotting delay → spotted info reaches HQ only by proximity/courier).
- **Jamming (Eastern EW truck):** in radius, enemy radio nets and drone links degrade (drones lose control → return/crash; Networked Fires disabled). Jammer itself is a huge signature.
- **Team spotting delay:** with radio net, spotted enemies share to team instantly; without, after a delay or when within a friendly unit's range.

### 5.6 Weather & time of day
- Wind (direction/speed) drives plumes. Rain moves contamination to ground, reduces optics range. Fog reduces optics (thermal less affected). Night: day optics heavily reduced, NV/thermal matter.
- Weather changes on a seeded schedule per match.

### 5.7 Veterancy & crews
- Units gain XP from kills/spotting/survival. 3 ranks: Trained → Veteran → Elite (+accuracy, +reload, +morale).
- Vehicles have crews (count from roster). Crew casualties degrade performance (e.g. MBT without gunner can't fire). Bailed crews can be recovered to save manpower.
- In persistent modes the **company roster** stores named crews with XP and dose.

### 5.8 Fog of war & intel
- Three visibility layers per team: **visible** (in LOS now), **last known** (ghost markers), **unknown**.
- Signature ellipses (§5.5) are a separate intel layer.

---

## 6. AI

- **Commander AI (strategic):** utility-based. Evaluates goals: expand to depot, defend FOB, attack objective, counter-battery, retreat-from-fallout. Allocates units to **task forces**.
- **Task force AI (operational):** moves groups along safe paths (cost includes dose rate and threat), sets up overwatch, uses smoke, calls artillery on known/ellipse targets.
- **Unit AI (tactical):** target selection (threat × kill chance), auto-reverse to keep front armour toward threat, seek cover, retreat when suppressed/out of ammo.
- **Doctrine profiles:** Coalition AI = recon-first, standoff, precision; Eastern AI = mass, barrage, EW; Marauders = ambush, raid, opportunistic.
- **Difficulty:** affects reaction time, scouting cheat (none at Normal+), resource multipliers only at Easy/Hard extremes.
- AI must run inside the deterministic sim (same tick, same RNG) so co-op/versus with AI players stays in sync.

---

## 7. Technical architecture (Godot 4)

### 7.1 Language
- **GDScript with static typing everywhere** (`var x: int`, typed arrays, `class_name`).
- Sim hot paths that prove too slow (pathfinding, LOS, contamination grid) can later move to a **GDExtension (C++)** module with the same API. Design sim modules behind small interfaces to allow this.

### 7.2 Simulation / presentation split
```
[Input/UI] -> Commands -> [Lockstep Net] -> [Simulation (fixed tick, deterministic)] -> SimState
                                                                                       |
                                                    [Presentation (Nodes, 3D, VFX, audio, UI)] <- reads + interpolates
```
- **Sim tick rate:** 10 Hz (`TICK_MS = 100`). Rendering interpolates between last two sim states.
- **Sim is pure data:** `SimWorld` holds arrays/dictionaries of entity components. No Node inheritance in sim.
- **Entity model:** lightweight ECS-style — `EntityId: int`, component stores as typed arrays/dicts (`Transform`, `Mobility`, `Armour`, `Weapons`, `Crew`, `Dose`, `Supply`, `Emitter`, `Vision`, `Order`). Systems iterate in a **fixed, documented order** (§7.5).
- **Presentation:** one `UnitView` Node3D per entity, spawned/despawned by a `ViewSync` node listening to sim events.

### 7.3 Determinism rules
- **Fixed-point:** positions in **integer millimetres** (`int`), angles in integer **milliradians** or a 0–65535 binary angle; use a `FixedMath` util (int sqrt, atan2 lookup table, sin/cos tables).
- **RNG:** `SimRng` xorshift64* seeded from match seed; only sim code calls it, in deterministic order.
- **Iteration order:** never iterate Dictionaries where order could differ; iterate sorted entity IDs.
- **No** `float`, `Time`, `OS`, physics engine, `randf`, threads or signals inside sim step.
- **State checksum:** every N ticks compute a hash (e.g. FNV-1a over key component arrays); peers compare → desync detection and logging.

### 7.4 Networking (lockstep, peer-to-peer over Steam)
- **Steam integration:** GodotSteam (GDExtension) — lobbies, invites, P2P messaging (Steam Networking Messages/Sockets). Offline builds stub the Steam layer.
- **Lockstep:** commands scheduled for `current_tick + input_delay` (start 3 ticks = 300 ms, adaptive). A tick advances only when all peers' command packets (possibly empty) for that tick are received.
- **Host** = lobby owner; host assigns seed, map, settings; also authoritative for pause/speed.
- **Desync handling:** on checksum mismatch, log both states, notify players, offer to end match. Desync logs saved to `user://desync/`.
- **Replays:** match = seed + settings + command log → replay file. Free with lockstep; build in M3.
- **Reconnect:** v1 not required; v2 via state snapshot.
- **No dedicated servers, no third-party hosting.**

### 7.5 Sim tick order
1. Apply commands for this tick (sorted by player id, then sequence)
2. AI planning (commander every 10 ticks, task forces every 2 ticks, units every tick)
3. Orders → movement (pathfinding requests, steering, collision avoidance)
4. Vision & spotting update
5. Signature emission + DF + jamming
6. Weapons: target acquisition, firing, projectile/impact resolution
7. Damage, suppression, morale, crew casualties
8. Radiation: plume advection (every 10 ticks), dose accrual, contamination
9. Logistics: fuel/ammo consumption, resupply, income, production queues, construction
10. Veterancy, deaths/cleanup, event emission
11. Checksum (every 20 ticks)

### 7.6 Map & navigation
- **Map size:** 4×4 km to 8×8 km. Terrain heightmap (Godot `Terrain3D` plugin or custom mesh) for visuals; **sim uses its own grid** (cell = 8 m) with: height, terrain type (road/field/forest/bog/water/urban), movement cost per mobility class (foot/wheeled/tracked), LOS occlusion, cover value, contamination.
- **Pathfinding:** hierarchical — sector graph (64×64 cell sectors) + A* on cells within path corridor; **flow fields** for large group moves to the same target. Cost includes threat and dose rate (configurable per order: "fastest" / "safest").
- **Local avoidance:** simple deterministic separation steering on a spatial hash; vehicles have turning radius.
- Bogs: wheeled vehicles slow/stuck; roads give speed bonus — logistics depends on roads.

### 7.7 Data
- Unit, weapon, building, faction defs as **Godot Resources** (`UnitDef.tres`, `WeaponDef.tres`) under `data/`, with a JSON export/import tool so balance can be edited in spreadsheets.
- On sim start, defs are converted to immutable integer stat tables (no floats leak into sim).

Example `UnitDef` fields:
```
id, faction, display_name, role, cost_supply, cost_manpower, build_time_ticks,
mobility_class, max_speed_mm_per_tick, turn_rate, fuel_capacity, fuel_per_km,
hp, armour {front, side, rear, top}, protection_factor, nbc_overpressure: bool,
crew_slots [driver, gunner, commander, loader?], passenger_capacity,
vision {day_m, night_m, thermal_m}, concealment, size_class,
weapons [WeaponDef ids], emitter {type, strength} or null,
abilities [smoke, dig_in, designate, jam, decon, build, repair]
```

Example `WeaponDef` fields:
```
id, type (direct|indirect|atgm|aa), range_min_m, range_max_m, penetration, damage,
suppression, reload_ticks, aim_ticks, ammo_capacity, ammo_per_shot,
accuracy_base, accuracy_range_falloff, guidance (none|fire_forget|wire), blast_radius_m
```

### 7.8 Project structure
```
res://
  addons/            # GodotSteam, test framework, terrain plugin
  data/
    factions/ units/ weapons/ buildings/ maps/ campaign/
  sim/               # NO Nodes here (RefCounted / plain classes only)
    core/            # SimWorld, SimRng, FixedMath, EntityStore, Checksum
    systems/         # movement, vision, signature, combat, damage, radiation, logistics, production, veterancy
    ai/              # commander, taskforce, unit_ai, doctrines
    nav/             # grid, sectors, astar, flowfield
    commands/        # Command types + validation
  net/               # lockstep, steam_transport, offline_transport, replay
  presentation/
    views/           # UnitView, BuildingView, ProjectileView, FalloutView
    camera/ fx/ audio/ hud/ overlays/  # dosimetry + signal overlays
  ui/                # menus, lobby, roster/base camp screens
  modes/             # campaign, operations, containment, skirmish, zone_war rules
  tests/             # headless sim tests
  tools/             # balance JSON import/export, map baker, desync diff
```

### 7.9 Testing
- Headless test runner (GUT or gdUnit4) in CI-able form: `godot --headless -s tests/run.gd`.
- **Determinism test:** run the same seed + command log twice (and with entity IDs inserted in different order) → identical checksums every tick.
- Per-system unit tests (armour penetration, dose accrual, DF triangulation, pathfinding).
- Soak test: 2 AIs vs each other for 30 sim-minutes, no errors, checksum stable.

---

## 8. Controls & UI

- Classic RTS: left-click select, box select, right-click contextual order, control groups (Ctrl+1–9), formations, waypoint queue (Shift).
- Orders: Move (fast / safe-from-fallout), Attack-move, Hold, Reverse-move, Unload, Dig in, Smoke, Fire mission (grid), Designate, EMCON level, Return to resupply/decon.
- Speed control in single-player/co-op (pause, 1×, 2×, 4×); versus: host can pause.
- **Overlays:** dosimetry (dose-rate heatmap + wind arrow), signal (own emissions + enemy DF ellipses), supply routes, LOS preview for selected unit.
- **Unit card:** HP, armour diagram, crew with individual dose bars, ammo/fuel, veterancy, contamination flag.
- HUD sound: Geiger counter click rate increases with selected units' dose rate.

---

## 9. Art & audio direction

- Overcast Nordic light, wet asphalt, autumn birches, fog over bogs, Soviet-era concrete, rusted border infrastructure. Grounded, desaturated, no neon "glow".
- Camouflage: Coalition splinter/digital greens; Eastern olive and three-tone.
- Radiation readability via **overlay and instruments**, not glowing ground (keep realism). Optional subtle heat-shimmer/grain in very hot zones.
- Audio: authentic weapon sounds, radio chatter with squelch, Geiger counter, wind, rain.
- Camera: perspective RTS camera, pitch 40–70°, zoom from squad level to ~1.5 km view.

---

## 10. Campaign outline (v1)

- **Act I — The Corridor** (Coalition): secure the border road, first depot, first fallout event.
- **Act II — Red Forest** (Eastern): push through contaminated forest; EW vs drones; crew rotation pressure.
- **Act III — Kaarnavaara** (alternating): both sides converge on the plant; sarcophagus breach changes the map mid-mission.
- Between missions: **base camp** screen — repair, decontaminate, rotate crews, spend SUPPLY, buy from salvage traders, review dosimetry of your company.
- 12–15 missions total for v1.

---

## 11. Balance notes (starting points)
- Coalition unit ≈ 1.4–1.6× cost of Eastern equivalent; should win ~60% of equal-count 1:1 fights at range, lose at close range vs mass.
- Artillery is lethal but loud: an SPG that fires 3 times from the same spot should usually be found by an enemy CB radar/DF.
- A tank crew sitting buttoned-up in a moderate hot spot for a full match should reach "Exposed", infantry in the same spot "Severe".
- Matches (skirmish/Zone War): 25–40 minutes.

---

## 12. Milestones (build in this order)

### M0 — Project skeleton
- Godot project, folder structure (§7.8), static typing enforced, test runner working headless.
- `SimWorld`, `SimRng`, `FixedMath`, `EntityStore`, fixed 10 Hz tick loop, render interpolation stub.
- **Accept:** headless test spawns 100 entities, runs 1000 ticks, checksum identical across two runs.

### M1 — Map, movement, selection
- Sim grid from a test map (height, terrain types), hierarchical pathfinding, flow fields, deterministic avoidance.
- RTS camera, selection, move orders, control groups; placeholder unit views with interpolation.
- **Accept:** 200 units move across a 4×4 km map without stacking/stuck at 60 FPS; determinism test passes.

### M2 — Combat core
- Vision/spotting, fog of war layers, weapons, armour facing/penetration, damage, infantry suppression/morale, smoke, indirect fire.
- Data-driven `UnitDef`/`WeaponDef` for ~6 units per faction.
- **Accept:** scripted 20v20 skirmish resolves plausibly; armour-facing unit tests pass; determinism holds.

### M3 — Lockstep multiplayer + replays
- Command system, lockstep with offline loopback and GodotSteam transport, lobbies/invites, checksum desync detection, replay record/playback.
- **Accept:** two PCs play 20 minutes over Steam with no desync; replay of that match reproduces final checksum.

### M4 — Economy, logistics, base building
- SUPPLY/MANPOWER, depots, supply routes, fuel/ammo consumption, resupply, engineers, FOB structures, production queues, repair.
- **Accept:** full skirmish loop playable vs a dummy opponent: build FOB → capture depot → produce units → destroy HQ.

### M5 — Radiation
- Contamination grid, hot spots, wind-driven plumes, rain, dose accrual with protection factors, contamination, dose states/effects, decon point, field hospital, dosimetry overlay, Geiger audio.
- **Accept:** unit tests for dose math; a plume event visibly drifts with wind and changes AI-free pathing costs ("safe" move avoids it).

### M6 — Backscatter (signature & EW)
- Emitters, signal layer, DF bearings/triangulation ellipses, counter-battery, EMCON states, radio nets & Networked Fires, EW jamming, drones.
- **Accept:** an SPG firing repeatedly gets located and counter-fired by AI CB; jammer disables drone links in radius; signal overlay readable.

### M7 — AI
- Commander/task force/unit AI with doctrine profiles; AI respects fallout and signatures; Marauder AI.
- **Accept:** AI vs AI soak test 30 min stable; Normal AI beats a passive player and loses to a competent one; AI works in co-op and versus-with-AI without desync.

### M8 — Modes & content
- Skirmish, Zone War, Containment, Operations (persistent roster), Campaign Act I.
- Full v1 rosters (§3.4), 3 skirmish maps, art pass, audio pass, menus, settings, Steam achievements.
- **Accept:** vertical slice suitable for a Steam Next Fest demo (Act I mission 1–2 + one skirmish map).

---

## 13. Coding conventions
- GDScript, static types everywhere, `class_name` for shared classes, `snake_case` files/functions, `PascalCase` classes.
- Sim classes extend `RefCounted` (never `Node`). Mark sim files with a header comment `# SIM: deterministic — no floats, no Nodes`.
- One system per file; systems expose `func step(world: SimWorld, tick: int) -> void`.
- Commands are immutable data classes with `validate(world) -> bool` and `apply(world)`.
- All tunables in `data/` or `sim/core/constants.gd`.
- Each PR/change: update or add tests; run determinism test.

---

## 14. Open questions
- Final faction/nation names, insignia, and plant name.
- Terrain approach: Terrain3D plugin vs custom heightmap mesh (decide in M1 based on performance).
- Whether co-op Campaign ships in v1 or post-launch.
- Mod support (data-driven defs make this cheap — Steam Workshop for maps/units post-launch?).
- Price point and Early Access scope.

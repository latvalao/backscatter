# Backscatter — implementation plan

Follows `docs/DESIGN.md` §12. Each milestone ends when its acceptance criteria pass
in CI. Status: ✅ done · 🟡 in progress · ⬜ not started.

## M0 — Project skeleton ✅
- ✅ Folder structure (§7.8), `project.godot` with untyped declarations = error
- ✅ `SimConst`, `FixedMath` (isqrt, baked sin/atan tables, binary angles), `SimRng`
  (xoshiro128**, 32-bit masked), `EntityStore` (monotonic ids), SoA component stores
- ✅ `SimWorld` fixed tick order, `CommandQueue` (sorted by player, sequence),
  deferred destruction, `SimEvent` stream, FNV-1a `Checksum` every 20 ticks
- ✅ Presentation: `SimRunner` (10 Hz accumulator + interpolation), `ViewSync`,
  `UnitView`, `RtsCamera`, M0 demo scene (100 wandering units)
- ✅ Headless test runner `tests/run.gd`, `tools/lint_sim.py`, GitHub Actions CI
- ✅ **Accept:** CI green — determinism test (100 entities × 1000 ticks, identical checksums every tick); 29/29 tests

## M1 — Map, movement, selection ✅
- ✅ `SimGrid` (8 m cells): height, terrain type, per-mobility step costs, sector cost table
- ✅ `MapGen`: deterministic integer value-noise map — fields, forest, lakes + bog, rock,
  two crossing roads, village (4×4 km = 500×500 cells)
- ✅ `UnitDef`/`WeaponDef` as JSON under `data/` → `content/def_loader.gd` → immutable int
  `UnitStats`/`WeaponStats` in `DefDb`
- ✅ Hierarchical pathfinding: sector-graph A* corridor → cell A* (weighted, budgeted,
  closest-reachable fallback) → road-preserving path smoothing; `safety_cost` hook for M5
- ✅ Flow fields (Dijkstra) shared by group moves of ≥6 units per mobility class
- ✅ Formation slots, deterministic separation on a spatial hash, turn rates, kinematic
  braking, terrain slide, stall detection/repath, Shift-queued orders, reverse move
- ✅ Presentation: chunked terrain mesh from the grid (custom mesh, decided), MultiMesh
  trees/houses, RTS camera (edge/arrow/MMB pan, zoom, rotate, pitch 40–70°), box/click
  selection, right-click orders, control groups, interpolated unit views
- ✅ **Accept:** 200 mixed units cross the 4×4 km map (≈7 ms/tick sim), ≤4 stragglers,
  no stacking; determinism incl. shuffled command insertion order
- Notes: a 300-unit flow field over a large window costs ~1 s in GDScript on the order
  tick — first candidate for GDExtension or spreading over ticks.

## M2 — Combat core ✅
- ✅ Vision/spotting: optics day/night/thermal × target visibility (unit, terrain, moving,
  fired), staggered 5-tick scans, LOS over heights + forest/urban/rock depth (~50 m forest)
- ✅ Fog of war: per-team visible / last known (ghost markers) / unknown; terrain fog shader
- ✅ Weapons: target scoring (effectiveness × range, threat), own-LOS check, aim/reload,
  ammo, burst scaled by surviving squad members, loader/gunner/turret effects
- ✅ Armour facing (front ±45°, rear ±45°, side, top for indirect), penetration, damage
  roll, component damage (engine/tracks/turret/optics), crew casualties
- ✅ Infantry squads of individual soldiers, cover, suppression 0–1000, pin, morale, retreat
- ✅ Projectiles: fire-and-forget vs wire-guided ATGMs (operator LOS/suppression), shells
- ✅ Indirect fire missions (spotter LOS required, dispersion, blast), smoke (launchers +
  smoke rounds; thermal sees through at half range)
- ✅ ~7 units per faction as data (+ supply trucks), attack / attack-move / stop / hold fire
- ✅ **Accept:** scripted 20v20 resolves (Coalition wins at range as §11 expects), armour
  facing unit tests, battle determinism
- Balance is first-pass only; Coalition currently wins the scripted 20v20 decisively.

## M3 — Lockstep multiplayer + replays ✅ (Steam path untested here)
- ✅ Command serialization (`CommandCodec`, byte-identical round trip for every command)
- ✅ `Lockstep`: turns scheduled at tick + input delay (3 networked / 1 solo), tick runs
  only with every human's turn, checksum exchange every 20 ticks, desync signal +
  `user://desync/` dumps (`tools/desync_diff.py`); host-controlled pause/speed
- ✅ Transports behind one interface (star topology, host relays game messages):
  `LoopbackTransport` (tests, simulated latency/jitter), `ENetTransport` (LAN / direct
  IP, UDP 27960), `SteamTransport` (GodotSteam lobbies, overlay invites, P2P packets)
- ✅ Invite-only `Lobby` protocol (HELLO/WELCOME/ROSTER/START), AI slots, teams
- ✅ Replays: settings + per-tick commands + checksums; `ReplayPlayer` verifies every
  checksum; auto-saved to `user://replays/` on victory / leave / F12; menu viewer
- ✅ AI players run inside the sim (`AiController`), so AI matches stay in sync
- ✅ Main menu: skirmish vs AI, sandbox, host/join LAN, host Steam lobby, last replay
- ✅ Tests: two lagged peers stay bit-identical 400 ticks + replay matches; desync
  detection; replay tamper detection; CI runs a real two-process ENet session
- ⬜ **Accept (needs two PCs + Steam):** 20 min over Steam without desync; replay
  reproduces final checksum. Install GodotSteam (see `net/transport/steam_transport.gd`).

## M4 — Economy, logistics, base building ✅
- ✅ SUPPLY / MANPOWER per player (start 2000 / 80, manpower regen), rules in
  `data/rules/economy.json`
- ✅ Structures as data (`data/buildings/`): HQ, supply depot, barracks, motor pool,
  artillery park, repair yard, trench, vehicle pit, tank traps, depot objective;
  footprints block movement per mobility class (dynamic grid costs)
- ✅ Engineers (and infantry for trenches) build via `BuildCommand`; sites grow with
  builder time; placement rules (buildable terrain, no overlap, no units in the way)
- ✅ Production queues (`ProduceCommand`, cancel/refund, rally points), unit lists per
  building role and faction
- ✅ Depot objectives: capture by presence (contested = frozen), income only when a road
  route to a friendly HQ/supply depot avoids enemy units — else stock for supply trucks
- ✅ Fuel burn per km (out of fuel = immobile), ammo; resupply near HQ / supply depot /
  loaded truck (costs supply); repair at repair yard or by idle engineers
- ✅ Skirmish rules: lose all HQs = defeated; victory banner; `SkirmishAi` dummy opponent
- ✅ UI: resources HUD, build menu + placement ghost, production panel + queue, depot flags
- ✅ **Accept:** `test_skirmish_loop` — build FOB → capture depot → produce → destroy HQ
- Deferred: HQ upgrades (one-time unlocks), helipad, minefields/wire, field hospital and
  decon point (M5), crew recovery.

## M5 — Radiation ⬜ (next)
## M6 — Backscatter (signature & EW)
## M7 — AI
## M8 — Modes & content
(Broken down when the previous milestone lands — see DESIGN.md §12 for scope.)

## Decisions / deviations to confirm
- **RNG:** design says xorshift64*; implemented xoshiro128** on 32-bit lanes because
  GDScript ints are signed 64-bit and a 64-bit multiply would rely on overflow wrap.
  Same role, seeded per match, golden-value tested.
- **Test framework:** a ~100-line built-in runner instead of GUT/gdUnit4 (no addon
  dependency, same `godot --headless -s tests/run.gd` entry point). Can switch later.
- **Engine version:** pinned to Godot 4.5.1 in CI.
- **Defs as JSON:** units/weapons live as JSON (human units: m, km/h, s) rather than
  `.tres`; the loader converts to integer stat tables. Spreadsheet-friendly, per §7.7.
- **Suppression scale:** stored 0–1000 (tenths of the doc's 0–100).
- **Fixed input delay** of 3 ticks for networked play (adaptive delay later, as needed).
- **Steam transport** uses GodotSteam's classic P2P packet API (simplest, widely used);
  can move to Networking Messages later behind the same interface.
- **Terrain tunables** (speeds, cover, concealment, LOS depth) live in
  `sim/nav/terrain_table.gd` as a constants file.

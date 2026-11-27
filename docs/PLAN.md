# Backscatter — implementation plan

Follows `docs/DESIGN.md` §12. Each milestone ends when its acceptance criteria pass
in CI. Status: ✅ done · 🟡 in progress · ⬜ not started.

## M0 — Project skeleton 🟡 (code complete, awaiting first green CI run)
- ✅ Folder structure (§7.8), `project.godot` with untyped declarations = error
- ✅ `SimConst`, `FixedMath` (isqrt, baked sin/atan tables, binary angles), `SimRng`
  (xoshiro128**, 32-bit masked), `EntityStore` (monotonic ids), SoA component stores
- ✅ `SimWorld` fixed tick order, `CommandQueue` (sorted by player, sequence),
  deferred destruction, `SimEvent` stream, FNV-1a `Checksum` every 20 ticks
- ✅ Presentation: `SimRunner` (10 Hz accumulator + interpolation), `ViewSync`,
  `UnitView`, `RtsCamera`, M0 demo scene (100 wandering units)
- ✅ Headless test runner `tests/run.gd`, `tools/lint_sim.py`, GitHub Actions CI
- ⬜ **Accept:** CI green — determinism test (100 entities × 1000 ticks, identical checksums)

## M1 — Map, movement, selection
1. `SimGrid` (8 m cells): height, terrain type, per-mobility-class cost, LOS occlusion, cover.
   Test map baked from a PNG/JSON by `tools/map_baker` (4×4 km = 500×500 cells).
2. `UnitDef` resource + JSON import → immutable int stat tables; first defs (truck, MBT, squad).
3. Nav: sector graph (64×64 cells) + cell A* in corridor; flow fields for group moves;
   "fastest"/"safest" cost profiles (dose/threat hooks stubbed).
4. Movement: `MoveCommand`, waypoint queue, steering with turn rate, spatial-hash
   separation avoidance (deterministic), terrain speed modifiers.
5. Presentation: terrain mesh from grid (decide Terrain3D vs custom mesh — open question),
   box/drag selection, right-click move, control groups, Shift-queue.
6. Determinism test v2: entity insertion order permutation; benchmark 200 units @ 60 FPS.

## M2 — Combat core
Vision/spotting + 3-layer fog of war, `WeaponDef`, armour facing/penetration, damage,
component/crew hits, infantry squads + suppression/morale, smoke, indirect fire.
~6 units per faction as data. Scripted 20v20 scenario test.

## M3 — Lockstep multiplayer + replays
Command serialization, lockstep scheduler (input delay 3 ticks, adaptive), offline
loopback transport, GodotSteam transport + lobbies/invites, checksum exchange + desync
dumps, replay record/playback.

## M4 — Economy, logistics, base building
## M5 — Radiation
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

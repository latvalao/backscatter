# Backscatter — notes for Claude Code

- Source of truth: `docs/DESIGN.md` (gameplay) and `docs/VISUALS.md` (art/rendering; gameplay readability wins). Ask before deviating from it.
- Progress / next steps: `docs/PLAN.md` (update it when a milestone task lands).
- Hard rules: deterministic integer-only sim under `sim/` (no floats, Nodes,
  engine RNG, Time/OS, physics, threads, signals); presentation only reads sim
  state; every gameplay input is a `SimCommand`; all stats are data in `data/`.
- Before committing:
  - `python3 tools/lint_sim.py`
  - `godot --headless --path . --import` (once) then
    `godot --headless --path . -s res://tests/run.gd -- --fast` (~1 min, every change)
  - long milestone acceptance / soak tests are named `test_slow_*`; run them with
    `-- --slow` (~8 min) before finishing a milestone. CI runs both, in parallel jobs.
  - Keep tests lean: smallest map / tick count that still proves the point; reuse
    the sim's periodic checksum instead of hashing every tick; share reference runs.
- Godot 4.5.1, GDScript with static types everywhere (untyped declarations are errors).
- Models are generated: edit `tools/forge/*.gd`, then
  `godot --headless --path . -s res://tools/model_forge.gd` (writes `presentation/assets/`).
  Look presets are data in `presentation/look/` (palette.json, presets/*.tres).

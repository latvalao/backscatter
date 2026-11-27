# Backscatter — notes for Claude Code

- Source of truth: `docs/DESIGN.md`. Ask before deviating from it.
- Progress / next steps: `docs/PLAN.md` (update it when a milestone task lands).
- Hard rules: deterministic integer-only sim under `sim/` (no floats, Nodes,
  engine RNG, Time/OS, physics, threads, signals); presentation only reads sim
  state; every gameplay input is a `SimCommand`; all stats are data in `data/`.
- Before committing:
  - `python3 tools/lint_sim.py`
  - `godot --headless --path . --import` (once) then `godot --headless --path . -s res://tests/run.gd`
- Godot 4.5.1, GDScript with static types everywhere (untyped declarations are errors).

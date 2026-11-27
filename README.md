# Backscatter

Realistic West-vs-East RTS in a radioactive exclusion zone. Godot 4 · PC.

- Design: [`docs/DESIGN.md`](docs/DESIGN.md)
- Plan & status: [`docs/PLAN.md`](docs/PLAN.md)

## Running

Requires Godot **4.5.1**.

```bash
godot --path .                 # M0 demo: 100 wandering units (WASD pan, wheel zoom, Q/E rotate, P pause, 1-4 speed)
```

## Tests

```bash
python3 tools/lint_sim.py                               # determinism rules for sim/
godot --headless --path . --import                      # first time: build class cache
godot --headless --path . -s res://tests/run.gd         # all tests
godot --headless --path . -s res://tests/run.gd -- --filter=determinism
```

## Layout

| Path | Contents |
|---|---|
| `sim/` | Deterministic simulation. Integer math only, `RefCounted` classes, no Nodes. |
| `presentation/` | Nodes that read sim state and interpolate (views, camera, HUD). |
| `net/` | Lockstep, transports, replays (M3). |
| `data/` | Unit/weapon/building/faction definitions. |
| `modes/` | Game mode rules and scenes. |
| `tests/` | Headless tests (`test_*.gd`). |
| `tools/` | Lint, table generators, balance/map tools. |

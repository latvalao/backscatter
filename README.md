# Backscatter

Realistic West-vs-East RTS in a radioactive exclusion zone. Godot 4 · PC.

- Design: [`docs/DESIGN.md`](docs/DESIGN.md)
- Plan & status: [`docs/PLAN.md`](docs/PLAN.md)

## Running

Requires Godot **4.5.1**.

```bash
godot --path .                 # main menu: skirmish vs AI, sandbox, LAN host/join, Steam lobby, replays
```

Skirmish: you start with an HQ, an engineer, a supply truck and a few units. Select the
engineer to build (barracks, motor pool, supply depot…), select a finished building to
produce units (right-click sets the rally point), take the depots on the roads for income,
and destroy the enemy HQ. LAN games use UDP port 27960. Steam play needs the GodotSteam
addon (see `net/transport/steam_transport.gd`).

Controls: LMB select / box, RMB move or attack, Shift queue, Alt+RMB reverse, A attack-move,
R reverse, F fire mission, G smoke mission, X smoke launchers, S stop, H hold fire,
Ctrl+1–9 / 1–9 groups, arrows / screen edge / MMB pan, wheel zoom, Q/E rotate,
PgUp/PgDn pitch, F1–F8 build/produce buttons, Z EMCON (emit / restricted / silent),
Ctrl+RMB safe route (avoids fallout), D dosimetry overlay, V signal overlay, P pause,
+/- speed, F9 reveal map (solo), F10 labels, F12 save replay, Esc menu.

## Tests

```bash
python3 tools/lint_sim.py                               # determinism rules for sim/
godot --headless --path . --import                      # first time: build class cache
godot --headless --path . -s res://tests/run.gd -- --fast # everyday suite (~1 min)
godot --headless --path . -s res://tests/run.gd -- --slow # milestone acceptance + 30-min AI soak (~8 min)
godot --headless --path . -s res://tests/run.gd         # everything
godot --headless --path . -s res://tests/run.gd -- --filter=determinism
godot --headless --path . -s res://tools/check_scripts.gd     # compile every script
godot --headless --path . -s res://tests/smoke_scene.gd       # boot menu + skirmish + sandbox headless
tools/net_selftest.sh godot                                   # two processes, lockstep over ENet
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

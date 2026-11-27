# SIM: deterministic — no floats, no Nodes
## Global sim tunables. Gameplay stats live in data/, not here.
class_name SimConst
extends RefCounted

const TICK_MS: int = 100
const TICKS_PER_SECOND: int = 10
const CHECKSUM_INTERVAL: int = 20

## Binary angle: 65536 units per full turn.
const ANGLE_FULL: int = 65536
const ANGLE_HALF: int = 32768
const ANGLE_QUARTER: int = 16384
const ANGLE_MASK: int = 0xFFFF

## Positions are integer millimetres.
const MM_PER_M: int = 1000

const MASK32: int = 0xFFFFFFFF

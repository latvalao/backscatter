# SIM: deterministic — no floats, no Nodes
## Terrain types and mobility classes. Tunables (constants file per §13).
class_name TerrainTable
extends RefCounted

const ROAD: int = 0
const FIELD: int = 1
const FOREST: int = 2
const BOG: int = 3
const WATER: int = 4
const URBAN: int = 5
const ROCK: int = 6
const COUNT: int = 7
const NAMES: Array[String] = ["road", "field", "forest", "bog", "water", "urban", "rock"]

const FOOT: int = 0
const WHEELED: int = 1
const TRACKED: int = 2
const MOBILITY_COUNT: int = 3
const MOBILITY_NAMES: Array[String] = ["foot", "wheeled", "tracked"]

## Speed multiplier permille, indexed [mobility * COUNT + terrain]. 0 = impassable.
const SPEED: Array[int] = [
	# road  field forest bog  water urban rock
	1000, 900, 700, 450, 0, 850, 450,   # foot
	1000, 550, 120, 150, 0, 700, 0,     # wheeled
	900, 750, 300, 350, 0, 600, 0,      # tracked
]

## Infantry cover permille (reduces incoming hit chance / blast effect).
const COVER: Array[int] = [0, 50, 400, 100, 0, 500, 450]

## Target visibility multiplier permille (lower = better concealment).
const CONCEAL: Array[int] = [1000, 900, 450, 850, 1000, 500, 650]

## LOS is blocked once a ray has passed through this much of the terrain (mm). 0 = never blocks.
const BLOCK_DEPTH_MM: Array[int] = [0, 0, 50000, 0, 0, 16000, 24000]


static func speed(mobility: int, terrain: int) -> int:
	return SPEED[mobility * COUNT + terrain]

# SIM: deterministic — no floats, no Nodes
## Immutable integer unit stats (converted from data/units/*.json at load).
class_name UnitStats
extends RefCounted

const CREW_DRIVER: int = 1
const CREW_GUNNER: int = 2
const CREW_COMMANDER: int = 4
const CREW_LOADER: int = 8

const SIZE_INFANTRY: int = 0
const SIZE_SMALL: int = 1
const SIZE_LARGE: int = 2

var index: int = 0
var id: String = ""
var faction: String = ""
var display_name: String = ""
var role: String = ""
var cost_supply: int = 0
var cost_manpower: int = 0
var build_time_ticks: int = 0

var mobility_class: int = TerrainTable.FOOT
var max_speed: int = 0          # mm/tick
var accel: int = 1              # mm/tick per tick
var turn_rate: int = 0          # binary angle per tick
var radius_mm: int = 1000
var stabilized: bool = false

var is_infantry: bool = false
## Infantry: soldiers in the squad; each has `hp`. Vehicles: 1.
var members: int = 1
var hp: int = 100
var armour_front: int = 0
var armour_side: int = 0
var armour_rear: int = 0
var armour_top: int = 0
var protection_factor: int = 1
var crew_slots: int = 0
var passenger_capacity: int = 0

var vision_day_mm: int = 0
var vision_night_mm: int = 0
var vision_thermal_mm: int = 0
## Base visibility permille (lower = harder to spot).
var visibility: int = 1000
var size_class: int = SIZE_INFANTRY
var eye_height_mm: int = 1700
var target_height_mm: int = 1000

var morale: int = 700
var smoke_charges: int = 0
var weapons: PackedInt32Array = PackedInt32Array()
var abilities: PackedStringArray = PackedStringArray()


func is_vehicle() -> bool:
	return not is_infantry


func has_crew(slot: int) -> bool:
	return (crew_slots & slot) != 0


func crew_count() -> int:
	var n: int = 0
	for b: int in [CREW_DRIVER, CREW_GUNNER, CREW_COMMANDER, CREW_LOADER]:
		if (crew_slots & b) != 0:
			n += 1
	return n

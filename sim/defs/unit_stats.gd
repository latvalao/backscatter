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
## Collective NBC overpressure (Eastern vehicles): doubles PF in hot cells, costs fuel.
var nbc: bool = false
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
## Building role that produces this unit ("barracks", "motor_pool", ...);
## for structures: "engineer", "infantry" or "none" (placed by scenario only).
var built_at: String = ""
var fuel_capacity: int = 0      # mL; 0 = no fuel needed (infantry)
var fuel_per_km: int = 0        # mL per km
var cargo_capacity: int = 0     # SUPPLY a logistics vehicle can carry

# --- air (drones) ---
var is_air: bool = false
var altitude_mm: int = 0
var battery_ticks: int = 0      # flight endurance; 0 = unlimited

# --- signature / EW (§5.5) ---
const EMIT_NONE: int = 0
const EMIT_RADIO: int = 1
const EMIT_DRONE_LINK: int = 2
const EMIT_RADAR: int = 3
const EMIT_JAMMER: int = 4
const EMIT_HQ: int = 5
const EMIT_NAMES: Array[String] = ["none", "radio", "drone_link", "radar", "jammer", "hq"]
var emitter_kind: int = EMIT_NONE
## Signal strength; detectable by direction finding out to strength × 100 m × DF quality.
var emitter_strength: int = 0
## Direction-finding quality 0 (none) .. 3 (EW truck).
var df_quality: int = 0
var jam_radius_mm: int = 0

# --- structures ---
var is_structure: bool = false
var footprint_w: int = 0        # cells
var footprint_h: int = 0
## Bitmask of mobility classes (1 << TerrainTable.FOOT etc.) the footprint blocks.
var blocks_mask: int = 0
## Cover permille for infantry inside the footprint (trench), or hull-down for vehicles.
var cover: int = 0
var smoke_charges: int = 0
var weapons: PackedInt32Array = PackedInt32Array()
var abilities: PackedStringArray = PackedStringArray()


func is_vehicle() -> bool:
	return not is_infantry and not is_structure


func has_ability(a: String) -> bool:
	return abilities.has(a)


func has_crew(slot: int) -> bool:
	return (crew_slots & slot) != 0


func crew_count() -> int:
	var n: int = 0
	for b: int in [CREW_DRIVER, CREW_GUNNER, CREW_COMMANDER, CREW_LOADER]:
		if (crew_slots & b) != 0:
			n += 1
	return n

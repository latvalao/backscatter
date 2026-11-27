## Loads data/weapons/*.json and data/units/*.json into a DefDb, converting
## human-friendly units (m, km/h, deg/s, seconds) into integer sim units.
## Runs once before the sim starts; nothing float-valued reaches sim state.
class_name DefLoader
extends RefCounted

const WEAPON_DIR: String = "res://data/weapons"
const UNIT_DIR: String = "res://data/units"
const BUILDING_DIR: String = "res://data/buildings"
const RULES_DIR: String = "res://data/rules"

static var _cached: DefDb = null


## Shared, cached DefDb (defs are immutable).
static func load_default() -> DefDb:
	if _cached == null:
		_cached = load_dirs(WEAPON_DIR, UNIT_DIR)
		for entry: Dictionary in _read_entries(BUILDING_DIR):
			_cached.add_unit(_structure(entry))
		for f: String in DirAccess.get_files_at(RULES_DIR):
			if f.ends_with(".json"):
				var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_DIR.path_join(f)))
				if typeof(d) == TYPE_DICTIONARY:
					var rules: Dictionary = d
					for k: String in rules.keys():
						_cached.rules[k] = roundi(float(rules[k]))
	return _cached


static func load_dirs(weapon_dir: String, unit_dir: String) -> DefDb:
	var db: DefDb = DefDb.new()
	for entry: Dictionary in _read_entries(weapon_dir):
		db.add_weapon(_weapon(entry))
	for entry: Dictionary in _read_entries(unit_dir):
		db.add_unit(_unit(entry, db))
	return db


static func _read_entries(dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var text: String = FileAccess.get_file_as_string(dir.path_join(f))
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_ARRAY:
			push_error("DefLoader: %s must be a JSON array" % f)
			continue
		var arr: Array = parsed
		for e: Variant in arr:
			if typeof(e) == TYPE_DICTIONARY:
				out.append(e as Dictionary)
	return out


static func _i(d: Dictionary, key: String, default_value: int = 0) -> int:
	if not d.has(key):
		return default_value
	return roundi(float(d[key]))


## value * scale, rounded (e.g. metres -> mm).
static func _scaled(d: Dictionary, key: String, scale: int, default_value: int = 0) -> int:
	if not d.has(key):
		return default_value
	return roundi(float(d[key]) * scale)


static func _kmh_to_mm_tick(kmh: float) -> int:
	return roundi(kmh * 1000000.0 / 3600.0 / SimConst.TICKS_PER_SECOND)


static func _weapon(d: Dictionary) -> WeaponStats:
	var w: WeaponStats = WeaponStats.new()
	w.id = d["id"]
	w.type = ["direct", "indirect", "atgm"].find(String(d.get("type", "direct")))
	w.guidance = ["none", "fire_forget", "wire"].find(String(d.get("guidance", "none")))
	assert(w.type >= 0 and w.guidance >= 0, "bad weapon type/guidance in " + w.id)
	w.range_min_mm = _scaled(d, "range_min_m", 1000)
	w.range_max_mm = _scaled(d, "range_max_m", 1000)
	w.penetration = _i(d, "penetration")
	w.damage = _i(d, "damage")
	w.inf_damage = _i(d, "inf_damage")
	w.blast_radius_mm = _scaled(d, "blast_radius_m", 1000)
	w.suppression = _i(d, "suppression")
	w.reload_ticks = maxi(1, _scaled(d, "reload_s", SimConst.TICKS_PER_SECOND, 1))
	w.aim_ticks = _scaled(d, "aim_s", SimConst.TICKS_PER_SECOND)
	w.ammo_capacity = _i(d, "ammo_capacity", 1)
	w.ammo_per_shot = _i(d, "ammo_per_shot", 1)
	w.burst = maxi(1, _i(d, "burst", 1))
	w.accuracy_near = _i(d, "accuracy_near", 500)
	w.accuracy_far = _i(d, "accuracy_far", 100)
	# m/s -> mm/tick
	w.projectile_speed = _scaled(d, "projectile_speed_ms", 1000 / SimConst.TICKS_PER_SECOND)
	w.dispersion_per_km_mm = _scaled(d, "dispersion_m_per_km", 1000)
	w.smoke = bool(d.get("smoke", false))
	w.anti_air = bool(d.get("air", false))
	return w


static func _unit(d: Dictionary, db: DefDb) -> UnitStats:
	var u: UnitStats = UnitStats.new()
	u.id = d["id"]
	u.faction = d.get("faction", "")
	u.display_name = d.get("name", u.id)
	u.role = d.get("role", "")
	u.cost_supply = _i(d, "sup")
	u.cost_manpower = _i(d, "mp")
	u.build_time_ticks = _scaled(d, "build_s", SimConst.TICKS_PER_SECOND)
	u.mobility_class = TerrainTable.MOBILITY_NAMES.find(String(d.get("mobility", "foot")))
	assert(u.mobility_class >= 0, "bad mobility in " + u.id)
	var speed_kmh: float = float(d.get("speed_kmh", 5.0))
	u.max_speed = _kmh_to_mm_tick(speed_kmh)
	var accel_s: float = maxf(0.1, float(d.get("accel_s", 1.0)))
	u.accel = maxi(1, roundi(u.max_speed / (accel_s * SimConst.TICKS_PER_SECOND)))
	u.turn_rate = maxi(1, roundi(float(d.get("turn_deg_s", 90.0)) * SimConst.ANGLE_FULL / 360.0 / SimConst.TICKS_PER_SECOND))
	u.radius_mm = _scaled(d, "radius_m", 1000, 2000)
	u.stabilized = bool(d.get("stabilized", false))
	u.is_infantry = u.mobility_class == TerrainTable.FOOT
	u.members = _i(d, "members", 1)
	u.hp = _i(d, "hp", 100)
	var armour: Dictionary = d.get("armour", {})
	u.armour_front = _i(armour, "front")
	u.armour_side = _i(armour, "side")
	u.armour_rear = _i(armour, "rear")
	u.armour_top = _i(armour, "top")
	u.protection_factor = maxi(1, _i(d, "pf", 1))
	u.nbc = bool(d.get("nbc", false))
	u.crew_slots = 0
	var crew: Array = d.get("crew", [])
	for c: Variant in crew:
		var slot: int = ["driver", "gunner", "commander", "loader"].find(String(c))
		assert(slot >= 0, "bad crew slot in " + u.id)
		u.crew_slots |= 1 << slot
	u.passenger_capacity = _i(d, "passengers")
	var vision: Dictionary = d.get("vision", {})
	u.vision_day_mm = _scaled(vision, "day_m", 1000, 1000000)
	u.vision_night_mm = _scaled(vision, "night_m", 1000, u.vision_day_mm / 5)
	u.vision_thermal_mm = _scaled(vision, "thermal_m", 1000, 0)
	u.visibility = _i(d, "visibility", 1000)
	u.size_class = ["infantry", "small", "large"].find(String(d.get("size", "infantry")))
	assert(u.size_class >= 0, "bad size in " + u.id)
	u.eye_height_mm = _scaled(d, "eye_height_m", 1000, 1700 if u.is_infantry else 2600)
	u.target_height_mm = _scaled(d, "target_height_m", 1000, 1000 if u.is_infantry else 2300)
	u.morale = _i(d, "morale", 700)
	u.smoke_charges = _i(d, "smoke_charges")
	var weapon_ids: Array = d.get("weapons", [])
	for wid: Variant in weapon_ids:
		var wi: int = db.weapon_index(String(wid))
		assert(wi >= 0, "unknown weapon %s in %s" % [wid, u.id])
		u.weapons.append(wi)
	var abilities: Array = d.get("abilities", [])
	for a: Variant in abilities:
		u.abilities.append(String(a))
	u.built_at = d.get("built_at", "")
	u.fuel_capacity = _scaled(d, "fuel_l", 1000)
	u.fuel_per_km = _scaled(d, "fuel_per_km_l", 1000)
	u.cargo_capacity = _i(d, "cargo")
	u.is_air = u.mobility_class == TerrainTable.AIR
	u.is_infantry = u.mobility_class == TerrainTable.FOOT
	u.altitude_mm = _scaled(d, "altitude_m", 1000)
	u.battery_ticks = _scaled(d, "battery_s", SimConst.TICKS_PER_SECOND)
	if u.is_air:
		u.eye_height_mm = u.altitude_mm
		u.target_height_mm = u.altitude_mm
		u.fuel_capacity = 0
	_emitter(u, d)
	return u


static func _emitter(u: UnitStats, d: Dictionary) -> void:
	var e: Dictionary = d.get("emitter", {})
	if not e.is_empty():
		u.emitter_kind = UnitStats.EMIT_NAMES.find(String(e.get("kind", "none")))
		assert(u.emitter_kind >= 0, "bad emitter in " + u.id)
		u.emitter_strength = _i(e, "strength")
	u.df_quality = _i(d, "df")
	u.jam_radius_mm = _scaled(d, "jam_radius_m", 1000)


## Structures reuse UnitStats with is_structure set (no mobility, no crew).
static func _structure(d: Dictionary) -> UnitStats:
	var u: UnitStats = UnitStats.new()
	u.id = d["id"]
	u.is_structure = true
	u.faction = d.get("faction", "any")
	u.display_name = d.get("name", u.id)
	u.role = d.get("role", "")
	u.built_at = d.get("built_at", "none")
	u.cost_supply = _i(d, "sup")
	u.cost_manpower = _i(d, "mp")
	u.build_time_ticks = _scaled(d, "build_s", SimConst.TICKS_PER_SECOND)
	var fp: Array = d.get("footprint", [1, 1])
	u.footprint_w = roundi(float(fp[0]))
	u.footprint_h = roundi(float(fp[1]))
	var blocks: Array = d.get("blocks", [])
	for b: Variant in blocks:
		var mob: int = TerrainTable.MOBILITY_NAMES.find(String(b))
		assert(mob >= 0, "bad blocks entry in " + u.id)
		u.blocks_mask |= 1 << mob
	u.cover = _i(d, "cover")
	u.hp = _i(d, "hp", 1000)
	var armour: Dictionary = d.get("armour", {})
	u.armour_front = _i(armour, "front")
	u.armour_side = _i(armour, "side")
	u.armour_rear = _i(armour, "rear")
	u.armour_top = _i(armour, "top")
	u.protection_factor = maxi(1, _i(d, "pf", 1))
	var vision: Dictionary = d.get("vision", {})
	u.vision_day_mm = _scaled(vision, "day_m", 1000, 0)
	u.vision_night_mm = _scaled(vision, "night_m", 1000, u.vision_day_mm / 2)
	u.visibility = _i(d, "visibility", 1500)
	u.size_class = ["infantry", "small", "large"].find(String(d.get("size", "large")))
	u.radius_mm = maxi(u.footprint_w, u.footprint_h) * SimGrid.CELL_MM / 2
	u.eye_height_mm = 4000
	u.target_height_mm = 3000
	u.morale = 1000
	u.members = 1
	u.mobility_class = TerrainTable.TRACKED
	_emitter(u, d)
	return u

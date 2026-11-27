# SIM: deterministic — no floats, no Nodes
## All definitions for a match. Built once by content/def_loader.gd, then read-only.
class_name DefDb
extends RefCounted

var units: Array[UnitStats] = []
## Integer economy/rules tunables from data/rules/*.json.
var rules: Dictionary = {}  # String -> int (lookup only)
var weapons: Array[WeaponStats] = []
var _unit_index: Dictionary = {}    # String -> int (lookup only)
var _weapon_index: Dictionary = {}


func add_weapon(w: WeaponStats) -> void:
	w.index = weapons.size()
	weapons.append(w)
	_weapon_index[w.id] = w.index


func add_unit(u: UnitStats) -> void:
	u.index = units.size()
	units.append(u)
	_unit_index[u.id] = u.index


func unit_index(id: String) -> int:
	return _unit_index.get(id, -1)


func weapon_index(id: String) -> int:
	return _weapon_index.get(id, -1)


func rule(name: String) -> int:
	assert(rules.has(name), "missing rule " + name)
	return rules[name]


## Unit defs a building role can produce for a faction, in data order.
func producible(building_role: String, faction: String) -> Array[UnitStats]:
	var out: Array[UnitStats] = []
	for u: UnitStats in units:
		if not u.is_structure and u.built_at == building_role and u.faction == faction:
			out.append(u)
	return out


## Structures an engineer (or infantry, for "infantry") can build.
func buildable(builder: String) -> Array[UnitStats]:
	var out: Array[UnitStats] = []
	for u: UnitStats in units:
		if u.is_structure and u.built_at == builder:
			out.append(u)
	return out


func unit(id: String) -> UnitStats:
	return units[_unit_index[id]]


func weapon(id: String) -> WeaponStats:
	return weapons[_weapon_index[id]]

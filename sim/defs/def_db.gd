# SIM: deterministic — no floats, no Nodes
## All definitions for a match. Built once by content/def_loader.gd, then read-only.
class_name DefDb
extends RefCounted

var units: Array[UnitStats] = []
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


func unit(id: String) -> UnitStats:
	return units[_unit_index[id]]


func weapon(id: String) -> WeaponStats:
	return weapons[_weapon_index[id]]

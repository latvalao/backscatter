# SIM: deterministic — no floats, no Nodes
## Per-weapon-slot state, flat [id * MAX_WEAPONS + slot].
class_name WeaponStore
extends ComponentStore

const MAX_WEAPONS: int = 3

var ammo: PackedInt32Array = PackedInt32Array()
var reload: PackedInt32Array = PackedInt32Array()
var aim: PackedInt32Array = PackedInt32Array()
var target: PackedInt32Array = PackedInt32Array()


func add(id: int, def: UnitStats, db: DefDb) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	for s: int in range(MAX_WEAPONS):
		var k: int = id * MAX_WEAPONS + s
		ammo[k] = 0
		reload[k] = 0
		aim[k] = 0
		target[k] = 0
		if s < def.weapons.size():
			var w: WeaponStats = db.weapons[def.weapons[s]]
			ammo[k] = w.ammo_capacity
			aim[k] = w.aim_ticks


func _resize_columns(n: int) -> void:
	ammo.resize(n * MAX_WEAPONS)
	reload.resize(n * MAX_WEAPONS)
	aim.resize(n * MAX_WEAPONS)
	target.resize(n * MAX_WEAPONS)


func hash_entity(id: int, h: Checksum) -> void:
	for s: int in range(MAX_WEAPONS):
		var k: int = id * MAX_WEAPONS + s
		h.add_int(ammo[k])
		h.add_int(reload[k])
		h.add_int(aim[k])
		h.add_int(target[k])

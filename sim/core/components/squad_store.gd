# SIM: deterministic — no floats, no Nodes
## Individual soldier HP for infantry squads, flat [id * MAX_MEMBERS + m]. 0 = dead.
class_name SquadStore
extends ComponentStore

const MAX_MEMBERS: int = 12

var member_hp: PackedInt32Array = PackedInt32Array()


func add(id: int, def: UnitStats) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	for m: int in range(MAX_MEMBERS):
		member_hp[id * MAX_MEMBERS + m] = def.hp if m < def.members else 0


func _resize_columns(n: int) -> void:
	member_hp.resize(n * MAX_MEMBERS)


func hash_entity(id: int, h: Checksum) -> void:
	for m: int in range(MAX_MEMBERS):
		h.add_int(member_hp[id * MAX_MEMBERS + m])

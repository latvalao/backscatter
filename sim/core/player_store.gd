# SIM: deterministic — no floats, no Nodes
## Per-player economy and status (§5.1). Indexed by player id.
class_name PlayerStore
extends RefCounted

var team: PackedInt32Array = PackedInt32Array()
## Faction id string per player ("nc", "ec").
var faction: PackedStringArray = PackedStringArray()
var supply: PackedInt32Array = PackedInt32Array()
var manpower: PackedInt32Array = PackedInt32Array()
var defeated: PackedByteArray = PackedByteArray()
## True for AI-controlled players (their commands come from sim-side AI).
var is_ai: PackedByteArray = PackedByteArray()


func add(p_team: int, p_faction: String, p_supply: int, p_manpower: int, ai: bool) -> int:
	team.append(p_team)
	faction.append(p_faction)
	supply.append(p_supply)
	manpower.append(p_manpower)
	defeated.append(0)
	is_ai.append(1 if ai else 0)
	return team.size() - 1


func count() -> int:
	return team.size()


func can_afford(p: int, sup: int, mp: int) -> bool:
	return supply[p] >= sup and manpower[p] >= mp


func spend(p: int, sup: int, mp: int) -> void:
	supply[p] -= sup
	manpower[p] -= mp


func refund(p: int, sup: int, mp: int) -> void:
	supply[p] += sup
	manpower[p] += mp


func hash_into(h: Checksum) -> void:
	for p: int in range(team.size()):
		h.add_int(team[p])
		h.add_int(supply[p])
		h.add_int(manpower[p])
		h.add_int(defeated[p])

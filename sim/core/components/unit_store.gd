# SIM: deterministic — no floats, no Nodes
## Per-unit identity and condition.
class_name UnitStore
extends ComponentStore

const DMG_ENGINE: int = 1
const DMG_TRACKS: int = 2
const DMG_TURRET: int = 4
const DMG_OPTICS: int = 8

const EMCON_EMIT: int = 0
const EMCON_RESTRICTED: int = 1
const EMCON_SILENT: int = 2
const EMCON_NAMES: Array[String] = ["EMIT", "RESTRICTED", "SILENT"]

const STANCE_FIRE_AT_WILL: int = 0
const STANCE_HOLD_FIRE: int = 1

var def_index: PackedInt32Array = PackedInt32Array()
var team: PackedInt32Array = PackedInt32Array()
var owner: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
## Bitmask of crew slots still alive (UnitStats.CREW_*).
var crew: PackedInt32Array = PackedInt32Array()
## Bitmask of damaged components (DMG_*).
var damage: PackedInt32Array = PackedInt32Array()
## 0..1000 (design doc's 0–100 in tenths).
var suppression: PackedInt32Array = PackedInt32Array()
var morale: PackedInt32Array = PackedInt32Array()
var members_alive: PackedInt32Array = PackedInt32Array()
var smoke_charges: PackedInt32Array = PackedInt32Array()
var stance: PackedInt32Array = PackedInt32Array()
var last_fired_tick: PackedInt32Array = PackedInt32Array()
var last_hit_tick: PackedInt32Array = PackedInt32Array()
var last_attacker: PackedInt32Array = PackedInt32Array()
var kills: PackedInt32Array = PackedInt32Array()
var emcon: PackedInt32Array = PackedInt32Array()
## Drones: operator entity id. 0 = none.
var link: PackedInt32Array = PackedInt32Array()
## Drones: ticks the control link has been down.
var link_lost: PackedInt32Array = PackedInt32Array()


func add(id: int, def: UnitStats, p_team: int, p_owner: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	def_index[id] = def.index
	team[id] = p_team
	owner[id] = p_owner
	hp[id] = def.hp
	crew[id] = def.crew_slots
	damage[id] = 0
	suppression[id] = 0
	morale[id] = def.morale
	members_alive[id] = def.members
	smoke_charges[id] = def.smoke_charges
	stance[id] = STANCE_FIRE_AT_WILL
	last_fired_tick[id] = -1000
	last_hit_tick[id] = -1000
	last_attacker[id] = 0
	kills[id] = 0
	emcon[id] = EMCON_EMIT
	link[id] = 0
	link_lost[id] = 0


func _resize_columns(n: int) -> void:
	def_index.resize(n)
	team.resize(n)
	owner.resize(n)
	hp.resize(n)
	crew.resize(n)
	damage.resize(n)
	suppression.resize(n)
	morale.resize(n)
	members_alive.resize(n)
	smoke_charges.resize(n)
	stance.resize(n)
	last_fired_tick.resize(n)
	last_hit_tick.resize(n)
	last_attacker.resize(n)
	kills.resize(n)
	emcon.resize(n)
	link.resize(n)
	link_lost.resize(n)


func _cols() -> Array[PackedInt32Array]:
	return [def_index, team, owner, hp, crew, damage, suppression, morale, members_alive,
		smoke_charges, stance, last_fired_tick, last_hit_tick, last_attacker, kills, emcon, link, link_lost]


func hash_entity(id: int, h: Checksum) -> void:
	for col: PackedInt32Array in _cols():
		h.add_int(col[id])

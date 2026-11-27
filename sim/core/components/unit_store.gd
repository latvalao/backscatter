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
## Transport carrying this unit (0 = on foot). Carried units are out of play:
## not in team rosters, not spotted, not targetable, do not fire.
var carrier: PackedInt32Array = PackedInt32Array()
## Engagement range limit in mm (0 = weapon maximum).
var engage_range: PackedInt32Array = PackedInt32Array()
## Experience points and veterancy rank (0 Trained, 1 Veteran, 2 Elite).
var xp: PackedInt32Array = PackedInt32Array()
var rank: PackedInt32Array = PackedInt32Array()
## Morale broke: retreats and ignores orders until this tick.
var rout_until: PackedInt32Array = PackedInt32Array()
## Ticks spent stationary (infantry dig in / garrison after a while).
var still_ticks: PackedInt32Array = PackedInt32Array()
## Engineer task (TASK_*) and its argument (wreck entity id / packed point).
var task: PackedInt32Array = PackedInt32Array()
var task_x: PackedInt64Array = PackedInt64Array()
var task_y: PackedInt64Array = PackedInt64Array()
var task_arg: PackedInt32Array = PackedInt32Array()
## Last tick this unit made a radio call (off-map support): a DF-visible burst.
var tx_tick: PackedInt32Array = PackedInt32Array()
## Smart order flags (SMART_*), overwatch sector centre (binary angle, -1 none)
## and the position a unit returns to after a crew rotation.
var smart: PackedInt32Array = PackedInt32Array()
var overwatch_dir: PackedInt32Array = PackedInt32Array()
var home_x: PackedInt64Array = PackedInt64Array()
var home_y: PackedInt64Array = PackedInt64Array()

const SMART_AUTO_CB: int = 1
const SMART_ROTATE: int = 2
## Set while a unit is away being treated / decontaminated.
const SMART_ROTATING: int = 4

const TASK_NONE: int = 0
const TASK_SALVAGE: int = 1
const TASK_LAY_MINES: int = 2


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
	carrier[id] = 0
	engage_range[id] = 0
	xp[id] = 0
	rank[id] = 0
	rout_until[id] = 0
	still_ticks[id] = 0
	task[id] = 0
	task_x[id] = 0
	task_y[id] = 0
	task_arg[id] = 0
	tx_tick[id] = -1000
	smart[id] = 0
	overwatch_dir[id] = -1
	home_x[id] = 0
	home_y[id] = 0


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
	carrier.resize(n)
	engage_range.resize(n)
	xp.resize(n)
	rank.resize(n)
	rout_until.resize(n)
	still_ticks.resize(n)
	task.resize(n)
	task_x.resize(n)
	task_y.resize(n)
	task_arg.resize(n)
	tx_tick.resize(n)
	smart.resize(n)
	overwatch_dir.resize(n)
	home_x.resize(n)
	home_y.resize(n)


func _cols() -> Array[PackedInt32Array]:
	return [def_index, team, owner, hp, crew, damage, suppression, morale, members_alive,
		smoke_charges, stance, last_fired_tick, last_hit_tick, last_attacker, kills, emcon, link, link_lost,
		carrier, engage_range, xp, rank, rout_until, still_ticks, task, task_arg, tx_tick, smart, overwatch_dir]


func hash_entity(id: int, h: Checksum) -> void:
	for col: PackedInt32Array in _cols():
		h.add_int(col[id])
	h.add_int(task_x[id])
	h.add_int(task_y[id])
	h.add_int(home_x[id])
	h.add_int(home_y[id])

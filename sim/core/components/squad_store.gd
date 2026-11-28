# SIM: deterministic — no floats, no Nodes
## Individual soldiers of infantry squads, flat [id * MAX_MEMBERS + m].
## The squad entity stays the unit you command (path, orders, targeting);
## each soldier has his own position, facing, posture, cover, role and state,
## moved by SoldierSystem. hp 0 = dead.
class_name SquadStore
extends ComponentStore

const MAX_MEMBERS: int = 12

const ROLE_RIFLE: int = 0
const ROLE_LEADER: int = 1
const ROLE_GUNNER: int = 2
const ROLE_AT: int = 3
const ROLE_MEDIC: int = 4

const STATE_OK: int = 0
## Badly wounded: can't fight or walk, bleeds out unless a buddy treats him.
const STATE_DOWN: int = 1

const STAND: int = 0
const CROUCH: int = 1
const PRONE: int = 2

const TASK_NONE: int = 0
## Moving to a downed buddy, then dragging him (task_arg = his member index).
const TASK_DRAG: int = 1
## Patching up a downed buddy in cover (task_arg = his member index).
const TASK_TREAT: int = 2

var member_hp: PackedInt32Array = PackedInt32Array()
var mx: PackedInt64Array = PackedInt64Array()
var my: PackedInt64Array = PackedInt64Array()
var tx: PackedInt64Array = PackedInt64Array()
var ty: PackedInt64Array = PackedInt64Array()
var heading: PackedInt32Array = PackedInt32Array()
var posture: PackedByteArray = PackedByteArray()
var state: PackedByteArray = PackedByteArray()
var role: PackedByteArray = PackedByteArray()
var cover: PackedInt32Array = PackedInt32Array()
var task: PackedByteArray = PackedByteArray()
var task_arg: PackedInt32Array = PackedInt32Array()
var timer: PackedInt32Array = PackedInt32Array()
## Last tick this soldier fired (presentation: recoil / muzzle flash).
var fired: PackedInt32Array = PackedInt32Array()
## Per squad: soldiers have been placed in the world.
var placed: PackedByteArray = PackedByteArray()


func add(id: int, def: UnitStats) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	placed[id] = 0
	for m: int in range(MAX_MEMBERS):
		var k: int = id * MAX_MEMBERS + m
		member_hp[k] = def.hp if m < def.members else 0
		mx[k] = 0
		my[k] = 0
		tx[k] = 0
		ty[k] = 0
		heading[k] = 0
		posture[k] = STAND
		state[k] = STATE_OK
		role[k] = role_for(def, m)
		cover[k] = 0
		task[k] = TASK_NONE
		task_arg[k] = 0
		timer[k] = 0
		fired[k] = -1000


## Leader first; the support weapon (MG, launcher, mortar) second; a medic in
## squads of six or more; a second gunner in squads of eight or more.
static func role_for(def: UnitStats, m: int) -> int:
	if m == 0:
		return ROLE_LEADER if def.members > 2 else ROLE_RIFLE
	if m == 1 or (m == 5 and def.members >= 8):
		return ROLE_AT if def.role == "at_infantry" else ROLE_GUNNER
	if m == 3 and def.members >= 6:
		return ROLE_MEDIC
	return ROLE_RIFLE


func alive(id: int, m: int) -> bool:
	return member_hp[id * MAX_MEMBERS + m] > 0


## Soldiers able to fight right now: alive, not down, not busy with a casualty.
func firers(id: int) -> int:
	var n: int = 0
	for m: int in range(MAX_MEMBERS):
		var k: int = id * MAX_MEMBERS + m
		if member_hp[k] > 0 and state[k] == STATE_OK and task[k] == TASK_NONE:
			n += 1
	return n


## Marks `count` able soldiers as firing this tick, rotating through the squad
## so everyone takes turns (drives recoil and muzzle flashes in presentation).
func mark_fired(id: int, tick: int, count: int) -> void:
	var start: int = tick % MAX_MEMBERS
	for i: int in range(MAX_MEMBERS):
		if count <= 0:
			return
		var k: int = id * MAX_MEMBERS + (start + i) % MAX_MEMBERS
		if member_hp[k] > 0 and state[k] == STATE_OK and task[k] == TASK_NONE:
			fired[k] = tick
			count -= 1


func _resize_columns(n: int) -> void:
	var c: int = n * MAX_MEMBERS
	member_hp.resize(c)
	mx.resize(c)
	my.resize(c)
	tx.resize(c)
	ty.resize(c)
	heading.resize(c)
	posture.resize(c)
	state.resize(c)
	role.resize(c)
	cover.resize(c)
	task.resize(c)
	task_arg.resize(c)
	timer.resize(c)
	fired.resize(c)
	placed.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(placed[id])
	for m: int in range(MAX_MEMBERS):
		var k: int = id * MAX_MEMBERS + m
		h.add_int(member_hp[k])
		h.add_int(mx[k])
		h.add_int(my[k])
		h.add_int(posture[k] + state[k] * 4 + task[k] * 16 + role[k] * 64)
		h.add_int(task_arg[k])
		h.add_int(timer[k])

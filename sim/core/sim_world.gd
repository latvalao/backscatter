# SIM: deterministic — no floats, no Nodes
## Root of all simulation state. Pure data + a fixed system order.
##
## Tick order (design doc §7.5). Phases without a system yet are reserved:
##   1. Apply commands (sorted by player id, then sequence)
##   2. AI planning                      -> DebugWanderSystem (M0 placeholder)
##   3. Orders -> movement               -> MovementSystem
##   4. Vision & spotting                (M2)
##   5. Signature / DF / jamming         (M6)
##   6. Weapons                          (M2)
##   7. Damage, suppression, morale      (M2)
##   8. Radiation                        (M5)
##   9. Logistics / production           (M4)
##  10. Veterancy, cleanup, events       -> _cleanup()
##  11. Checksum every CHECKSUM_INTERVAL ticks
class_name SimWorld
extends RefCounted

var tick: int = 0
var match_seed: int = 0
var rng: SimRng
var entities: EntityStore = EntityStore.new()
var commands: CommandQueue = CommandQueue.new()

var transform: TransformStore = TransformStore.new()
var motion: MotionStore = MotionStore.new()
var team: PackedInt32Array = PackedInt32Array()

var map_width_mm: int = 4000 * SimConst.MM_PER_M
var map_height_mm: int = 4000 * SimConst.MM_PER_M

## Events produced since the last drain_events(); presentation drains them each frame.
var events: Array[SimEvent] = []
## Most recent periodic checksum and the tick it was taken on (-1 = none yet).
var last_checksum: int = 0
var last_checksum_tick: int = -1

var _systems: Array[SimSystem] = []
var _pending_destroy: PackedInt32Array = PackedInt32Array()


func _init(p_seed: int = 0) -> void:
	match_seed = p_seed
	rng = SimRng.new(p_seed)
	_systems.append(DebugWanderSystem.new())  # phase 2
	_systems.append(MovementSystem.new())     # phase 3


## Fixed component store order — part of the checksum definition.
func component_stores() -> Array[ComponentStore]:
	var out: Array[ComponentStore] = [transform, motion]
	return out


func in_bounds(x_mm: int, y_mm: int) -> bool:
	return x_mm >= 0 and y_mm >= 0 and x_mm <= map_width_mm and y_mm <= map_height_mm


## Schedules a command. Commands for past ticks are rejected.
func queue_command(cmd: SimCommand) -> bool:
	if cmd.tick < tick:
		return false
	commands.push(cmd)
	return true


## Advance the simulation by exactly one tick.
func step() -> void:
	# 1. commands
	for cmd: SimCommand in commands.take(tick):
		if cmd.validate(self):
			cmd.apply(self)
	# 2..9 systems
	for system: SimSystem in _systems:
		system.step(self, tick)
	# 10. cleanup
	_cleanup()
	# 11. checksum
	if tick % SimConst.CHECKSUM_INTERVAL == 0:
		last_checksum = Checksum.compute(self)
		last_checksum_tick = tick
	tick += 1


## Returns and clears pending events.
func drain_events() -> Array[SimEvent]:
	var out: Array[SimEvent] = events
	var fresh: Array[SimEvent] = []
	events = fresh
	return out


func spawn_debug_unit(x_mm: int, y_mm: int, p_team: int, speed_cap: int, wander_period: int) -> int:
	var id: int = entities.create()
	if team.size() < entities.capacity():
		team.resize(entities.capacity())
	team[id] = p_team
	transform.add(id, x_mm, y_mm, 0, 0)
	motion.add(id, speed_cap, wander_period)
	events.append(SimEvent.new(SimEvent.Type.SPAWNED, id, tick))
	return id


## Marks an entity for removal at the end of this tick (phase 10).
func destroy_entity(id: int) -> void:
	if entities.is_alive(id):
		_pending_destroy.append(id)


func _cleanup() -> void:
	if _pending_destroy.is_empty():
		return
	_pending_destroy.sort()
	for id: int in _pending_destroy:
		if not entities.is_alive(id):
			continue
		for store: ComponentStore in component_stores():
			store.remove(id)
		entities.destroy(id)
		events.append(SimEvent.new(SimEvent.Type.DESTROYED, id, tick))
	_pending_destroy.clear()

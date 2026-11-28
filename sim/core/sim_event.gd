# SIM: deterministic — no floats, no Nodes
## Sim -> presentation notification. Presentation drains world.events each frame.
## Never read back by the sim.
class_name SimEvent
extends RefCounted

enum Type {
	SPAWNED,
	DESTROYED,
	SHOT,            # entity = shooter, other = target, value = weapon index, x/y = aim point
	IMPACT,          # other = shooter, value = weapon index, x/y = impact point
	PENETRATED,      # entity = target, other = shooter, value = face
	BOUNCED,         # entity = target, other = shooter, value = face
	SOLDIER_KILLED,  # entity = squad, other = shooter, value = members left, x = soldier index
	SMOKE,           # x/y = cloud centre, value = radius
	MISSED,          # entity = shooter, other = target, value = weapon index, x/y = miss point
	BUILT,           # entity = structure, value = def index
	PRODUCED,        # entity = new unit, other = building, value = def index
	CAPTURED,        # entity = depot, other = player, value = team
	DEFEATED,        # other = player, value = team
	VICTORY,         # value = winning team
	OUT_OF_FUEL,     # entity = unit
	RADIATION_CASUALTY,  # entity = unit that lost a soldier / crewman to ARS
	SIGNAL_FIX,      # entity = emitter, other = team that fixed it, value = radius mm, x/y = estimate
	JAMMED,          # entity = unit whose link was jammed
	DRONE_LOST,      # entity = drone
	MOUNTED,         # entity = passenger, other = carrier
	DISMOUNTED,      # entity = passenger
	PROMOTED,        # entity = unit, value = new rank
	ROUTED,          # entity = unit (morale broke)
	MINE,            # entity = victim (0 if none), x/y = mine position
	ALERT,           # entity = subject, value = alert code (1 = crew recovered), x/y = place
	SALVAGED,        # entity = wreck's old id, other = engineer, value = supply, x/y = place
	FLARE,           # x/y = flare position, other = firing unit
	SUPPORT_CALLED,  # entity = caller, other = player, value = kind, x/y = target
	MISSION,         # other = 0 message / 1 objective added / 2 done / 3 failed, value = index
	SOLDIER_DOWN,    # entity = squad, other = shooter, value = soldier index (badly wounded)
}

var kind: Type
var entity_id: int
var other_id: int
var value: int
var x: int
var y: int
var tick: int


func _init(p_type: Type = Type.SPAWNED, p_entity_id: int = 0, p_tick: int = 0) -> void:
	kind = p_type
	entity_id = p_entity_id
	tick = p_tick

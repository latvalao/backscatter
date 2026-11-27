# SIM: deterministic — no floats, no Nodes
## Sim -> presentation notification. Presentation drains world.events after each tick.
class_name SimEvent
extends RefCounted

enum Type { SPAWNED, DESTROYED }

var kind: Type
var entity_id: int
var tick: int


func _init(p_type: Type = Type.SPAWNED, p_entity_id: int = 0, p_tick: int = 0) -> void:
	kind = p_type
	entity_id = p_entity_id
	tick = p_tick

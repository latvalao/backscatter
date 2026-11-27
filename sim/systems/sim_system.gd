# SIM: deterministic — no floats, no Nodes
## Base class for sim systems. One system per file.
class_name SimSystem
extends RefCounted


func step(_world: SimWorld, _tick: int) -> void:
	pass

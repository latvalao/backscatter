# SIM: deterministic — no floats, no Nodes
## A group of AI units with one operational goal (§6 task force AI).
class_name TaskForce
extends RefCounted

const CAPTURE: int = 0
const DEFEND: int = 1
const ATTACK: int = 2
const RECON: int = 3
const ARTILLERY: int = 4
const NAMES: Array[String] = ["capture", "defend", "attack", "recon", "artillery"]

var id: int = 0
var kind: int = CAPTURE
var units: PackedInt32Array = PackedInt32Array()
var goal_x: int = 0
var goal_y: int = 0
## Objective entity (depot to capture, HQ to attack); 0 if a map point.
var target: int = 0
var last_order_tick: int = -100000
var start_size: int = 0
var last_regroup_tick: int = -100000


func prune(world: SimWorld) -> void:
	var keep: PackedInt32Array = PackedInt32Array()
	for u: int in units:
		if world.is_unit(u):
			keep.append(u)
	units = keep


func centroid(world: SimWorld) -> Vector2i:
	if units.is_empty():
		return Vector2i(goal_x, goal_y)
	var sx: int = 0
	var sy: int = 0
	for u: int in units:
		sx += world.transform.x[u]
		sy += world.transform.y[u]
	return Vector2i(sx / units.size(), sy / units.size())

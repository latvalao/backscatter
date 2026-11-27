## Placeholder unit visual: a team-coloured box that follows interpolated sim state.
class_name UnitView
extends Node3D

const TEAM_COLORS: Array[Color] = [Color(0.30, 0.45, 0.30), Color(0.55, 0.25, 0.20)]

var entity_id: int = 0


func setup(id: int, team: int) -> void:
	entity_id = id
	name = "Unit_%d" % id
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(3.5, 2.2, 7.0)
	mesh.mesh = box
	mesh.position.y = 1.1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = TEAM_COLORS[team % TEAM_COLORS.size()]
	mesh.material_override = mat
	add_child(mesh)

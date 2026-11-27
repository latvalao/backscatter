## Renders every forged model in a lineup to a PNG (art review).
##   godot --path . -s res://tools/model_sheet.gd -- --out=/tmp/sheet.png [--filter=nc_]
extends SceneTree

var _out: String = "user://sheet.png"
var _filter: String = ""
var _frame: int = 0
var _zoom: float = 1.0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--zoom="):
			_zoom = a.substr(7).to_float()
		elif a.begins_with("--filter="):
			_filter = a.substr(9)
	var db: DefDb = DefLoader.load_default()
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var x: float = 0.0
	var z: float = 0.0
	var rowmax: float = 0.0
	var count: int = 0
	for u: UnitStats in db.units:
		if _filter != "" and not u.id.begins_with(_filter) and not (_filter == "structures" and u.is_structure):
			continue
		var n: Node3D = ModelLibrary.instantiate(u)
		if n == null:
			continue
		ModelLibrary.dress(n, ModelLibrary.material(ModelLibrary.faction_row(u.faction) if not u.is_structure else 0, ModelLibrary.camo_style(u.faction) if not u.is_structure else 0))
		var span: float = 28.0 if u.is_structure else (6.0 if u.is_infantry else 11.0)
		if x + span > 75.0:
			x = 0.0
			z += rowmax
			rowmax = 0.0
		n.position = Vector3(x + span * 0.5, 0, z + span * 0.5)
		n.rotation.y = PI - 0.7
		if u.is_infantry:
			var b: Node3D = n.get_node_or_null("SoldierB") as Node3D
			if b != null:
				b.position = Vector3(1.4, 0, 0.6)
			var pr: Node3D = n.get_node_or_null("Prop") as Node3D
			if pr != null:
				pr.position = Vector3(-1.5, 0, 0.8)
		if u.is_air:
			n.position.y = 1.0
		world.add_child(n)
		x += span
		rowmax = maxf(rowmax, span)
		count += 1
	var ground: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color("#6B7A4A")
	ground.material_override = gmat
	world.add_child(ground)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 40, 0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#B8C2C4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.68, 0.75)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	world.add_child(env)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 38.0
	var cx: float = 37.5
	var cz: float = (z + rowmax) * 0.5
	var dist: float = maxf(42.0, (z + rowmax) * 1.5) * _zoom
	cam.position = Vector3(cx, dist * 0.62, cz + dist * 0.78)
	world.add_child(cam)
	cam.basis = Basis.looking_at(Vector3(cx, 0, cz) - cam.position)
	print("models: %d" % count)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 8:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved " + _out)
		quit(0)
	return false

## Placeholder unit visual (§0: boxes with team colours until M8).
## Vehicles: hull + turret. Infantry: one figure per surviving soldier.
## Also draws a selection ring and a small status label.
class_name UnitView
extends Node3D

const TEAM_COLORS: Array[Color] = [Color(0.36, 0.46, 0.34), Color(0.52, 0.42, 0.26), Color(0.42, 0.44, 0.52), Color(0.55, 0.55, 0.53)]
const FLAG_COLORS: Array[Color] = [Color(0.25, 0.55, 0.95), Color(0.85, 0.25, 0.2), Color(0.9, 0.8, 0.2), Color(0.85, 0.85, 0.85)]

var entity_id: int = 0
var team: int = 0
var def: UnitStats
var ghost: bool = false

var _ring: MeshInstance3D
var _label: Label3D
var _figures: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _shown_members: int = -1
var _flag_mat: StandardMaterial3D
var _complete: bool = true


func setup(id: int, p_team: int, p_def: UnitStats, p_ghost: bool = false) -> void:
	entity_id = id
	team = p_team
	def = p_def
	ghost = p_ghost
	name = ("Ghost_%d" if ghost else "Unit_%d") % id
	_material = StandardMaterial3D.new()
	_material.albedo_color = TEAM_COLORS[team % TEAM_COLORS.size()]
	if ghost:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color.a = 0.35
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var r: float = def.radius_mm * 0.001
	if def.is_structure:
		_build_structure()
	elif def.is_air:
		var body: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(4.0, 0.4, 1.0) if def.altitude_mm > 200000 else Vector3(1.6, 0.4, 1.6)
		body.mesh = bm
		body.material_override = _material
		add_child(body)
	elif def.is_infantry:
		for m: int in range(def.members):
			var fig: MeshInstance3D = MeshInstance3D.new()
			var cap: CapsuleMesh = CapsuleMesh.new()
			cap.radius = 0.35
			cap.height = 1.8
			fig.mesh = cap
			fig.material_override = _material
			var ang: float = TAU * m / def.members
			var rad: float = r * (0.35 + 0.5 * float(m % 2))
			fig.position = Vector3(cos(ang) * rad, 0.9, sin(ang) * rad)
			add_child(fig)
			_figures.append(fig)
	else:
		var hull: MeshInstance3D = MeshInstance3D.new()
		var hb: BoxMesh = BoxMesh.new()
		var length: float = r * 2.0
		hb.size = Vector3(length * 0.5, 1.6 if def.size_class == UnitStats.SIZE_LARGE else 1.9, length)
		hull.mesh = hb
		hull.position.y = hb.size.y * 0.5
		hull.material_override = _material
		add_child(hull)
		if not def.weapons.is_empty():
			var turret: MeshInstance3D = MeshInstance3D.new()
			var tb: BoxMesh = BoxMesh.new()
			tb.size = Vector3(length * 0.32, 0.8, length * 0.36)
			turret.mesh = tb
			turret.position = Vector3(0, hb.size.y + 0.4, length * 0.05)
			turret.material_override = _material
			add_child(turret)
			var barrel: MeshInstance3D = MeshInstance3D.new()
			var bb: BoxMesh = BoxMesh.new()
			bb.size = Vector3(0.2, 0.2, length * 0.5)
			barrel.mesh = bb
			barrel.position = Vector3(0, hb.size.y + 0.45, -length * 0.35)
			barrel.material_override = _material
			add_child(barrel)
	if ghost:
		return
	_ring = MeshInstance3D.new()
	if def.is_structure:
		r = maxf(def.footprint_w, def.footprint_h) * SimGrid.CELL_MM * 0.0006
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = r + 1.2
	torus.outer_radius = r + 1.8
	_ring.mesh = torus
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.6, 1.0, 0.6)
	_ring.material_override = rmat
	_ring.position.y = 0.3
	_ring.visible = false
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 20
	_label.outline_size = 6
	_label.position.y = 5.0
	_label.visible = false
	add_child(_label)


func _build_structure() -> void:
	var cell: float = SimGrid.CELL_MM * 0.001
	var sx: float = def.footprint_w * cell
	var sz: float = def.footprint_h * cell
	var height: float = 6.0
	match def.role:
		"hq":
			height = 7.5
		"trench", "vehicle_pit":
			height = 0.7
		"tank_trap":
			height = 1.5
		"depot_objective":
			height = 4.0
	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(sx * 0.92, height, sz * 0.92)
	body.mesh = bm
	body.position.y = height * 0.5
	if def.role == "trench" or def.role == "vehicle_pit":
		_material.albedo_color = Color(0.25, 0.22, 0.17)
	body.material_override = _material
	add_child(body)
	if def.role == "hq":
		var mast: MeshInstance3D = MeshInstance3D.new()
		var mm: CylinderMesh = CylinderMesh.new()
		mm.top_radius = 0.15
		mm.bottom_radius = 0.25
		mm.height = 14.0
		mast.mesh = mm
		mast.position = Vector3(sx * 0.3, height + 7.0, 0)
		mast.material_override = _material
		add_child(mast)
	if def.role == "depot_objective":
		var pole: MeshInstance3D = MeshInstance3D.new()
		var pm: CylinderMesh = CylinderMesh.new()
		pm.top_radius = 0.12
		pm.bottom_radius = 0.12
		pm.height = 12.0
		pole.mesh = pm
		pole.position = Vector3(sx * 0.5 + 1.0, 6.0, 0)
		add_child(pole)
		var flag: MeshInstance3D = MeshInstance3D.new()
		var fm: BoxMesh = BoxMesh.new()
		fm.size = Vector3(4.0, 2.5, 0.1)
		flag.mesh = fm
		flag.position = Vector3(sx * 0.5 + 3.0, 10.5, 0)
		_flag_mat = StandardMaterial3D.new()
		_flag_mat.albedo_color = FLAG_COLORS[3]
		_flag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flag.material_override = _flag_mat
		add_child(flag)


func set_selected(on: bool) -> void:
	if _ring != null:
		_ring.visible = on


func refresh(world: SimWorld, show_label: bool) -> void:
	if ghost or not world.units.has(entity_id):
		return
	var u: UnitStore = world.units
	if def.is_structure:
		_refresh_structure(world, show_label)
		return
	if def.is_infantry and _shown_members != u.members_alive[entity_id]:
		_shown_members = u.members_alive[entity_id]
		for m: int in range(_figures.size()):
			_figures[m].visible = m < _shown_members
	if _label == null:
		return
	var supp: int = u.suppression[entity_id]
	var hurt: bool = false
	var text: String = ""
	if def.is_infantry:
		text = "%d/%d" % [u.members_alive[entity_id], def.members]
		hurt = u.members_alive[entity_id] < def.members
	else:
		var pct: int = maxi(0, u.hp[entity_id]) * 100 / maxi(1, def.hp)
		text = "%d%%" % pct
		hurt = pct < 100 or u.damage[entity_id] != 0 or u.crew[entity_id] != def.crew_slots
	if supp >= MoraleSystem.PIN_THRESHOLD:
		text += " PINNED"
	elif supp >= 300:
		text += " supp"
	_label.text = text
	_label.modulate = Color(1, 0.55, 0.45) if supp >= MoraleSystem.PIN_THRESHOLD else Color(0.95, 0.95, 0.9)
	_label.visible = show_label or hurt or supp >= 300


func _refresh_structure(world: SimWorld, show_label: bool) -> void:
	var s: StructureStore = world.structures
	var complete: bool = s.is_complete(entity_id)
	if complete != _complete:
		_complete = complete
		_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if complete else BaseMaterial3D.TRANSPARENCY_ALPHA
	var text: String = ""
	if not complete:
		var total: int = maxi(1, def.build_time_ticks * 100)
		var pct: int = 100 - s.build_left[entity_id] * 100 / total
		_material.albedo_color.a = 0.25 + 0.6 * pct / 100.0
		text = "%s %d%%" % [def.display_name, pct]
	elif def.role == "depot_objective":
		var holder: int = s.holder_team[entity_id]
		if _flag_mat != null:
			_flag_mat.albedo_color = FLAG_COLORS[holder] if holder >= 0 else FLAG_COLORS[3]
		text = "DEPOT"
		if s.capture_team[entity_id] >= 0:
			text += " capturing %d%%" % (s.capture_progress[entity_id] * 100 / maxi(1, Economy.ticks(world, "capture_s")))
		if holder >= 0:
			text += "  stock %d%s" % [s.stock[entity_id], "" if s.connected[entity_id] == 1 else "  (no route)"]
	else:
		var q: PackedInt32Array = s.get_queue(entity_id)
		if not q.is_empty():
			text = "%s: %s (%d)" % [def.display_name, world.defs.units[q[0]].display_name, q.size()]
		elif world.units.hp[entity_id] < def.hp:
			text = "%d%%" % (world.units.hp[entity_id] * 100 / def.hp)
	if _label != null:
		_label.text = text
		_label.position.y = 12.0
		_label.visible = text != "" or show_label

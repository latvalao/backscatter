## Unit / structure visual: forged low-poly model dressed with the scale-model
## shader, team ground ring (team identity is never carried by paint, §10),
## turret tracking its sim target, infantry drawn as individual soldiers,
## mud / contamination / construction state and the persistent wreck state.
## Read-only with respect to the sim.
class_name UnitView
extends Node3D

## Colour-blind-safe team markers: blue / orange / yellow / grey.
const TEAM_COLORS: Array[Color] = [Color(0.24, 0.55, 0.88), Color(0.9, 0.5, 0.15), Color(0.92, 0.82, 0.25), Color(0.75, 0.75, 0.72)]
const FLAG_COLORS: Array[Color] = [Color(0.24, 0.55, 0.88), Color(0.9, 0.5, 0.15), Color(0.92, 0.82, 0.25), Color(0.85, 0.85, 0.85)]

var entity_id: int = 0
var team: int = 0
var faction: String = ""
var def: UnitStats
var ghost: bool = false
var wrecked: bool = false
var model: Node3D

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _label: Label3D
var _figures: Array[Node3D] = []
var _figure_base: Array[Vector3] = []
var _geoms: Array[GeometryInstance3D] = []
var _turret: Node3D
var _shown_members: int = -1
var _flag_mat: StandardMaterial3D
var _complete: bool = true
var _mud: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _bob: float = 0.0
var _burn: float = 0.0
var _selected: bool = false
var _rotor: Node3D
var _lie: float = 0.0
var _sway: float = 0.0
var _last_speed: float = 0.0
var _dust: GPUParticles3D
var _identified: bool = true
var _proxy: MeshInstance3D


func setup(id: int, p_team: int, p_def: UnitStats, p_ghost: bool = false, p_faction: String = "") -> void:
	entity_id = id
	team = p_team
	def = p_def
	ghost = p_ghost
	faction = p_faction if p_faction != "" else def.faction
	name = ("Ghost_%d" if ghost else "Unit_%d") % id
	model = ModelLibrary.instantiate(def)
	if model == null:
		model = _fallback_box()
	add_child(model)
	var mat: Material
	if ghost:
		mat = ModelLibrary.ghost_material()
	else:
		mat = ModelLibrary.material(ModelLibrary.faction_row(faction), ModelLibrary.camo_style(faction))
	ModelLibrary.dress(model, mat)
	_collect_geoms(model)
	if not def.is_structure:
		model.scale = Vector3.ONE * ModelLibrary.UNIT_SCALE
	_turret = model.get_node_or_null("Turret") as Node3D
	_rotor = model.get_node_or_null("Rotor") as Node3D
	if def.is_infantry:
		_build_squad()
	if def.is_air:
		model.position.y = 0.0
	if def.is_structure and def.role == "depot_objective":
		_build_flag()
	if ghost:
		return
	_build_ring()


func _collect_geoms(n: Node) -> void:
	var g: GeometryInstance3D = n as GeometryInstance3D
	if g != null:
		_geoms.append(g)
	for c: Node in n.get_children():
		_collect_geoms(c)


func _fallback_box() -> Node3D:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	var r: float = def.radius_mm * 0.001
	bm.size = Vector3(r, 1.6, r * 2.0)
	mi.mesh = bm
	mi.position.y = 0.8
	root.add_child(mi)
	return root


## Soldiers in a loose, slightly irregular file; SoldierA riflemen, SoldierB
## support gunner, Prop (mortar / ATGM post) beside the squad leader.
func _build_squad() -> void:
	var a: MeshInstance3D = model.get_node_or_null("SoldierA") as MeshInstance3D
	var b: MeshInstance3D = model.get_node_or_null("SoldierB") as MeshInstance3D
	var prop: MeshInstance3D = model.get_node_or_null("Prop") as MeshInstance3D
	if a == null:
		return
	var n: int = maxi(1, def.members)
	var spread: float = maxf(2.2, def.radius_mm * 0.001 * 0.8) / ModelLibrary.UNIT_SCALE
	for m: int in range(n):
		var src: MeshInstance3D = b if (b != null and (m == 1 or m == 5)) else a
		var fig: MeshInstance3D = MeshInstance3D.new()
		fig.mesh = src.mesh
		fig.material_override = src.material_override
		var h: int = SimRng.hash3(def.index, m, 3)
		var row: int = m / 3
		var col: int = m % 3
		var off: Vector3 = Vector3((col - 1) * spread * 0.55 + (float(h & 0xFF) / 255.0 - 0.5) * 0.8,
			0.0, (row - (n - 1) / 6.0) * spread * 0.6 + (float((h >> 8) & 0xFF) / 255.0 - 0.5) * 0.8)
		fig.position = off
		fig.rotation.y = (float((h >> 16) & 0xFF) / 255.0 - 0.5) * 0.6
		model.add_child(fig)
		_figures.append(fig)
		_figure_base.append(off)
		_geoms.append(fig)
	a.visible = false
	if b != null:
		b.visible = false
	if prop != null:
		prop.position = Vector3(spread * 0.9, 0, spread * 0.3)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var r: float = def.radius_mm * 0.001 * (1.15 if not def.is_infantry else 0.9)
	if def.is_structure:
		r = maxf(def.footprint_w, def.footprint_h) * SimGrid.CELL_MM * 0.00062
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = r + 0.6
	torus.outer_radius = r + 1.1
	torus.rings = 24
	torus.ring_segments = 3
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.05, 1.0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.no_depth_test = true
	_ring_mat.render_priority = 1
	var c: Color = TEAM_COLORS[team % TEAM_COLORS.size()]
	c.a = 0.5
	_ring_mat.albedo_color = c
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.25
	_ring.visible = not def.is_structure or def.role == "hq"
	add_child(_ring)


func _build_flag() -> void:
	var cell: float = SimGrid.CELL_MM * 0.001
	var sx: float = def.footprint_w * cell
	var pole: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.1
	pm.bottom_radius = 0.12
	pm.height = 12.0
	pole.mesh = pm
	pole.position = Vector3(sx * 0.5 + 1.0, 6.0, 0)
	add_child(pole)
	var flag: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(3.6, 2.2, 0.08)
	flag.mesh = fm
	flag.position = Vector3(sx * 0.5 + 2.9, 10.6, 0)
	_flag_mat = StandardMaterial3D.new()
	_flag_mat.albedo_color = FLAG_COLORS[3]
	flag.material_override = _flag_mat
	add_child(flag)


## Unidentified enemy contact: a generic shape for its class and a short label.
func set_identified(on: bool) -> void:
	if on == _identified:
		return
	_identified = on
	model.visible = on
	if not on and _proxy == null:
		_proxy = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		if def.is_infantry:
			bm.size = Vector3(4.0, 1.6, 4.0)
		elif def.is_air:
			bm.size = Vector3(5.0, 1.5, 9.0)
		else:
			bm.size = Vector3(3.6, 2.2, 7.5 if def.mobility_class == TerrainTable.TRACKED else 6.5)
		_proxy.mesh = bm
		_proxy.position.y = bm.size.y * 0.5
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.26, 0.26, 0.24)
		m.roughness = 1.0
		_proxy.material_override = m
		add_child(_proxy)
	if _proxy != null:
		_proxy.visible = not on


func is_identified() -> bool:
	return _identified


func contact_class() -> String:
	if def.is_infantry:
		return "Infantry"
	if def.is_air:
		return "Aircraft"
	return "Tracked vehicle" if def.mobility_class == TerrainTable.TRACKED else "Wheeled vehicle"


func set_selected(on: bool) -> void:
	_selected = on
	if _ring != null:
		_ring.visible = on or not def.is_structure or def.role == "hq"
		var c: Color = TEAM_COLORS[team % TEAM_COLORS.size()]
		if on:
			c = c.lightened(0.35)
		c.a = 0.95 if on else 0.5
		_ring_mat.albedo_color = c


func _set_param(p: StringName, v: float) -> void:
	for g: GeometryInstance3D in _geoms:
		g.set_instance_shader_parameter(p, v)


## Per-frame presentation update (only while visible).
func refresh(world: SimWorld, show_label: bool, terrain: TerrainView, delta: float) -> void:
	if ghost or wrecked or not world.units.has(entity_id):
		return
	var u: UnitStore = world.units
	if def.is_structure:
		_refresh_structure(world, show_label)
		return
	var moved: float = 0.0 if _last_pos == Vector3.INF else Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length()
	_last_pos = position
	if def.is_infantry:
		if _shown_members != u.members_alive[entity_id]:
			_shown_members = u.members_alive[entity_id]
			for m: int in range(_figures.size()):
				_figures[m].visible = m < _shown_members
		# pinned or dug in: soldiers go prone; moving: they bob along
		var prone: bool = (u.suppression[entity_id] >= MoraleSystem.PIN_THRESHOLD or FieldSystem.dug_in_bonus(world, entity_id) > 0) and moved < 0.001
		var target_lie: float = -1.45 if prone else 0.0
		_lie = move_toward(_lie, target_lie, delta * 3.0)
		if moved > 0.001:
			_bob += delta * 9.0
		for m2: int in range(_figures.size()):
			var f: Node3D = _figures[m2]
			f.rotation.x = _lie
			f.position.y = (absf(sin(_bob + m2 * 1.3)) * 0.07 if moved > 0.001 else 0.0) + (0.25 if _lie < -0.5 else 0.0)
	elif terrain != null and not def.is_air:
		# mud picked up on soft ground, washed off slowly (faster in rain)
		var t: int = terrain.terrain_at(position)
		if moved > 0.001 and (t == TerrainTable.BOG or t == TerrainTable.FIELD or t == TerrainTable.FOREST):
			_mud = minf(1.0, _mud + delta * (0.08 if t == TerrainTable.BOG else 0.015))
		else:
			_mud = maxf(0.0, _mud - delta * 0.002)
		_set_param(&"mud_amount", _mud)
		# suspension: pitch with acceleration, a little roll and bounce when moving
		var spd: float = moved / maxf(delta, 0.001)
		var acc: float = (spd - _last_speed) / maxf(delta, 0.001)
		_last_speed = lerpf(_last_speed, spd, 0.3)
		_sway = _sway + delta * (2.0 + spd * 0.4)
		var pitch: float = clampf(-acc * 0.004, -0.06, 0.06)
		model.rotation.x = lerpf(model.rotation.x, pitch + (sin(_sway * 3.1) * 0.012 if spd > 0.5 else 0.0), clampf(delta * 6.0, 0.0, 1.0))
		model.rotation.z = sin(_sway * 2.3) * 0.01 * clampf(spd / 8.0, 0.0, 1.0)
		if _dust != null:
			_dust.emitting = spd > 2.0 and t != TerrainTable.WATER and t != TerrainTable.BOG
		elif spd > 2.0 and terrain != null:
			_dust = Effects.make_dust_trail(def.radius_mm * 0.001 * ModelLibrary.UNIT_SCALE)
			_dust.position = Vector3(0, 0.6, def.radius_mm * 0.001 * 1.2)
			add_child(_dust)
	if world.radiation.has(entity_id):
		_set_param(&"contamination", clampf(world.radiation.contamination[entity_id] / 2000.0, 0.0, 1.0))
	_aim_turret(world, delta)
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
	if u.rank[entity_id] > 0:
		text = ["", "V ", "E "][u.rank[entity_id]] + text
	if u.rout_until[entity_id] > world.tick:
		text += " ROUTING"
	elif supp >= MoraleSystem.PIN_THRESHOLD:
		text += " PINNED"
	elif supp >= 300:
		text += " supp"
	if not _identified:
		_label.text = "? " + contact_class()
		_label.modulate = Color(1.0, 0.7, 0.5)
		_label.visible = true
		return
	_label.text = text
	_label.modulate = Color(1, 0.55, 0.45) if supp >= MoraleSystem.PIN_THRESHOLD else Color(0.95, 0.95, 0.9)
	_label.visible = show_label or hurt or supp >= 300 or u.rout_until[entity_id] > world.tick


## Turret follows the sim's current target (slot 0); returns to the front otherwise.
func _aim_turret(world: SimWorld, delta: float) -> void:
	if _turret == null or not world.weapons.has(entity_id):
		return
	var tgt: int = world.weapons.target[entity_id * WeaponStore.MAX_WEAPONS]
	var want: float = 0.0
	if tgt > 0 and world.transform.has(tgt):
		var tp: Vector3 = SimRunner.sim_to_view(world.transform.x[tgt], world.transform.y[tgt], 0)
		var d: Vector3 = tp - global_position
		var world_yaw: float = atan2(-d.x, -d.z)
		want = wrapf(world_yaw - rotation.y, -PI, PI)
	_turret.rotation.y = lerp_angle(_turret.rotation.y, want, clampf(delta * 1.6, 0.0, 1.0))


## Destroyed: charred hull, turret blown off on main battle tanks (ammo
## cook-off), fire then a lingering smoke column. Stays for the whole match.
func make_wreck(fx: Effects) -> void:
	wrecked = true
	if _dust != null:
		_dust.emitting = false
	if _ring != null:
		_ring.visible = false
	if _label != null:
		_label.visible = false
	_burn = 1.0
	_set_param(&"burn", 1.0)
	_set_param(&"mud_amount", 0.6)
	if _turret != null and def.role == "mbt" and (entity_id % 3) != 0:
		_turret.position += Vector3(1.2, 0.4, 0.8)
		_turret.rotation = Vector3(0.35, _turret.rotation.y + 0.9, -0.5)
	elif _turret != null:
		_turret.rotation.y += 0.5
		var gun: Node3D = _turret.get_node_or_null("Gun") as Node3D
		if gun != null:
			gun.rotation.x = -0.12
	rotation.z = 0.03
	if fx != null:
		fx.attach_wreck_fire(self, def.size_class == UnitStats.SIZE_LARGE)


func _process(delta: float) -> void:
	if _rotor != null and not wrecked:
		_rotor.rotation.y += delta * 28.0
	if wrecked and _burn > 0.7:
		_burn = maxf(0.7, _burn - delta * 0.004)
		_set_param(&"burn", _burn)


func _refresh_structure(world: SimWorld, show_label: bool) -> void:
	var s: StructureStore = world.structures
	var complete: bool = s.is_complete(entity_id)
	var text: String = ""
	if not complete:
		var total: int = maxi(1, def.build_time_ticks * 100)
		var pct: int = 100 - s.build_left[entity_id] * 100 / total
		_set_param(&"build_alpha", 0.15 + 0.85 * pct / 100.0)
		text = "%s %d%%" % [def.display_name, pct]
	elif complete != _complete:
		_set_param(&"build_alpha", 1.0)
	_complete = complete
	if complete and def.role == "depot_objective":
		var holder: int = s.holder_team[entity_id]
		if _flag_mat != null:
			_flag_mat.albedo_color = FLAG_COLORS[holder] if holder >= 0 else FLAG_COLORS[3]
		text = "DEPOT"
		if s.capture_team[entity_id] >= 0:
			text += " capturing %d%%" % (s.capture_progress[entity_id] * 100 / maxi(1, Economy.ticks(world, "capture_s")))
		if holder >= 0:
			text += "  stock %d%s" % [s.stock[entity_id], "" if s.connected[entity_id] == 1 else "  (no route)"]
	elif complete:
		var q: PackedInt32Array = s.get_queue(entity_id)
		if not q.is_empty():
			text = "%s: %s (%d)" % [def.display_name, world.defs.units[q[0]].display_name, q.size()]
		elif world.units.hp[entity_id] < def.hp:
			text = "%d%%" % (world.units.hp[entity_id] * 100 / def.hp)
	if _label != null:
		_label.text = text
		_label.position.y = 12.0
		_label.visible = text != "" or show_label

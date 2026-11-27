## Minimap (Phase 1.8): terrain, friendly units, enemies the local team can see,
## last-known ghosts, depots, the camera footprint and alert pings. Left-click or
## drag moves the camera; right-click sends the selection there.
class_name Minimap
extends Control

const SIZE_PX: float = 220.0
const PING_S: float = 3.0

var runner: SimRunner
var views: ViewSync
var controller: SelectionController

var _tex: ImageTexture
var _pings: Array[Dictionary] = []
var _drag: bool = false


func setup() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	size = Vector2(SIZE_PX, SIZE_PX)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 10
	offset_top = -SIZE_PX - 10
	offset_right = 10 + SIZE_PX
	offset_bottom = -10
	mouse_filter = Control.MOUSE_FILTER_STOP
	var g: SimGrid = runner.world.grid
	var img: Image = Image.create(g.width, g.height, false, Image.FORMAT_RGB8)
	for y: int in range(g.height):
		for x: int in range(g.width):
			var i: int = g.index(x, y)
			var c: Color = TerrainView.COLORS[g.terrain[i]]
			c = c.lightened(clampf(g.ground_mm[i] / 60000.0, 0.0, 0.35) - 0.1)
			img.set_pixel(x, g.height - 1 - y, c)
	_tex = ImageTexture.create_from_image(img)


func ping(p: Vector3, c: Color) -> void:
	_pings.append({"p": p, "c": c, "t": PING_S})


func _to_map(p: Vector3) -> Vector2:
	var w: SimWorld = runner.world
	return Vector2(p.x / (w.map_width_mm() * 0.001), 1.0 + p.z / (w.map_height_mm() * 0.001)) * SIZE_PX


func _to_world(m: Vector2) -> Vector3:
	var w: SimWorld = runner.world
	return Vector3(m.x / SIZE_PX * w.map_width_mm() * 0.001, 0.0, -(1.0 - m.y / SIZE_PX) * w.map_height_mm() * 0.001)


func _process(delta: float) -> void:
	for i: int in range(_pings.size() - 1, -1, -1):
		_pings[i]["t"] = float(_pings[i]["t"]) - delta
		if float(_pings[i]["t"]) <= 0.0:
			_pings.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	draw_rect(Rect2(Vector2(-2, -2), Vector2(SIZE_PX + 4, SIZE_PX + 4)), Color(0, 0, 0, 0.7))
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), false)
	var w: SimWorld = runner.world
	var team: int = views.local_team
	var layer: TeamVision = w.vision[team]
	for id: int in w.entities.ids():
		if not w.units.has(id) or w.units.carrier[id] != 0:
			continue
		var t: int = w.units.team[id]
		var p: Vector3 = SimRunner.sim_to_view(w.transform.x[id], w.transform.y[id], 0)
		var col: Color = UnitView.TEAM_COLORS[t % 4]
		var size: float = 2.0
		if w.is_structure(id):
			size = 4.0
			if t == SimWorld.NEUTRAL_TEAM:
				var h: int = w.structures.holder_team[id]
				col = UnitView.TEAM_COLORS[h] if h >= 0 else Color(0.9, 0.9, 0.9)
		elif t != team and not views.reveal_all:
			if not layer.is_visible(id, w.tick):
				if layer.is_known(id):
					p = SimRunner.sim_to_view(layer.last_x[id], layer.last_y[id], 0)
					col = col.darkened(0.4)
					col.a = 0.6
				else:
					continue
		if controller != null and views.selected.has(id):
			col = col.lightened(0.5)
		var m: Vector2 = _to_map(p)
		draw_rect(Rect2(m - Vector2(size, size) * 0.5, Vector2(size, size)), col)
	# camera footprint
	var cam: RtsCamera = controller.cam
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var corners: PackedVector2Array = PackedVector2Array()
	for c: Vector2 in [Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]:
		var gp: Variant = cam.ground_point(c)
		if gp == null:
			var o: Vector3 = cam.camera.project_ray_origin(c)
			var d: Vector3 = cam.camera.project_ray_normal(c)
			gp = o + d * (o.y / maxf(0.05, -d.y))
		corners.append(_to_map(gp as Vector3))
	corners.append(corners[0])
	draw_polyline(corners, Color(1, 1, 1, 0.8), 1.0)
	for pg: Dictionary in _pings:
		var k: float = 1.0 - float(pg["t"]) / PING_S
		var pc: Color = pg["c"]
		pc.a = 1.0 - k
		draw_arc(_to_map(pg["p"] as Vector3), 4.0 + k * 14.0, 0.0, TAU, 20, pc, 1.5)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				controller.cam.focus(_to_world(mb.position))
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not controller.selection.is_empty():
			var s: Vector2i = SimRunner.view_to_sim(_to_world(mb.position))
			controller.submit(MoveCommand.new(controller.selection, s.x, s.y, MoveCommand.MODE_MOVE, mb.shift_pressed, false, controller.formation))
		accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _drag:
		controller.cam.focus(_to_world(mm.position))
		accept_event()

## RTS camera: arrow keys / screen-edge / middle-mouse drag to pan, wheel zoom,
## Q/E rotate, Page Up/Down pitch. Pitch clamped to 40–70° (§9).
class_name RtsCamera
extends Node3D

@export var pan_speed: float = 500.0
@export var min_distance: float = 30.0
@export var max_distance: float = 1500.0
@export var pitch_deg: float = 55.0
@export var edge_pan: bool = true

var distance: float = 500.0
var bounds: Rect2 = Rect2(0, -4000, 4000, 4000)  # x, z range
var terrain: TerrainView
var camera: Camera3D

var _dragging: bool = false


func _ready() -> void:
	camera = Camera3D.new()
	camera.far = 9000.0
	camera.near = 0.5
	add_child(camera)
	_apply()


func _process(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if edge_pan and DisplayServer.window_is_focused():
		var vp: Viewport = get_viewport()
		var m: Vector2 = vp.get_mouse_position()
		var size: Vector2 = vp.get_visible_rect().size
		if m.x >= 0 and m.y >= 0 and m.x <= size.x and m.y <= size.y:
			if m.x < 6:
				dir.x -= 1.0
			elif m.x > size.x - 6:
				dir.x += 1.0
			if m.y < 6:
				dir.y -= 1.0
			elif m.y > size.y - 6:
				dir.y += 1.0
	if dir != Vector2.ZERO:
		_pan(dir.normalized() * pan_speed * (distance / 500.0) * delta)
	if Input.is_key_pressed(KEY_Q):
		rotation.y += 1.4 * delta
	if Input.is_key_pressed(KEY_E):
		rotation.y -= 1.4 * delta
	if Input.is_key_pressed(KEY_PAGEUP):
		pitch_deg += 30.0 * delta
		_apply()
	if Input.is_key_pressed(KEY_PAGEDOWN):
		pitch_deg -= 30.0 * delta
		_apply()
	if terrain != null:
		position.y = lerpf(position.y, terrain.height_at(position), clampf(delta * 6.0, 0.0, 1.0))


func _pan(v: Vector2) -> void:
	var basis_flat: Basis = Basis(Vector3.UP, rotation.y)
	position += basis_flat * Vector3(v.x, 0.0, v.y)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func focus(p: Vector3) -> void:
	position.x = p.x
	position.z = p.z


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance * 0.88)
			_apply()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * 1.12)
			_apply()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _dragging:
		_pan(-mm.relative * distance / 600.0)


func _apply() -> void:
	pitch_deg = clampf(pitch_deg, 40.0, 70.0)
	var p: float = deg_to_rad(pitch_deg)
	if camera == null:
		return
	camera.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)
	camera.rotation = Vector3(-p, 0.0, 0.0)


## Ground point under a screen position (ray march over the terrain), or null.
func ground_point(screen: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	var prev: Vector3 = origin
	var step: float = 6.0
	var t: float = 0.0
	while t < 9000.0:
		var p: Vector3 = origin + dir * t
		if p.y <= terrain.height_at(p):
			# refine between prev and p
			var a: Vector3 = prev
			var b: Vector3 = p
			for i: int in range(8):
				var mid: Vector3 = (a + b) * 0.5
				if mid.y <= terrain.height_at(mid):
					b = mid
				else:
					a = mid
			return b
		prev = p
		t += step
		step = minf(step * 1.04, 40.0)
	return null

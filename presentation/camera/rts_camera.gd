## RTS camera: arrow keys / screen-edge / middle-mouse drag to pan, wheel zoom,
## Q/E rotate, Page Up/Down pitch. Narrow FOV for the diorama look, smooth zoom,
## slight auto-tilt toward the horizon when close (cinematic) and top-down when
## far (tactical), zoom-driven tilt-shift depth of field (docs/VISUALS.md §8.1).
class_name RtsCamera
extends Node3D

@export var pan_speed: float = 500.0
@export var min_distance: float = 30.0
@export var max_distance: float = 1500.0
@export var pitch_deg: float = 55.0
@export var edge_pan: bool = true

var distance: float = 500.0
var _distance_target: float = 500.0
var _attrs: CameraAttributesPractical
var bounds: Rect2 = Rect2(0, -4000, 4000, 4000)  # x, z range
var terrain: TerrainView
var camera: Camera3D

var _dragging: bool = false


func _ready() -> void:
	camera = Camera3D.new()
	camera.far = 9000.0
	camera.near = 0.5
	camera.fov = 40.0
	_attrs = CameraAttributesPractical.new()
	camera.attributes = _attrs
	add_child(camera)
	_distance_target = distance
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
	if absf(_distance_target - distance) > 0.05:
		distance = lerpf(distance, _distance_target, clampf(delta * 8.0, 0.0, 1.0))
		_apply()
	if terrain != null:
		position.y = lerpf(position.y, terrain.height_at(position), clampf(delta * 6.0, 0.0, 1.0))


func _pan(v: Vector2) -> void:
	var basis_flat: Basis = Basis(Vector3.UP, rotation.y)
	position += basis_flat * Vector3(v.x, 0.0, v.y)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func set_distance(d: float) -> void:
	distance = clampf(d, min_distance, max_distance)
	_distance_target = distance
	_apply()


func focus(p: Vector3) -> void:
	position.x = p.x
	position.z = p.z


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance_target = maxf(min_distance, _distance_target * 0.85)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance_target = minf(max_distance, _distance_target * 1.15)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _dragging:
		_pan(-mm.relative * distance / 600.0)


func _apply() -> void:
	pitch_deg = clampf(pitch_deg, 40.0, 70.0)
	# auto-tilt: up to 14° flatter when zoomed right in
	var close: float = 1.0 - clampf((distance - min_distance) / 250.0, 0.0, 1.0)
	var p: float = deg_to_rad(pitch_deg - close * 14.0)
	if camera == null:
		return
	camera.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)
	camera.rotation = Vector3(-p, 0.0, 0.0)
	if _attrs != null:
		var on: bool = GraphicsSettings.tilt_shift
		_attrs.dof_blur_far_enabled = on
		_attrs.dof_blur_near_enabled = on
		_attrs.dof_blur_far_distance = distance * 1.25
		_attrs.dof_blur_far_transition = distance * 0.9
		_attrs.dof_blur_near_distance = distance * 0.55
		_attrs.dof_blur_near_transition = distance * 0.3
		_attrs.dof_blur_amount = clampf(0.04 + distance / 4000.0, 0.04, 0.16)


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

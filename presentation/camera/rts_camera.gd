## Minimal RTS camera: WASD/arrow pan, mouse wheel zoom, Q/E rotate.
## Pitch clamped to 40–70° per design doc §9.
class_name RtsCamera
extends Node3D

@export var pan_speed: float = 400.0
@export var min_distance: float = 40.0
@export var max_distance: float = 1500.0
@export var pitch_deg: float = 55.0

var distance: float = 600.0
var _cam: Camera3D


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.far = 8000.0
	add_child(_cam)
	_apply()


func _process(delta: float) -> void:
	var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var basis_flat: Basis = Basis(Vector3.UP, rotation.y)
	var move: Vector3 = basis_flat * Vector3(dir.x, 0.0, dir.y)
	position += move * pan_speed * (distance / 600.0) * delta
	if Input.is_key_pressed(KEY_Q):
		rotation.y += 1.5 * delta
	if Input.is_key_pressed(KEY_E):
		rotation.y -= 1.5 * delta


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * 1.1)
		_apply()


func _apply() -> void:
	pitch_deg = clampf(pitch_deg, 40.0, 70.0)
	var p: float = deg_to_rad(pitch_deg)
	_cam.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)
	_cam.rotation = Vector3(-p, 0.0, 0.0)

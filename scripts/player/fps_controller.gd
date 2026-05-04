## FPSController — WASD movement and mouse-look for first-person player.
## Attach to a Node child of CharacterBody3D. Camera3D must be a direct child
## of the CharacterBody3D named "Camera3D".
class_name FPSController
extends Node

## Mouse sensitivity in radians per pixel.
@export var mouse_sensitivity: float = 0.002
## Horizontal movement speed in m/s.
@export var move_speed: float = 4.0
## Jump impulse velocity in m/s.
@export var jump_velocity: float = 4.5

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _camera: Camera3D = _body.get_node("Camera3D") as Camera3D

# Read once in _ready — never mutate ProjectSettings.
var _gravity: float = 0.0

var _bob_time: float = 0.0


func _ready() -> void:
	# Read gravity from project settings once; never call set_setting.
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") as float
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_body.rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera.rotate_x(-motion.relative.y * mouse_sensitivity)
		_camera.rotation.x = clampf(_camera.rotation.x, -1.5, 1.5)


func _physics_process(delta: float) -> void:
	if _body == null or _camera == null:
		return

	# Apply gravity on the CharacterBody3D velocity directly.
	if not _body.is_on_floor():
		_body.velocity.y -= _gravity * delta

	var input_dir: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back"
	)
	var direction: Vector3 = (
		_body.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	if direction != Vector3.ZERO:
		_body.velocity.x = direction.x * move_speed
		_body.velocity.z = direction.z * move_speed
	else:
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, move_speed)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, move_speed)

	_body.move_and_slide()
	_apply_head_bob(delta)


func _apply_head_bob(delta: float) -> void:
	var horizontal_speed: float = Vector2(_body.velocity.x, _body.velocity.z).length()
	if horizontal_speed > 0.1 and _body.is_on_floor():
		_bob_time = fmod(_bob_time + delta * horizontal_speed * 0.5, TAU)
		_camera.position.y = lerpf(
			_camera.position.y, sin(_bob_time * 2.0) * 0.02, 10.0 * delta
		)
	else:
		_camera.position.y = lerpf(_camera.position.y, 0.0, 6.0 * delta)

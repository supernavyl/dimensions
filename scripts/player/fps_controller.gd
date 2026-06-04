## FPSController — physically grounded first-person controller.
## Real-feeling body: acceleration/friction curves, weighty mouse-look,
## landing impact spring, step cadence with footstep audio, lean-into-strafe,
## crouch, sprint, and DrugDaze-coupled motor degradation.
##
## Attach to a Node child of CharacterBody3D. Camera3D and CollisionShape3D
## (capsule) must be direct children of the body.
class_name FPSController
extends Node

# --- Tuning ----------------------------------------------------------------

## Mouse sensitivity in radians per pixel.
@export var mouse_sensitivity: float = 0.0022
## Walk top speed (m/s).
@export var walk_speed: float = 4.0
## Sprint top speed (m/s, hold Shift).
@export var sprint_speed: float = 6.2
## Crouch top speed (m/s, hold Ctrl).
@export var crouch_speed: float = 1.9
## Ground acceleration toward target velocity (m/s²).
@export var ground_accel: float = 38.0
## Ground deceleration when no input (m/s²).
@export var ground_friction: float = 22.0
## Air acceleration — limited control mid-jump.
@export var air_accel: float = 6.0
## Jump impulse velocity (m/s).
@export var jump_velocity: float = 4.6
## Mouse-look smoothing — fraction of motion applied per frame.
## 1.0 = instant, lower = heavier head. 0.55 feels like a real neck.
@export var look_smoothing: float = 0.55
## Lean into strafe (radians at full sideways speed).
@export var strafe_lean: float = 0.045
## Standing camera height above body origin.
@export var stand_height: float = 1.7
## Crouched camera height above body origin.
@export var crouch_height: float = 1.05

# --- Refs ------------------------------------------------------------------

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _camera: Camera3D = _body.get_node("Camera3D") as Camera3D
@onready var _collision: CollisionShape3D = _body.get_node_or_null("CollisionShape3D") as CollisionShape3D

var _gravity: float = 0.0
var _daze: DrugDaze
var _capsule_full_height: float = 1.8

# --- Step cadence + footstep audio ----------------------------------------

var _bob_phase: float = 0.0
var _last_bob_y: float = 0.0
var _step_players: Array[AudioStreamPlayer] = []
var _step_streams: Array[AudioStreamWAV] = []
var _step_idx: int = 0
var _land_player: AudioStreamPlayer

# --- Landing spring (1D damped harmonic on camera offset) ------------------

var _land_offset: float = 0.0
var _land_velocity: float = 0.0
const _LAND_SPRING_K: float = 95.0
const _LAND_SPRING_D: float = 13.0

# --- Crouch / state --------------------------------------------------------

var _crouching: bool = false
var _camera_y_target: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") as float
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_daze = _body.get_node_or_null("DrugDaze") as DrugDaze
	_camera_y_target = stand_height
	_camera.position.y = stand_height

	if _collision != null and _collision.shape is CapsuleShape3D:
		var cap: CapsuleShape3D = _collision.shape as CapsuleShape3D
		_capsule_full_height = cap.height

	_init_step_audio()


func _init_step_audio() -> void:
	# Pre-bake 6 footstep variants. Round-robin to avoid same sample twice.
	for i: int in range(6):
		var stream: AudioStreamWAV = ProcAudio.footstep(1000 + i * 137, 0.45)
		_step_streams.append(stream)
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = &"Master"
		p.volume_db = -10.0
		add_child(p)
		_step_players.append(p)

	_land_player = AudioStreamPlayer.new()
	_land_player.stream = ProcAudio.land_thud(1.0, 0.7)
	_land_player.bus = &"Master"
	_land_player.volume_db = -6.0
	add_child(_land_player)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var k: float = _daze.current_intensity if _daze != null else 0.0
		var sens: float = mouse_sensitivity * lerpf(1.0, 0.55, k)
		# Direct mouse-look — apply immediately so the head feels responsive.
		_body.rotate_y(-motion.relative.x * sens)
		_camera.rotate_x(-motion.relative.y * sens)
		_camera.rotation.x = clampf(_camera.rotation.x, -1.5, 1.5)


func _physics_process(delta: float) -> void:
	if _body == null or _camera == null:
		return

	_apply_gravity(delta)
	_handle_jump()
	_apply_crouch(delta)
	_apply_horizontal_movement(delta)
	_body.move_and_slide()
	_handle_landing()
	_apply_camera_dynamics(delta)


# --- Gravity / jump --------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not _body.is_on_floor():
		_body.velocity.y -= _gravity * delta


func _handle_jump() -> void:
	if not Input.is_action_just_pressed(&"jump"):
		return
	if not _body.is_on_floor():
		return
	# Daze halves jump strength — the body is heavy.
	var k: float = _daze.current_intensity if _daze != null else 0.0
	_body.velocity.y = jump_velocity * lerpf(1.0, 0.5, k)


# --- Crouch ---------------------------------------------------------------

func _apply_crouch(delta: float) -> void:
	# Crouch action may not exist in the project — fall back to raw Ctrl key.
	var want_crouch: bool = Input.is_key_pressed(KEY_CTRL)
	if InputMap.has_action(&"crouch"):
		want_crouch = want_crouch or Input.is_action_pressed(&"crouch")
	_crouching = want_crouch
	_camera_y_target = crouch_height if _crouching else stand_height

	if _collision != null and _collision.shape is CapsuleShape3D:
		var cap: CapsuleShape3D = _collision.shape as CapsuleShape3D
		var target_h: float = _capsule_full_height * (0.6 if _crouching else 1.0)
		cap.height = lerpf(cap.height, target_h, clampf(delta * 10.0, 0.0, 1.0))


# --- Horizontal movement (accel + friction) -------------------------------

func _apply_horizontal_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back"
	)
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and not _crouching
	var top_speed: float = walk_speed
	if sprinting:
		top_speed = sprint_speed
	if _crouching:
		top_speed = crouch_speed

	# Daze: top speed drops to 35% at peak. Stagger drift adds incoherent push.
	var k: float = _daze.current_intensity if _daze != null else 0.0
	top_speed *= lerpf(1.0, 0.35, k)

	var wish_dir: Vector3 = (
		_body.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()
	var wish_vel: Vector3 = wish_dir * top_speed

	var horizontal_vel := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var on_ground: bool = _body.is_on_floor()
	var accel: float = ground_accel if on_ground else air_accel

	if wish_dir != Vector3.ZERO:
		# Exponential approach to wish velocity.
		var step: float = accel * delta
		horizontal_vel = horizontal_vel.move_toward(wish_vel, step)
	elif on_ground:
		# Friction — linear deceleration to zero.
		var friction_step: float = ground_friction * delta
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, friction_step)

	# Stagger drift while dazed — lateral wobble at low frequency.
	if k > 0.05:
		var t_ms: float = float(Time.get_ticks_msec())
		var stagger: Vector3 = (
			_body.transform.basis.x * sin(t_ms * 0.0021)
			+ _body.transform.basis.x * sin(t_ms * 0.0007) * 0.5
		) * k * 1.1
		horizontal_vel += stagger * delta * 8.0

	_body.velocity.x = horizontal_vel.x
	_body.velocity.z = horizontal_vel.z


# --- Landing impact -------------------------------------------------------

func _handle_landing() -> void:
	var on_floor: bool = _body.is_on_floor()
	if on_floor and not _was_on_floor:
		# Impact strength scales with downward velocity at touchdown.
		var impact: float = clampf(absf(_body.velocity.y) / 8.0, 0.15, 1.4)
		_land_velocity -= impact * 4.5  # negative = camera drops
		if _land_player != null:
			_land_player.stream = ProcAudio.land_thud(impact, 0.7)
			_land_player.volume_db = lerpf(-18.0, -3.0, impact)
			_land_player.play()
	_was_on_floor = on_floor


# --- Camera dynamics: bob, breath, lean, landing spring -------------------

func _apply_camera_dynamics(delta: float) -> void:
	# --- Landing spring: damped harmonic on _land_offset ---
	var spring_force: float = -_LAND_SPRING_K * _land_offset - _LAND_SPRING_D * _land_velocity
	_land_velocity += spring_force * delta
	_land_offset += _land_velocity * delta

	# --- Walk bob + step cadence ---
	var horizontal_speed: float = Vector2(_body.velocity.x, _body.velocity.z).length()
	var moving: bool = horizontal_speed > 0.3 and _body.is_on_floor()
	var bob_y: float = 0.0
	var bob_x: float = 0.0
	if moving:
		var cadence: float = horizontal_speed * 1.6
		_bob_phase = fmod(_bob_phase + delta * cadence, TAU)
		bob_y = sin(_bob_phase * 2.0) * 0.025
		bob_x = sin(_bob_phase) * 0.018
		# Footstep fires on the downward zero-crossing of the vertical bob —
		# that matches when the foot would actually plant.
		if _last_bob_y > 0.0 and bob_y <= 0.0:
			_play_step(horizontal_speed)
		_last_bob_y = bob_y
	else:
		_bob_phase = lerpf(_bob_phase, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		_last_bob_y = lerpf(_last_bob_y, 0.0, clampf(delta * 6.0, 0.0, 1.0))

	# --- Breath: tiny rise/fall, slower and deeper while dazed ---
	var k: float = _daze.current_intensity if _daze != null else 0.0
	var breath_rate: float = lerpf(1.6, 0.95, k)
	var breath_amp: float = lerpf(0.004, 0.013, k)
	var breath_y: float = sin(Time.get_ticks_msec() * 0.001 * breath_rate) * breath_amp

	# --- Strafe lean ---
	var local_vel: Vector3 = _body.transform.basis.inverse() * _body.velocity
	var max_for_lean: float = walk_speed
	var lean_ratio: float = clampf(local_vel.x / max_for_lean, -1.0, 1.0)
	var target_roll: float = -lean_ratio * strafe_lean
	# DrugDaze adds its own roll on top via its shake — don't fight it,
	# only set the lean target while ignoring the existing offset.
	_camera.rotation.z = lerpf(_camera.rotation.z, target_roll, clampf(delta * 6.0, 0.0, 1.0))

	# --- Compose final camera y ---
	_camera.position.y = lerpf(
		_camera.position.y,
		_camera_y_target + bob_y + breath_y + _land_offset,
		clampf(delta * 18.0, 0.0, 1.0)
	)
	_camera.position.x = lerpf(_camera.position.x, bob_x, clampf(delta * 18.0, 0.0, 1.0))


func _play_step(speed: float) -> void:
	if _step_players.is_empty():
		return
	var p: AudioStreamPlayer = _step_players[_step_idx]
	_step_idx = (_step_idx + 1) % _step_players.size()
	# Volume scales with speed — sneak is quieter.
	var volume_db: float = lerpf(-22.0, -6.0, clampf(speed / sprint_speed, 0.0, 1.0))
	if _crouching:
		volume_db -= 8.0
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()

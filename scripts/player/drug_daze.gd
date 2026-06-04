## DrugDaze — wake-up-from-overdose effect.
## Pushes a fullscreen drug_daze shader at peak intensity, shakes and sways
## the camera, then decays everything to zero over `duration` seconds.
## Add as a child of the Player and call begin(duration) once.
class_name DrugDaze
extends Node

const _SHADER_PATH: String = "res://shaders/drug_daze.gdshader"

## Total decay time in seconds. Effect is full at t=0 and zero at t=duration.
@export var duration: float = 12.0
## Peak rotational shake in radians.
@export var shake_rot_amp: float = 0.055
## Peak position shake in meters.
@export var shake_pos_amp: float = 0.045
## Peak slow sway in radians (low-frequency drift on top of the jitter).
@export var sway_amp: float = 0.09
## Time between shake target re-rolls — lower = more violent.
@export var shake_tick: float = 0.07

var _camera: Camera3D
var _canvas: CanvasLayer
var _overlay: ColorRect
var _shader_mat: ShaderMaterial
var _t: float = 0.0
var _active: bool = false
## Eased intensity in [0, 1]. Other systems (viewmodel, audio) read this to
## react to the daze without re-deriving timing.
var current_intensity: float = 0.0
var _shake_acc: float = 0.0
var _shake_target_rot: Vector3 = Vector3.ZERO
var _shake_target_pos: Vector3 = Vector3.ZERO
var _base_cam_pos: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var body: CharacterBody3D = get_parent() as CharacterBody3D
	if body == null:
		push_error("DrugDaze: parent must be CharacterBody3D")
		return
	_camera = body.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		push_error("DrugDaze: no Camera3D under player")
		return
	_base_cam_pos = _camera.position


## Starts the daze. Subsequent calls reset the timer and re-arm the effect.
func begin(secs: float) -> void:
	if _camera == null:
		return
	duration = maxf(0.5, secs)
	_t = 0.0
	_active = true
	_ensure_overlay()
	_shader_mat.set_shader_parameter(&"intensity", 1.0)


func _ensure_overlay() -> void:
	if is_instance_valid(_overlay):
		return
	_canvas = CanvasLayer.new()
	_canvas.layer = 7  # above per-dimension CA (5) and grain/vignette (6), below death (10)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = load(_SHADER_PATH) as Shader
	_overlay.material = _shader_mat
	_canvas.add_child(_overlay)
	add_child(_canvas)


func _process(delta: float) -> void:
	if not _active or _camera == null:
		return

	_t += delta
	var k: float = clampf(1.0 - _t / duration, 0.0, 1.0)
	# Ease-out so the worst of the daze lingers, then drops off.
	var eased: float = k * k * (3.0 - 2.0 * k)
	current_intensity = eased

	if _shader_mat != null:
		_shader_mat.set_shader_parameter(&"intensity", eased)

	# Re-roll a new shake target every shake_tick seconds; lerp toward it
	# in between so the camera doesn't clack between frames.
	_shake_acc += delta
	if _shake_acc >= shake_tick:
		_shake_acc = 0.0
		_shake_target_rot = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * shake_rot_amp * eased
		_shake_target_pos = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * shake_pos_amp * eased

	var blend: float = clampf(delta * 18.0, 0.0, 1.0)
	# Sway — slow figure-8 drift on top of the jitter.
	var sway_x: float = sin(_t * 1.3) * sway_amp * eased
	var sway_z: float = cos(_t * 0.9) * sway_amp * eased * 0.6

	_camera.rotation.z = lerpf(_camera.rotation.z, _shake_target_rot.z + sway_z, blend)
	# Don't fight FPSController on x/y — add a small additive jitter the controller
	# overwrites in _unhandled_input only on mouse motion, so it stays visible.
	_camera.position = _base_cam_pos.lerp(_base_cam_pos + _shake_target_pos, blend)

	# Pitch/yaw nudge — additive each frame, small enough that mouse-look dominates.
	_camera.rotation.x += sway_x * delta * 4.0
	_camera.rotation.x = clampf(_camera.rotation.x, -1.5, 1.5)

	if eased <= 0.001 and _t >= duration:
		_finish()


func _finish() -> void:
	_active = false
	current_intensity = 0.0
	if _camera != null:
		_camera.position = _base_cam_pos
		_camera.rotation.z = 0.0
	if _shader_mat != null:
		_shader_mat.set_shader_parameter(&"intensity", 0.0)
	if is_instance_valid(_canvas):
		_canvas.queue_free()
	_canvas = null
	_overlay = null
	_shader_mat = null

## PseudopodRig — first-person neutrophil pseudopod "hands".
## Two soft tapered membrane lobes positioned where FPS hands would go.
## Lives as a child of the player's Camera3D so it follows look direction.
##
## Anatomical grounding (NOESIS, OpenStax A&P 2e ch. 21):
##   "A neutrophil is a phagocytic cell attracted via chemotaxis from the
##    bloodstream. These spherical cells are granulocytes. A granulocyte
##    contains cytoplasmic granules, which in turn contain a variety of
##    vasoactive mediators such as histamine."
##
## The pseudopod is the membrane extension a leukocyte uses to engulf
## targets (phagocytosis). At cell scale, these ARE your hands.
##
## Lifecycle: added by SkeletonBody.mutate_for_template when entering the
## anatomy_alveolus dimension; queue_freed on dimension switch.
class_name PseudopodRig
extends Node3D

const _PSEUDOPOD_SHADER_PATH: String = "res://shaders/pseudopod.gdshader"

# Position offsets (in Camera3D local space) for the two pseudopods.
# Pushed out + down so they read as peripheral hand-stubs and don't block
# the central view when looking around.
const _LEFT_OFFSET: Vector3 = Vector3(-0.55, -0.62, -0.95)
const _RIGHT_OFFSET: Vector3 = Vector3(0.55, -0.62, -0.95)
# Long axis ~60° forward + outward splay so they don't read as parallel.
const _LEFT_ROT_DEG: Vector3 = Vector3(64.0, 0.0, -14.0)
const _RIGHT_ROT_DEG: Vector3 = Vector3(64.0, 0.0, 14.0)

const _IDLE_WOBBLE_SPEED: float = 1.4
const _IDLE_WOBBLE_AMP: float = 0.02
const _EXTEND_MAX: float = 0.65
const _EXTEND_LERP: float = 6.0

var _left: MeshInstance3D
var _right: MeshInstance3D
var _extend_target: float = 0.0
var _extend_current: float = 0.0


func _ready() -> void:
	name = &"PseudopodRig"
	_left = _build_pseudopod(_LEFT_OFFSET, true)
	_right = _build_pseudopod(_RIGHT_OFFSET, false)
	add_child(_left)
	add_child(_right)


func _process(delta: float) -> void:
	_extend_current = lerp(
		_extend_current, _extend_target, clampf(_EXTEND_LERP * delta, 0.0, 1.0)
	)
	_set_uniform_both(&"extend_amount", _extend_current)
	# Decay extend target so a single press = single reach.
	_extend_target = lerp(_extend_target, 0.0, clampf(2.5 * delta, 0.0, 1.0))


## Trigger a phagocytic reach toward the focal point.
func reach() -> void:
	_extend_target = _EXTEND_MAX


func _build_pseudopod(offset: Vector3, is_left: bool) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = &"PseudopodLeft" if is_left else &"PseudopodRight"
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.07
	cap.height = 0.45
	cap.radial_segments = 18
	cap.rings = 10
	inst.mesh = cap
	inst.position = offset
	inst.rotation_degrees = _LEFT_ROT_DEG if is_left else _RIGHT_ROT_DEG
	inst.extra_cull_margin = 0.6

	var shader: Shader = load(_PSEUDOPOD_SHADER_PATH) as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"wobble_speed", _IDLE_WOBBLE_SPEED)
		mat.set_shader_parameter(&"wobble_amp", _IDLE_WOBBLE_AMP)
		mat.set_shader_parameter(&"extend_amount", 0.0)
		var tint_jitter: float = 0.08 if is_left else -0.05
		mat.set_shader_parameter(
			&"membrane_color",
			Color(0.95 + tint_jitter * 0.1, 0.78, 0.74 - tint_jitter * 0.1),
		)
		inst.material_override = mat
	else:
		var fb: StandardMaterial3D = StandardMaterial3D.new()
		fb.albedo_color = Color(0.95, 0.78, 0.74, 0.78)
		fb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inst.material_override = fb
	return inst


func _set_uniform_both(name_: StringName, value: Variant) -> void:
	if _left and _left.material_override is ShaderMaterial:
		(_left.material_override as ShaderMaterial).set_shader_parameter(name_, value)
	if _right and _right.material_override is ShaderMaterial:
		(_right.material_override as ShaderMaterial).set_shader_parameter(name_, value)

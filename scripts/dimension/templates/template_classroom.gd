## TemplateClassroom — mundane, bright, subtly wrong classroom dimension.
## build() is called by DimensionRoot after add_child(). data must be set first.
class_name TemplateClassroom
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData

const _DESK_W: float = 0.8
const _DESK_H: float = 0.05
const _DESK_D: float = 0.5
const _DESK_HEIGHT_Y: float = 0.75
const _ROWS_MIN: int = 3
const _ROWS_MAX: int = 5
const _COLS_MIN: int = 4
const _COLS_MAX: int = 6


## Constructs the classroom dimension.
func build(rng: RandomNumberGenerator) -> void:
	_add_environment()
	_add_lighting()
	_add_floor()
	_place_desks(rng)
	_add_player_spawn()
	_add_post_processing(0.001)


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.85, 0.84, 0.80)
	environment.fog_enabled = false
	env.environment = environment
	add_child(env)


func _add_lighting() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.98, 0.92)
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	add_child(light)


func _add_floor() -> void:
	var static_body: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = WorldBoundaryShape3D.new()
	static_body.add_child(col_shape)
	add_child(static_body)

	var floor_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(30.0, 30.0)
	floor_mesh_inst.mesh = floor_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.74, 0.70)
	floor_mesh_inst.material_override = mat
	add_child(floor_mesh_inst)


func _place_desks(rng: RandomNumberGenerator) -> void:
	var rows: int = rng.randi_range(_ROWS_MIN, _ROWS_MAX)
	var cols: int = rng.randi_range(_COLS_MIN, _COLS_MAX)
	for r: int in range(rows):
		for c: int in range(cols):
			var desk: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(_DESK_W, _DESK_H, _DESK_D)
			desk.mesh = box
			desk.position = Vector3(
				float(c) * 1.2 - float(cols) * 0.6,
				_DESK_HEIGHT_Y,
				float(r) * 1.5 - 3.0
			)
			add_child(desk)


func _add_player_spawn() -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.0, 4.0)
	add_child(spawn)


func _add_post_processing(strength: float) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5  # below DeathSequence (10) and FinalEvent (20)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/chromatic_aberration.gdshader") as Shader
	mat.set_shader_parameter(&"strength", strength)
	overlay.material = mat
	canvas.add_child(overlay)
	add_child(canvas)

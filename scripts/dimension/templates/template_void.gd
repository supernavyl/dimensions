## TemplateVoid — empty, silent, alien dimension.
## build() is called by DimensionRoot after add_child(). data must be set first.
class_name TemplateVoid
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData


## Constructs the void dimension geometry using rng seeded by DimensionRoot.
func build(rng: RandomNumberGenerator) -> void:
	_add_environment()
	_add_floor()
	_add_monoliths(rng)
	_add_player_spawn()
	_add_post_processing(0.008)


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = data.ambient_color if data != null else Color(0.02, 0.02, 0.03)

	# Dim purple-grey ambient — geometry visible but not lit.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.18, 0.28)
	environment.ambient_light_energy = 0.28

	# Exponential fog — avoids the Forward+ volumetric regression.
	environment.fog_enabled = true
	environment.fog_density = data.fog_density if data != null else 0.025
	environment.fog_light_color = Color(0.06, 0.05, 0.08)
	environment.fog_sun_scatter = 0.0

	# Bloom — subtle halo on any emissive / bright surfaces.
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_strength = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Tonemap for cinematic contrast.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES

	# Desaturated + slightly high contrast for psychological dread.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.72
	environment.adjustment_contrast = 1.18
	environment.adjustment_saturation = 0.5

	# Screen Space Ambient Occlusion — depth in corners and crevices.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.8

	env.environment = environment
	add_child(env)


func _add_floor() -> void:
	# Visual floor mesh
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	mesh_inst.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.11, 0.18)
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Collision floor
	var static_body: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = WorldBoundaryShape3D.new()
	static_body.add_child(col_shape)
	add_child(static_body)


func _add_monoliths(rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(6, 14)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.05, 0.09)
	mat.roughness = 1.0

	for i: int in range(count):
		var w: float = rng.randf_range(0.4, 1.2)
		var h: float = rng.randf_range(1.5, 6.0)
		var d: float = rng.randf_range(0.4, 1.2)
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(4.0, 28.0)
		var pos := Vector3(cos(angle) * dist, h * 0.5, sin(angle) * dist)

		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, h, d)
		col.shape = shape
		body.position = pos
		body.add_child(col)
		add_child(body)

		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, h, d)
		mesh_inst.mesh = box
		mesh_inst.material_override = mat
		mesh_inst.position = pos
		add_child(mesh_inst)


func _add_player_spawn() -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.0, 0.0)
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

## TemplateIsekai — a fragment of a bioluminescent fantasy realm. Open sky, glowing
## crystal formations, ethereal floating orbs. Beautiful. Wrong. Inescapable.
## build() is called by DimensionRoot after add_child(). data must be set first.
class_name TemplateIsekai
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData

const _CRYSTAL_COLORS: Array[Color] = [
	Color(0.3, 0.9, 1.0),    # icy cyan
	Color(0.8, 0.3, 1.0),    # violet
	Color(0.2, 1.0, 0.6),    # teal-green
	Color(1.0, 0.85, 0.2),   # gold
	Color(0.4, 0.5, 1.0),    # periwinkle
]


func build(rng: RandomNumberGenerator) -> void:
	_add_environment()
	_add_floor(rng)
	_add_crystals(rng)
	_add_floating_orbs(rng)
	_add_sky_pillars(rng)
	_add_player_spawn()
	_add_post_processing(0.004)


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.01, 0.06)

	# Deep indigo ambient — light comes from the crystals, not the sky.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.15, 0.08, 0.28)
	environment.ambient_light_energy = 0.6

	# Thin ethereal mist — defines distance without obscuring crystal glow.
	environment.fog_enabled = true
	environment.fog_density = 0.012
	environment.fog_light_color = Color(0.08, 0.04, 0.14)
	environment.fog_sun_scatter = 0.0

	# Aggressive bloom — crystal emissives spill into the air.
	environment.glow_enabled = true
	environment.glow_intensity = 1.2
	environment.glow_strength = 1.6
	environment.glow_bloom = 0.28
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# Slightly desaturated — the beauty is off, something is wrong.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.9
	environment.adjustment_contrast = 1.15
	environment.adjustment_saturation = 0.78

	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.0

	env.environment = environment
	add_child(env)


func _add_floor(rng: RandomNumberGenerator) -> void:
	# Infinite-feeling ground — WorldBoundaryShape for physics, large plane visually.
	var static_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	static_body.add_child(col)
	add_child(static_body)

	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300.0, 300.0)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.04, 0.10)
	mat.roughness = 0.4
	mat.metallic = 0.2
	# Faint emissive so the floor catches crystal light.
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.02, 0.1)
	mat.emission_energy_multiplier = 0.3
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _add_crystals(rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(18, 32)
	for i: int in range(count):
		var color: Color = _CRYSTAL_COLORS[rng.randi_range(0, _CRYSTAL_COLORS.size() - 1)]
		var h: float = rng.randf_range(1.2, 5.5)
		var r: float = rng.randf_range(0.12, 0.35)
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(3.0, 32.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var tilt: float = rng.randf_range(-0.15, 0.15)

		# Crystal body — prism-like (cylinder with low radius-to-height).
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = h
		col.shape = shape
		body.position = pos + Vector3(0.0, h * 0.5, 0.0)
		body.rotation.z = tilt
		body.add_child(col)
		add_child(body)

		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = r * 0.08
		cyl.bottom_radius = r
		cyl.height = h
		mesh_inst.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(0.3)
		mat.roughness = 0.08
		mat.metallic = 0.6
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = rng.randf_range(0.6, 2.0)
		mesh_inst.material_override = mat
		mesh_inst.position = pos + Vector3(0.0, h * 0.5, 0.0)
		mesh_inst.rotation.z = tilt
		add_child(mesh_inst)

		# OmniLight at the crystal base — pools of colored light on the ground.
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = rng.randf_range(1.5, 3.5)
		light.omni_range = rng.randf_range(3.0, 7.0)
		light.position = pos + Vector3(0.0, 0.3, 0.0)
		add_child(light)


func _add_floating_orbs(rng: RandomNumberGenerator) -> void:
	for i: int in range(rng.randi_range(12, 20)):
		var color: Color = _CRYSTAL_COLORS[rng.randi_range(0, _CRYSTAL_COLORS.size() - 1)]
		var r: float = rng.randf_range(0.06, 0.18)
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(2.0, 18.0)
		var height: float = rng.randf_range(1.2, 5.0)

		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * 2.0
		mesh_inst.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = rng.randf_range(2.0, 5.0)
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		add_child(mesh_inst)

		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = rng.randf_range(0.8, 2.0)
		light.omni_range = rng.randf_range(2.0, 5.0)
		light.position = mesh_inst.position
		add_child(light)


func _add_sky_pillars(rng: RandomNumberGenerator) -> void:
	# Massive dark stone pillars reaching up — ruins of something ancient.
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.07, 0.06, 0.09)
	stone_mat.roughness = 0.9

	for i: int in range(rng.randi_range(4, 7)):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(10.0, 25.0)
		var h: float = rng.randf_range(8.0, 18.0)
		var w: float = rng.randf_range(1.2, 2.5)
		var pos := Vector3(cos(angle) * dist, h * 0.5, sin(angle) * dist)

		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, h, w)
		col.shape = shape
		body.position = pos
		body.add_child(col)
		add_child(body)

		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, h, w)
		mesh_inst.mesh = box
		mesh_inst.material_override = stone_mat
		mesh_inst.position = pos
		add_child(mesh_inst)


func _add_player_spawn() -> void:
	var spawn := Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.0, 0.0)
	add_child(spawn)


func _add_post_processing(strength: float) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/chromatic_aberration.gdshader") as Shader
	mat.set_shader_parameter(&"strength", strength)
	overlay.material = mat
	canvas.add_child(overlay)
	add_child(canvas)

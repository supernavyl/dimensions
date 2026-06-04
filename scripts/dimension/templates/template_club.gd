## TemplateClub — Arcane-aesthetic neon nightclub with an adjoining bathroom.
## build() is called by DimensionRoot after add_child(). data must be set first.
class_name TemplateClub
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData

const _ROOM_W: float = 22.0
const _ROOM_D: float = 20.0
const _ROOM_H: float = 5.0
const _BATH_W: float = 6.0
const _BATH_D: float = 5.0
const _BATH_H: float = 2.6
const _DOOR_W: float = 0.95  # narrow doorway — bathroom feels enclosed
const _DOOR_H: float = 2.05
const _LIGHT_COLORS: Array[Color] = [
	Color(0.0, 0.85, 1.0),   # cyan
	Color(1.0, 0.0, 0.72),   # hot pink
	Color(1.0, 0.68, 0.0),   # gold
	Color(0.62, 0.0, 1.0),   # violet
	Color(0.0, 1.0, 0.48),   # teal
	Color(1.0, 0.18, 0.0),   # red-orange
]


func build(rng: RandomNumberGenerator) -> void:
	_add_environment()
	_build_club_room()
	_build_bathroom()
	_place_pillars()
	_place_bar()
	_place_lights(rng)
	_place_particles(rng)
	_place_syringes(rng)
	_place_bottles(rng)
	_add_player_spawn()
	_add_post_processing(0.003)


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.02)

	# Near-black deep purple ambient — only the colored lights define space.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.02, 0.01, 0.04)
	environment.ambient_light_energy = 0.15

	# Purple-tinted exponential fog — carries the neon color.
	environment.fog_enabled = true
	environment.fog_density = 0.04
	environment.fog_light_color = Color(0.05, 0.01, 0.08)
	environment.fog_sun_scatter = 0.0

	# Heavy bloom — Arcane's signature neon bleed into atmosphere.
	environment.glow_enabled = true
	environment.glow_intensity = 1.0
	environment.glow_strength = 1.4
	environment.glow_bloom = 0.22
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Filmic tonemap — painterly crushed blacks, punchy highlights.
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# High contrast, slight boost on saturation for neon pop.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.65
	environment.adjustment_contrast = 1.3
	environment.adjustment_saturation = 0.82

	# SSAO — deep shadows in corners between lights.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 2.5

	env.environment = environment
	add_child(env)


func _build_club_room() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.04, 0.04, 0.05)
	floor_mat.roughness = 0.3
	floor_mat.metallic = 0.2

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.05, 0.03, 0.07)
	wall_mat.roughness = 0.9

	# Floor
	_add_box(Vector3(_ROOM_W, 0.2, _ROOM_D), Vector3(0.0, -0.1, 0.0), floor_mat)
	# Ceiling
	_add_box(Vector3(_ROOM_W, 0.2, _ROOM_D), Vector3(0.0, _ROOM_H + 0.1, 0.0), wall_mat)
	# +X wall
	_add_box(Vector3(0.2, _ROOM_H, _ROOM_D), Vector3(_ROOM_W * 0.5, _ROOM_H * 0.5, 0.0), wall_mat)
	# -X wall
	_add_box(Vector3(0.2, _ROOM_H, _ROOM_D), Vector3(-_ROOM_W * 0.5, _ROOM_H * 0.5, 0.0), wall_mat)
	# +Z wall (back wall behind bar)
	_add_box(Vector3(_ROOM_W, _ROOM_H, 0.2), Vector3(0.0, _ROOM_H * 0.5, _ROOM_D * 0.5), wall_mat)

	# -Z wall has a doorway to the bathroom: two side sections + lintel above door.
	var side_w: float = (_ROOM_W - _DOOR_W) * 0.5
	var side_cx: float = _ROOM_W * 0.5 - side_w * 0.5
	_add_box(Vector3(side_w, _ROOM_H, 0.2), Vector3(-side_cx, _ROOM_H * 0.5, -_ROOM_D * 0.5), wall_mat)
	_add_box(Vector3(side_w, _ROOM_H, 0.2), Vector3(side_cx, _ROOM_H * 0.5, -_ROOM_D * 0.5), wall_mat)
	# Lintel above door opening — sized to _DOOR_H so the doorway is shorter
	# than the bathroom ceiling and the bathroom feels properly enclosed.
	var lintel_h: float = _ROOM_H - _DOOR_H
	_add_box(Vector3(_DOOR_W, lintel_h, 0.2),
		Vector3(0.0, _DOOR_H + lintel_h * 0.5, -_ROOM_D * 0.5), wall_mat)


func _build_bathroom() -> void:
	var tile_mat := StandardMaterial3D.new()
	tile_mat.albedo_color = Color(0.42, 0.44, 0.46)
	tile_mat.roughness = 0.22
	tile_mat.metallic = 0.08

	var grout_mat := StandardMaterial3D.new()
	grout_mat.albedo_color = Color(0.18, 0.18, 0.19)
	grout_mat.roughness = 0.95

	# Bathroom origin: extends from z=-ROOM_D/2 to z=-(ROOM_D/2 + BATH_D)
	var bath_z: float = -_ROOM_D * 0.5 - _BATH_D * 0.5
	var back_wall_z: float = -_ROOM_D * 0.5 - _BATH_D

	# Floor
	_add_box(Vector3(_BATH_W, 0.2, _BATH_D), Vector3(0.0, -0.1, bath_z), grout_mat)
	# Ceiling
	_add_box(Vector3(_BATH_W, 0.2, _BATH_D), Vector3(0.0, _BATH_H + 0.1, bath_z), tile_mat)
	# Back wall
	_add_box(Vector3(_BATH_W, _BATH_H, 0.2),
		Vector3(0.0, _BATH_H * 0.5, back_wall_z), tile_mat)
	# Left wall
	_add_box(Vector3(0.2, _BATH_H, _BATH_D),
		Vector3(-_BATH_W * 0.5, _BATH_H * 0.5, bath_z), tile_mat)
	# Right wall
	_add_box(Vector3(0.2, _BATH_H, _BATH_D),
		Vector3(_BATH_W * 0.5, _BATH_H * 0.5, bath_z), tile_mat)

	# Stall divider — half-height wall splitting toilet area from sink area.
	var stall_mat := StandardMaterial3D.new()
	stall_mat.albedo_color = Color(0.32, 0.18, 0.14)
	stall_mat.roughness = 0.6
	_add_box(Vector3(0.08, 1.85, 2.6),
		Vector3(-1.4, 0.92, back_wall_z + 1.5), stall_mat)
	# Stall side wall (perpendicular short return)
	_add_box(Vector3(1.4, 1.85, 0.08),
		Vector3(-2.1, 0.92, back_wall_z + 2.8), stall_mat)

	# Sink — counter slab + basin cutout (counter against right back corner).
	var sink_mat := StandardMaterial3D.new()
	sink_mat.albedo_color = Color(0.62, 0.6, 0.58)
	sink_mat.roughness = 0.18
	sink_mat.metallic = 0.35
	_add_box(Vector3(2.4, 0.08, 0.55),
		Vector3(1.5, 0.92, back_wall_z + 0.31), sink_mat)
	# Sink basin (recessed darker box on top of counter)
	var basin_mat := StandardMaterial3D.new()
	basin_mat.albedo_color = Color(0.45, 0.43, 0.42)
	basin_mat.roughness = 0.4
	_add_box(Vector3(0.5, 0.04, 0.32),
		Vector3(1.5, 0.99, back_wall_z + 0.31), basin_mat)
	# Faucet
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.85, 0.86, 0.88)
	chrome.metallic = 0.95
	chrome.roughness = 0.08
	_add_box(Vector3(0.04, 0.18, 0.04),
		Vector3(1.5, 1.05, back_wall_z + 0.18), chrome)

	# Mirror over the sink — emissive dark rect with bright thin frame.
	var mirror_mat := StandardMaterial3D.new()
	mirror_mat.albedo_color = Color(0.05, 0.06, 0.08)
	mirror_mat.metallic = 0.9
	mirror_mat.roughness = 0.05
	mirror_mat.emission_enabled = true
	mirror_mat.emission = Color(0.15, 0.18, 0.22)
	mirror_mat.emission_energy_multiplier = 0.4
	_add_box(Vector3(1.0, 0.9, 0.04),
		Vector3(1.5, 1.55, back_wall_z + 0.06), mirror_mat)
	# Mirror frame — thin chrome border
	_add_box(Vector3(1.06, 0.04, 0.05),
		Vector3(1.5, 2.02, back_wall_z + 0.05), chrome)
	_add_box(Vector3(1.06, 0.04, 0.05),
		Vector3(1.5, 1.08, back_wall_z + 0.05), chrome)

	# Toilet behind the stall divider.
	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Color(0.78, 0.76, 0.74)
	porcelain.roughness = 0.15
	# Tank against back wall
	_add_box(Vector3(0.55, 0.7, 0.22),
		Vector3(-1.95, 0.55, back_wall_z + 0.16), porcelain)
	# Bowl
	_add_box(Vector3(0.5, 0.42, 0.62),
		Vector3(-1.95, 0.31, back_wall_z + 0.55), porcelain)
	# Seat
	_add_box(Vector3(0.5, 0.04, 0.62),
		Vector3(-1.95, 0.54, back_wall_z + 0.55), porcelain)

	# Trash can next to toilet.
	var trash_mat := StandardMaterial3D.new()
	trash_mat.albedo_color = Color(0.12, 0.11, 0.1)
	trash_mat.roughness = 0.7
	_add_box(Vector3(0.32, 0.5, 0.32),
		Vector3(-2.4, 0.25, back_wall_z + 1.1), trash_mat)

	# Door frame trim around the doorway, club side.
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.08, 0.05, 0.04)
	trim_mat.roughness = 0.65
	_add_box(Vector3(0.06, _DOOR_H, 0.06),
		Vector3(-_DOOR_W * 0.5, _DOOR_H * 0.5, -_ROOM_D * 0.5 - 0.02), trim_mat)
	_add_box(Vector3(0.06, _DOOR_H, 0.06),
		Vector3(_DOOR_W * 0.5, _DOOR_H * 0.5, -_ROOM_D * 0.5 - 0.02), trim_mat)
	_add_box(Vector3(_DOOR_W + 0.12, 0.06, 0.06),
		Vector3(0.0, _DOOR_H, -_ROOM_D * 0.5 - 0.02), trim_mat)

	# Hanging fluorescent fixture — long thin slab + emissive tube.
	var fixture_mat := StandardMaterial3D.new()
	fixture_mat.albedo_color = Color(0.18, 0.18, 0.18)
	fixture_mat.roughness = 0.7
	_add_box(Vector3(2.4, 0.08, 0.34),
		Vector3(0.0, _BATH_H - 0.04, bath_z + 0.4), fixture_mat)
	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = Color(0.95, 0.95, 0.92)
	tube_mat.emission_enabled = true
	tube_mat.emission = Color(0.95, 0.94, 0.85)
	tube_mat.emission_energy_multiplier = 4.0
	var tube := MeshInstance3D.new()
	var tube_mesh := BoxMesh.new()
	tube_mesh.size = Vector3(2.2, 0.04, 0.12)
	tube.mesh = tube_mesh
	tube.material_override = tube_mat
	tube.position = Vector3(0.0, _BATH_H - 0.1, bath_z + 0.4)
	tube.name = &"FluorescentTube"
	add_child(tube)

	# Bathroom light — dim, slightly warm, broken-fluorescent feel.
	var bath_light := OmniLight3D.new()
	bath_light.light_color = Color(0.95, 0.92, 0.82)
	bath_light.light_energy = 2.2
	bath_light.omni_range = 6.0
	bath_light.shadow_enabled = true
	bath_light.position = Vector3(0.0, _BATH_H - 0.18, bath_z + 0.4)
	bath_light.name = &"FluorescentLight"
	add_child(bath_light)

	# Flicker driver — randomly drops the tube emission + light energy.
	var flicker := _FluorescentFlicker.new()
	flicker.target_light = bath_light
	flicker.target_tube = tube
	flicker.tube_material = tube_mat
	flicker.base_energy = 2.2
	flicker.base_emission = 4.0
	add_child(flicker)


## Inline flicker driver — randomly dims the bathroom fluorescent.
class _FluorescentFlicker:
	extends Node

	var target_light: OmniLight3D
	var target_tube: MeshInstance3D
	var tube_material: StandardMaterial3D
	var base_energy: float = 2.0
	var base_emission: float = 4.0
	var _t: float = 0.0
	var _next: float = 0.4
	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()

	func _process(delta: float) -> void:
		_t += delta
		if _t < _next:
			return
		_t = 0.0
		# Most of the time light is healthy. ~22% chance we glitch.
		var roll: float = _rng.randf()
		if roll < 0.78:
			_set_intensity(1.0)
			_next = _rng.randf_range(1.4, 4.5)
		elif roll < 0.92:
			# Quick flicker dip
			_set_intensity(_rng.randf_range(0.15, 0.45))
			_next = _rng.randf_range(0.04, 0.12)
		else:
			# Full blackout for a beat
			_set_intensity(0.0)
			_next = _rng.randf_range(0.05, 0.18)

	func _set_intensity(k: float) -> void:
		if is_instance_valid(target_light):
			target_light.light_energy = base_energy * k
		if tube_material != null:
			tube_material.emission_energy_multiplier = base_emission * k


func _place_pillars() -> void:
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.07, 0.05, 0.09)
	pillar_mat.roughness = 0.8

	for px: float in [-7.0, 7.0]:
		for pz: float in [-6.0, 6.0]:
			_add_box(Vector3(0.5, _ROOM_H, 0.5),
				Vector3(px, _ROOM_H * 0.5, pz), pillar_mat)


func _place_bar() -> void:
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.08, 0.05, 0.03)
	bar_mat.roughness = 0.7
	bar_mat.metallic = 0.1

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.18, 0.12, 0.08)
	top_mat.roughness = 0.15
	top_mat.metallic = 0.4

	# Bar body
	_add_box(Vector3(14.0, 1.1, 0.65),
		Vector3(0.0, 0.55, _ROOM_D * 0.5 - 0.85), bar_mat)
	# Bar top surface
	_add_box(Vector3(14.2, 0.08, 0.75),
		Vector3(0.0, 1.14, _ROOM_D * 0.5 - 0.85), top_mat)


func _place_lights(rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(9, 12)
	for i: int in range(count):
		var light := OmniLight3D.new()
		light.light_color = _LIGHT_COLORS[rng.randi_range(0, _LIGHT_COLORS.size() - 1)]
		light.light_energy = rng.randf_range(5.0, 9.0)
		light.omni_range = rng.randf_range(6.0, 12.0)
		light.position = Vector3(
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(1.2, 4.0),
			rng.randf_range(-7.0, 8.0)
		)
		add_child(light)


func _place_particles(rng: RandomNumberGenerator) -> void:
	# Tiny emissive spheres floating in the air — Arcane magic-dust feel.
	for i: int in range(22):
		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.03, 0.07)
		sphere.height = sphere.radius * 2.0
		mesh_inst.mesh = sphere
		var mat := StandardMaterial3D.new()
		var color: Color = _LIGHT_COLORS[rng.randi_range(0, _LIGHT_COLORS.size() - 1)]
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = rng.randf_range(1.5, 4.0)
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(
			rng.randf_range(-9.0, 9.0),
			rng.randf_range(1.5, 4.2),
			rng.randf_range(-8.0, 8.5)
		)
		add_child(mesh_inst)


func _place_syringes(rng: RandomNumberGenerator) -> void:
	# Syringes on bathroom floor and near bar.
	var positions: Array[Vector3] = [
		Vector3(rng.randf_range(-2.0, 2.0), 0.02, -_ROOM_D * 0.5 - rng.randf_range(1.0, 4.0)),
		Vector3(rng.randf_range(-2.0, 2.0), 0.02, -_ROOM_D * 0.5 - rng.randf_range(1.0, 4.0)),
		Vector3(rng.randf_range(-5.0, 5.0), 0.02, _ROOM_D * 0.5 - 1.5),
	]
	for pos: Vector3 in positions:
		_add_syringe(pos, rng.randf_range(0.0, TAU))


func _add_syringe(pos: Vector3, rotation_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rotation_y
	root.rotation.z = 0.12

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.75, 0.8, 0.78)
	barrel_mat.roughness = 0.1
	barrel_mat.metallic = 0.5

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.014
	cyl.bottom_radius = 0.014
	cyl.height = 0.14
	body.mesh = cyl
	body.material_override = barrel_mat
	root.add_child(body)

	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color(0.85, 0.85, 0.88)
	needle_mat.roughness = 0.05
	needle_mat.metallic = 0.9

	var needle := MeshInstance3D.new()
	var ncyl := CylinderMesh.new()
	ncyl.top_radius = 0.002
	ncyl.bottom_radius = 0.005
	ncyl.height = 0.07
	needle.mesh = ncyl
	needle.material_override = needle_mat
	needle.position = Vector3(0.0, 0.105, 0.0)
	root.add_child(needle)

	add_child(root)


func _place_bottles(rng: RandomNumberGenerator) -> void:
	# Grabbable bottles on the bar surface — RigidBody3D so the interaction
	# handler can pick them up. 6-10 bottles randomised along the bar top.
	var count: int = rng.randi_range(6, 10)
	var bar_top_y: float = 1.22  # matches _place_bar top surface y
	var bar_z: float = _ROOM_D * 0.5 - 0.85

	for i: int in range(count):
		var bottle := RigidBody3D.new()
		bottle.mass = 0.4

		var col := CollisionShape3D.new()
		var cshape := CylinderShape3D.new()
		cshape.radius = 0.038
		cshape.height = 0.28
		col.shape = cshape
		bottle.add_child(col)

		# Bottle body
		var mat := StandardMaterial3D.new()
		var hue: float = rng.randf()
		mat.albedo_color = Color.from_hsv(hue, 0.7, 0.4)
		mat.roughness = 0.05
		mat.metallic = 0.1
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.55

		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.038
		cyl.height = 0.26
		mesh.mesh = cyl
		mesh.material_override = mat
		bottle.add_child(mesh)

		# Bottle neck
		var neck_mat := StandardMaterial3D.new()
		neck_mat.albedo_color = mat.albedo_color.darkened(0.1)
		neck_mat.roughness = 0.05
		neck_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		neck_mat.albedo_color.a = 0.55
		var neck := MeshInstance3D.new()
		var ncyl := CylinderMesh.new()
		ncyl.top_radius = 0.01
		ncyl.bottom_radius = 0.022
		ncyl.height = 0.09
		neck.mesh = ncyl
		neck.material_override = neck_mat
		neck.position = Vector3(0.0, 0.175, 0.0)
		bottle.add_child(neck)

		bottle.position = Vector3(
			rng.randf_range(-6.0, 6.0),
			bar_top_y + 0.14,
			bar_z
		)
		bottle.rotation.y = rng.randf_range(0.0, TAU)
		add_child(bottle)


func _add_player_spawn() -> void:
	# Player wakes up on the bathroom floor — the body they're in just overdosed.
	# Spawn between the stall divider and sink, facing the door.
	var bath_z: float = -_ROOM_D * 0.5 - _BATH_D * 0.5
	var spawn := Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.0, bath_z)
	add_child(spawn)

	# Syringe right at the player's feet — the one that killed the previous host.
	_add_syringe(Vector3(-0.4, 0.02, bath_z - 0.5), 0.6)
	# A second one — fell out of their hand the other way.
	_add_syringe(Vector3(0.35, 0.02, bath_z + 0.6), -1.4)


func _add_box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.position = pos
	body.add_child(col)
	add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = pos
	add_child(mesh_inst)


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

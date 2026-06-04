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
	_place_teacher_area()
	_add_player_spawn()
	_add_post_processing(0.001)


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.82, 0.81, 0.76)

	# Fluorescent ambient — slightly too warm, slightly wrong.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.95, 0.92, 0.82)
	environment.ambient_light_energy = 0.6

	# No fog — the mundane wrongness is clarity, not obscurity.
	environment.fog_enabled = false

	# Subtle glow — overexposed fluorescent look.
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_strength = 1.1
	environment.glow_bloom = 0.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES

	# Desaturated and slightly washed — clinical, wrong.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.55

	# SSAO — makes the room feel heavy despite bright lighting.
	environment.ssao_enabled = true
	environment.ssao_radius = 0.9
	environment.ssao_intensity = 1.4

	env.environment = environment
	add_child(env)


func _add_lighting() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.98, 0.92)
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	add_child(light)


func _add_floor() -> void:
	const W: float = 12.0
	const D: float = 9.0
	const H: float = 3.2

	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.88, 0.87, 0.83)

	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.72, 0.68, 0.60)

	# Floor
	_add_box(Vector3(W, 0.2, D), Vector3(0.0, -0.1, 0.0), floor_mat)
	# Ceiling
	_add_box(Vector3(W, 0.2, D), Vector3(0.0, H + 0.1, 0.0), wall_mat)
	# Walls
	_add_box(Vector3(W, H, 0.2), Vector3(0.0, H * 0.5, -D * 0.5), wall_mat)
	_add_box(Vector3(W, H, 0.2), Vector3(0.0, H * 0.5,  D * 0.5), wall_mat)
	_add_box(Vector3(0.2, H, D), Vector3(-W * 0.5, H * 0.5, 0.0), wall_mat)
	_add_box(Vector3(0.2, H, D), Vector3( W * 0.5, H * 0.5, 0.0), wall_mat)


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


func _place_desks(rng: RandomNumberGenerator) -> void:
	var rows: int = rng.randi_range(_ROWS_MIN, _ROWS_MAX)
	var cols: int = rng.randi_range(_COLS_MIN, _COLS_MAX)

	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.68, 0.62, 0.48)
	desk_mat.roughness = 0.8

	var chair_mat := StandardMaterial3D.new()
	chair_mat.albedo_color = Color(0.18, 0.18, 0.20)
	chair_mat.roughness = 0.9

	for r: int in range(rows):
		for c: int in range(cols):
			var desk_x: float = float(c) * 1.2 - float(cols) * 0.6
			var desk_z: float = float(r) * 1.5 - 3.0

			# Desk surface
			var desk := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(_DESK_W, _DESK_H, _DESK_D)
			desk.mesh = box
			desk.material_override = desk_mat
			desk.position = Vector3(desk_x, _DESK_HEIGHT_Y, desk_z)
			add_child(desk)

			# Chair — seat, back, 4 legs (all visual MeshInstance3D, matches desk style).
			var chair_seat := MeshInstance3D.new()
			var cseat := BoxMesh.new()
			cseat.size = Vector3(0.42, 0.04, 0.42)
			chair_seat.mesh = cseat
			chair_seat.material_override = chair_mat
			chair_seat.position = Vector3(desk_x, 0.46, desk_z + 0.48)
			add_child(chair_seat)

			var chair_back := MeshInstance3D.new()
			var cback := BoxMesh.new()
			cback.size = Vector3(0.42, 0.38, 0.04)
			chair_back.mesh = cback
			chair_back.material_override = chair_mat
			chair_back.position = Vector3(desk_x, 0.67, desk_z + 0.69)
			add_child(chair_back)

			for lx: float in [-0.17, 0.17]:
				for lz: float in [0.29, 0.67]:
					var leg := MeshInstance3D.new()
					var lmesh := BoxMesh.new()
					lmesh.size = Vector3(0.04, 0.46, 0.04)
					leg.mesh = lmesh
					leg.material_override = chair_mat
					leg.position = Vector3(desk_x + lx, 0.23, desk_z + lz)
					add_child(leg)


func _place_teacher_area() -> void:
	const W: float = 12.0
	const D: float = 9.0

	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.55, 0.48, 0.36)
	desk_mat.roughness = 0.75

	# Teacher's desk — larger, at the front of the room (-Z wall).
	_add_box(Vector3(1.6, 0.06, 0.7), Vector3(0.0, 0.76, -D * 0.5 + 1.2), desk_mat)
	# Desk body
	_add_box(Vector3(1.6, 0.72, 0.7), Vector3(0.0, 0.36, -D * 0.5 + 1.2), desk_mat)

	# Blackboard — emissive dark green panel on the front wall interior face.
	# Wall interior face is at z = -D/2 + 0.1; board depth 0.06 → center at -D/2 + 0.13.
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.10, 0.18, 0.12)
	board_mat.roughness = 0.95
	board_mat.emission_enabled = true
	board_mat.emission = Color(0.07, 0.12, 0.08)
	board_mat.emission_energy_multiplier = 0.4
	_add_box(Vector3(8.0, 1.4, 0.06), Vector3(0.0, 2.0, -D * 0.5 + 0.13), board_mat)

	# Chalk tray below board — thin ledge flush with board face.
	var tray_mat := StandardMaterial3D.new()
	tray_mat.albedo_color = Color(0.55, 0.52, 0.48)
	tray_mat.roughness = 0.7
	_add_box(Vector3(8.0, 0.06, 0.12), Vector3(0.0, 1.28, -D * 0.5 + 0.19), tray_mat)

	# Fluorescent ceiling strip lights — two rows.
	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = Color(0.95, 0.94, 0.88)
	tube_mat.emission_enabled = true
	tube_mat.emission = Color(0.95, 0.94, 0.88)
	tube_mat.emission_energy_multiplier = 3.5
	for strip_z: float in [-2.5, 2.5]:
		var tube := MeshInstance3D.new()
		var tmesh := BoxMesh.new()
		tmesh.size = Vector3(10.0, 0.06, 0.14)
		tube.mesh = tmesh
		tube.material_override = tube_mat
		tube.position = Vector3(0.0, 3.15, strip_z)
		add_child(tube)

		var strip_light := OmniLight3D.new()
		strip_light.light_color = Color(0.98, 0.96, 0.88)
		strip_light.light_energy = 2.8
		strip_light.omni_range = 8.0
		strip_light.position = Vector3(0.0, 3.0, strip_z)
		add_child(strip_light)


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

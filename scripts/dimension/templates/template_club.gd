## TemplateClub — dark nightclub dimension with colored lighting and fog.
## build() is called by DimensionRoot after add_child(). data must be set first.
class_name TemplateClub
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData

const _ROOM_W_MIN: float = 16.0
const _ROOM_W_MAX: float = 28.0
const _LIGHT_COUNT_MIN: int = 4
const _LIGHT_COUNT_MAX: int = 8
const _LIGHT_COLORS: Array[Color] = [
	Color(1.0, 0.0, 0.5),
	Color(0.0, 0.5, 1.0),
	Color(0.8, 0.0, 1.0),
	Color(1.0, 0.3, 0.0),
]


## Constructs the club dimension.
func build(rng: RandomNumberGenerator) -> void:
	_add_environment()
	_build_room(rng)
	_place_lights(rng)
	_add_player_spawn()


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.01, 0.04)
	environment.fog_enabled = true
	environment.fog_density = 0.06
	env.environment = environment
	add_child(env)


func _build_room(rng: RandomNumberGenerator) -> void:
	var w: float = rng.randf_range(_ROOM_W_MIN, _ROOM_W_MAX)
	var d: float = rng.randf_range(_ROOM_W_MIN, _ROOM_W_MAX)
	var h: float = 4.0

	# Floor
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_col: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(w, 0.2, d)
	floor_col.shape = floor_shape
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# Visual floor mesh
	var floor_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(w, 0.2, d)
	floor_mesh_inst.mesh = floor_mesh
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.05, 0.05, 0.06)
	floor_mesh_inst.material_override = floor_mat
	floor_mesh_inst.position = Vector3(0.0, -0.1, 0.0)
	add_child(floor_mesh_inst)

	# Ceiling collision (world boundary sufficient for walls)
	var ceiling: StaticBody3D = StaticBody3D.new()
	var ceiling_col: CollisionShape3D = CollisionShape3D.new()
	var ceiling_plane: WorldBoundaryShape3D = WorldBoundaryShape3D.new()
	ceiling_col.shape = ceiling_plane
	ceiling.position = Vector3(0.0, h, 0.0)
	ceiling.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	ceiling.add_child(ceiling_col)
	add_child(ceiling)


func _place_lights(rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(_LIGHT_COUNT_MIN, _LIGHT_COUNT_MAX)
	for i: int in range(count):
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = _LIGHT_COLORS[rng.randi_range(0, _LIGHT_COLORS.size() - 1)]
		light.light_energy = rng.randf_range(2.0, 6.0)
		light.omni_range = rng.randf_range(4.0, 10.0)
		light.position = Vector3(
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(2.5, 3.8),
			rng.randf_range(-8.0, 8.0)
		)
		add_child(light)


func _add_player_spawn() -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.0, 0.0)
	add_child(spawn)

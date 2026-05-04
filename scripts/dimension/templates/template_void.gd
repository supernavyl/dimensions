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
	_add_player_spawn()


func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = data.ambient_color if data != null else Color(0.05, 0.05, 0.07)
	environment.fog_enabled = true
	environment.fog_density = data.fog_density if data != null else 0.02
	env.environment = environment
	add_child(env)


func _add_floor() -> void:
	# Visual floor mesh
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	mesh_inst.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if data != null:
		mat.albedo_color = data.ambient_color.darkened(0.3)
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Collision floor
	var static_body: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = WorldBoundaryShape3D.new()
	static_body.add_child(col_shape)
	add_child(static_body)


func _add_player_spawn() -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.0, 0.0)
	add_child(spawn)

## DimensionManager — loads, unloads, and transitions between dimensions.
## Autoload: no class_name (collision with autoload node name).
extends Node

## Emitted after the new dimension scene is added and initialized.
signal dimension_loaded
## Emitted just before the current dimension is freed.
signal dimension_unloading

const _DIMENSION_ROOT_SCENE: String = "res://scenes/dimension/dimension_root.tscn"

var _current_dimension: Node3D = null
var _generator: DimensionGenerator = DimensionGenerator.new()

## Guards against re-entrant trigger_death calls.
var _dying: bool = false


## Loads and initializes the next procedural dimension.
## player is repositioned to PlayerSpawn after load.
func load_next_dimension(player: CharacterBody3D) -> void:
	if _current_dimension and is_instance_valid(_current_dimension):
		dimension_unloading.emit()
		_current_dimension.queue_free()
		_current_dimension = null

	var data: DimensionData = _generator.generate()
	var packed: PackedScene = load(_DIMENSION_ROOT_SCENE) as PackedScene
	if packed == null:
		push_error("DimensionManager: failed to load dimension_root.tscn")
		return

	_current_dimension = packed.instantiate() as Node3D
	if _current_dimension == null:
		push_error("DimensionManager: dimension_root.tscn root is not Node3D")
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		push_error("DimensionManager: no current_scene in tree")
		_current_dimension.queue_free()
		_current_dimension = null
		return

	scene_root.add_child(_current_dimension)

	var dim_root: DimensionRoot = _current_dimension as DimensionRoot
	if dim_root == null:
		push_error("DimensionManager: scene root does not have DimensionRoot script")
		_current_dimension.queue_free()
		_current_dimension = null
		return

	dim_root.initialize(data, player)
	dimension_loaded.emit()
	_dying = false


## Fires the death sequence. Calls load_next_dimension when complete.
## Re-entrant calls are swallowed via _dying latch.
func trigger_death(player: CharacterBody3D) -> void:
	if _dying:
		return
	_dying = true
	load_next_dimension(player)


## Returns the DimensionData for the active dimension, or null if none loaded.
func get_current_data() -> DimensionData:
	if _current_dimension == null or not is_instance_valid(_current_dimension):
		return null
	var dim_root: DimensionRoot = _current_dimension as DimensionRoot
	if dim_root == null:
		return null
	return dim_root.get_data()


## Returns the current dimension root node, or null.
func get_current_dimension() -> Node3D:
	return _current_dimension

## DimensionManager — loads, unloads, and transitions between dimensions.
## Autoload: no class_name (collision with autoload node name).
extends Node

## Emitted after the new dimension scene is added and initialized.
signal dimension_loaded
## Emitted just before the current dimension is freed.
signal dimension_unloading

const _DIMENSION_ROOT_SCENE: String = "res://scenes/dimension/dimension_root.tscn"
const _DEATH_SCENE: String = "res://scenes/death/death_sequence.tscn"

var _current_dimension: Node3D = null
var _generator: DimensionGenerator = DimensionGenerator.new()

## Guards against re-entrant trigger_death calls.
var _dying: bool = false


## Loads and initializes the next procedural dimension.
## player is repositioned to PlayerSpawn after load.
func load_next_dimension(player: CharacterBody3D) -> void:
	# Reset the dying latch at entry so all return paths (including error returns)
	# leave _dying in a clean state. Safe in single-threaded GDScript.
	_dying = false
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


## Fires the death sequence. Plays DeathSequence CanvasLayer, then calls
## load_next_dimension when the sequence finishes.
## Re-entrant calls are swallowed via _dying latch.
## cause is optional — null produces a silent slow fade.
func trigger_death(player: CharacterBody3D, cause: DeathCause = null) -> void:
	if _dying:
		return
	_dying = true
	_play_death_sequence(player, cause)


## Loads the DeathSequence scene, parents it to current_scene (NOT _current_dimension),
## and wires sequence_finished. Error paths call load_next_dimension directly so
## _dying always resets.
func _play_death_sequence(player: CharacterBody3D, cause: DeathCause) -> void:
	var packed: PackedScene = load(_DEATH_SCENE) as PackedScene
	if packed == null:
		push_error("DimensionManager: failed to load death_sequence.tscn — skipping sequence")
		load_next_dimension(player)
		return

	var seq: DeathSequence = packed.instantiate() as DeathSequence
	if seq == null:
		push_error("DimensionManager: death_sequence.tscn root is not DeathSequence")
		load_next_dimension(player)
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		push_error("DimensionManager: no current_scene for DeathSequence")
		load_next_dimension(player)
		return

	scene_root.add_child(seq)
	seq.sequence_finished.connect(_on_death_sequence_finished.bind(player, seq), CONNECT_ONE_SHOT)
	seq.play(cause)


## Called by sequence_finished (CONNECT_ONE_SHOT) when the fade completes.
## Frees the sequence node and loads the next dimension.
func _on_death_sequence_finished(player: CharacterBody3D, seq: DeathSequence) -> void:
	if is_instance_valid(seq):
		seq.queue_free()
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

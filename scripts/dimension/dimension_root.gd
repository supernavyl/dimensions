## DimensionRoot — base node for every procedural dimension scene.
## Owns the template instance and manages CompletionTracker lifecycle.
## CompletionTracker is instantiated in code (NOT baked in .tscn).
class_name DimensionRoot
extends Node3D

## Minimum spawn distance from the player in metres (ADR-007).
const _SPAWN_MIN_DIST: float = 2.0
## Candidate search radius in metres.
const _SPAWN_RADIUS: float = 6.0
## Maximum rejection-sampling attempts before falling back to radial placement.
const _SPAWN_MAX_TRIES: int = 16

## Lookup table mapping template_id StringName to template class.
const _TEMPLATES: Dictionary = {
	&"void": TemplateVoid,
	&"club": TemplateClub,
	&"classroom": TemplateClassroom,
}

var _data: DimensionData = null
var _tracker: CompletionTracker = null


## Initializes this dimension. NEXUS contract: signature is always
## (data: DimensionData, player: CharacterBody3D).
## Player is relocated to PlayerSpawn BEFORE NPC spawning so NPCs
## sample spawn positions relative to the correct player location.
func initialize(data: DimensionData, player: CharacterBody3D) -> void:
	_data = data

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _data.seed

	_build_template(rng)
	_setup_completion_tracker(data)

	# Relocate the player to the spawn point before NPCs sample positions.
	if player != null:
		player.global_position = get_player_spawn()

	_spawn_npcs(rng, player)


func _build_template(rng: RandomNumberGenerator) -> void:
	var template_id: StringName = _data.template_id
	var template_class: Variant = _TEMPLATES.get(template_id, TemplateVoid)
	if not _TEMPLATES.has(template_id):
		push_warning(
			"DimensionRoot: unknown template_id '%s', falling back to TemplateVoid" % template_id
		)

	# Class references in GDScript 4 are instantiated via .new() on the Variant.
	# template.set() and template.call() are used to avoid hard static typing here
	# since the exact subtype is resolved at runtime from the dictionary.
	var template: Node3D = template_class.new() as Node3D
	if template == null:
		push_error(
			"DimensionRoot: failed to instantiate template for id '%s'" % _data.template_id
		)
		return

	template.set(&"data", _data)
	add_child(template)
	template.call(&"build", rng)


func _setup_completion_tracker(data: DimensionData) -> void:
	_tracker = CompletionTracker.new()
	_tracker.threshold = data.survival_threshold
	add_child(_tracker)
	_tracker.dimension_completed.connect(_on_dimension_completed)


func _on_dimension_completed() -> void:
	GameState.record_completion()


## Spawns NPCs according to DimensionData.npc_count_min/max.
## Skips entirely if player is null (six existing tests pass null — must not crash).
func _spawn_npcs(rng: RandomNumberGenerator, player: CharacterBody3D) -> void:
	if player == null:
		push_warning("DimensionRoot: player is null — skipping NPC spawn")
		return

	var npc_container: Node3D = get_node_or_null("NPCContainer") as Node3D
	if npc_container == null:
		# Create the container at runtime so the .tscn does not require it baked in.
		npc_container = Node3D.new()
		npc_container.name = "NPCContainer"
		add_child(npc_container)

	var count: int = rng.randi_range(_data.npc_count_min, _data.npc_count_max)
	for i: int in range(count):
		var spawn_pos: Vector3 = _pick_safe_spawn(rng, player.global_position)
		var npc := NPCController.new()
		npc_container.add_child(npc)
		npc.global_position = spawn_pos
		var goal: NPCGoalGenerator.Goal = NPCGoalGenerator.generate(rng)
		npc.setup(goal, player, rng)
		# bind(player) passes player as the second argument to _on_npc_kill_range.
		npc.entered_kill_range.connect(_on_npc_kill_range.bind(player))


## Returns a spawn position at least _SPAWN_MIN_DIST from player_pos.
## Rejection-samples up to _SPAWN_MAX_TRIES; falls back to a radial push.
func _pick_safe_spawn(rng: RandomNumberGenerator, player_pos: Vector3) -> Vector3:
	for i: int in range(_SPAWN_MAX_TRIES):
		var offset_x: float = rng.randf_range(-_SPAWN_RADIUS, _SPAWN_RADIUS)
		var offset_z: float = rng.randf_range(-_SPAWN_RADIUS, _SPAWN_RADIUS)
		var candidate: Vector3 = Vector3(
			player_pos.x + offset_x,
			1.0,
			player_pos.z + offset_z
		)
		if candidate.distance_to(player_pos) >= _SPAWN_MIN_DIST:
			return candidate

	# Fallback: push radially outward at a deterministic angle so every NPC
	# in the same frame gets a distinct position.
	var fallback_angle: float = rng.randf_range(0.0, TAU)
	return Vector3(
		player_pos.x + _SPAWN_MIN_DIST * cos(fallback_angle),
		1.0,
		player_pos.z + _SPAWN_MIN_DIST * sin(fallback_angle)
	)


## Callback connected to each NPC's entered_kill_range signal.
## Fires DimensionManager.trigger_death(player). Re-entrant calls are swallowed
## by DimensionManager's _dying latch (ADR-001).
func _on_npc_kill_range(_npc: NPCController, player: CharacterBody3D) -> void:
	DimensionManager.trigger_death(player)


## Returns the world position of the PlayerSpawn Marker3D, or Vector3.ZERO.
func get_player_spawn() -> Vector3:
	var spawn: Marker3D = find_child("PlayerSpawn", true, false) as Marker3D
	if spawn == null:
		push_warning("DimensionRoot: no PlayerSpawn Marker3D found in dimension")
		return Vector3.ZERO
	return spawn.global_position


## Returns the DimensionData for this dimension.
func get_data() -> DimensionData:
	return _data

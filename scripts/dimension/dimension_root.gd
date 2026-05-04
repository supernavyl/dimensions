## DimensionRoot — base node for every procedural dimension scene.
## Owns the template instance and manages CompletionTracker lifecycle.
## CompletionTracker is instantiated in code (NOT baked in .tscn).
class_name DimensionRoot
extends Node3D

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
## player is wired in Phase 3 for NPC spawning; retained here for contract compliance.
func initialize(data: DimensionData, player: CharacterBody3D) -> void:
	_data = data

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _data.seed

	_build_template(rng)
	_setup_completion_tracker(data)

	# Phase 3 wires _spawn_npcs(rng, player) here.
	# player param retained per NEXUS contract — used in Phase 3 NPC spawning.
	# The parameter is intentionally unused in Phase 2.
	pass


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

## CauseRule — dimension-specific hidden rule that kills the player after a timer
## elapses or when the player enters a forbidden zone.
## Instantiated by DimensionRoot.initialize() when data.rule_id != &"".
## Added as a child of DimensionRoot so it is freed with the dimension.
## Unregisters its cause from DeathManager in _exit_tree().
class_name CauseRule
extends Node

## Key for the timer duration parameter in DimensionData.rule_param.
const PARAM_TIMER: StringName = &"timer"
## Key for the forbidden AABB zone parameter in DimensionData.rule_param.
const PARAM_ZONE: StringName = &"zone"

@export var rule_id: StringName = &""
@export var trigger_after_seconds: float = 0.0
@export var forbidden_zone: AABB = AABB()

var _timer: float = 0.0
var _death_manager: DeathManager = null
var _player: CharacterBody3D = null


## Sets up this rule from DimensionData. Must be called after add_child().
func setup(player: CharacterBody3D, dm: DeathManager, data: DimensionData) -> void:
	_player = player
	_death_manager = dm

	# Read parameters from DimensionData.rule_param.
	trigger_after_seconds = float(data.rule_param.get(PARAM_TIMER, 0.0))
	forbidden_zone = data.rule_param.get(PARAM_ZONE, AABB()) as AABB

	# Use data.rule_id as the cause identifier; fall back to generic.
	if data.rule_id != &"":
		rule_id = data.rule_id
	else:
		rule_id = &"rule_generic"

	var rule_cause := DeathCause.new()
	rule_cause.cause_id = rule_id
	rule_cause.is_silent = true
	rule_cause.blood_intensity = 0.3
	dm.register_cause(rule_cause)

	# Warn early if neither condition is active — rule will never fire.
	if trigger_after_seconds <= 0.0 and forbidden_zone.size == Vector3.ZERO:
		push_warning(
			"CauseRule: rule_id '%s' has no active condition (timer <= 0 and zone is empty) — rule will never fire" % rule_id
		)


## Unregisters this rule's cause when the node exits the tree (dimension freed).
func _exit_tree() -> void:
	if _death_manager != null:
		_death_manager.unregister_cause(rule_id)


func _physics_process(delta: float) -> void:
	if _player == null or _death_manager == null:
		return

	# Timer condition.
	if trigger_after_seconds > 0.0:
		_timer += delta
		if _timer >= trigger_after_seconds:
			_death_manager.trigger(rule_id)
			return

	# Zone condition: player position inside forbidden AABB.
	# No local latch needed: CauseRule is freed by queue_free at end-of-frame,
	# so _physics_process cannot run again after the dimension transitions.
	# DeathManager._triggered absorbs same-frame double-fire if timer and zone both fire.
	if forbidden_zone.size != Vector3.ZERO:
		if forbidden_zone.has_point(_player.global_position):
			_death_manager.trigger(rule_id)

## BTThreaten — leaf node: enter the player's personal space and hold position.
## Moves close to the target then oscillates in place to simulate threat presence.
## Returns RUNNING indefinitely (goal = maintain pressure, not complete).
## Writes actor.velocity only — NEVER calls move_and_slide().
class_name BTThreaten
extends BTNode

## Distance in metres at which the NPC stops advancing and holds. Always set by NPCController.setup().
var threat_distance: float = 0.8
## Speed in m/s while closing distance. Always set by NPCController.setup().
var approach_speed: float = 2.0
## Drift speed once in threat range (slow orbit to avoid static stall).
@export var drift_speed: float = 0.4

## Target node set by NPCController.setup().
var target: Node3D = null

var _rng: RandomNumberGenerator = null
var _drift_dir: Vector3 = Vector3.ZERO
var _drift_timer: float = 0.0
const _DRIFT_CHANGE_INTERVAL: float = 1.2


## Called by NPCController.setup() to supply the seeded RNG.
func init_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_pick_drift_dir()


func _tick(actor: CharacterBody3D, delta: float) -> Status:
	if target == null or not is_instance_valid(target):
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		return Status.FAILURE

	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_pick_drift_dir()

	var to_target: Vector3 = target.global_position - actor.global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	if dist > threat_distance:
		# Advance toward the target.
		var direction: Vector3 = to_target / dist
		actor.velocity.x = direction.x * approach_speed
		actor.velocity.z = direction.z * approach_speed
	else:
		# Hold and drift — change drift direction periodically.
		_drift_timer += delta
		if _drift_timer >= _DRIFT_CHANGE_INTERVAL:
			_drift_timer = 0.0
			_pick_drift_dir()
		actor.velocity.x = _drift_dir.x * drift_speed
		actor.velocity.z = _drift_dir.z * drift_speed

	return Status.RUNNING


func _pick_drift_dir() -> void:
	if _rng == null:
		return
	var angle: float = _rng.randf_range(0.0, TAU)
	_drift_dir = Vector3(cos(angle), 0.0, sin(angle))

## BTWander — leaf node: wander to a random position within wander_radius.
## Picks a new target when within arrival_distance or on first tick.
## Writes actor.velocity only — NEVER calls move_and_slide().
class_name BTWander
extends BTNode

## Radius in metres within which wander targets are chosen. Always set by NPCController.setup().
var wander_radius: float = 5.0
## Speed in m/s while wandering. Always set by NPCController.setup().
var move_speed: float = 1.5
## Distance at which the current target is considered reached. Always set by NPCController.setup().
var arrival_distance: float = 0.5

var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _rng: RandomNumberGenerator = null


## Called by NPCController.setup() to supply the seeded RNG.
func init_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func _tick(actor: CharacterBody3D, delta: float) -> Status:
	if _rng == null:
		_rng = RandomNumberGenerator.new()

	var pos: Vector3 = actor.global_position

	if not _has_target or pos.distance_to(_target) <= arrival_distance:
		var offset_x: float = _rng.randf_range(-wander_radius, wander_radius)
		var offset_z: float = _rng.randf_range(-wander_radius, wander_radius)
		_target = Vector3(pos.x + offset_x, pos.y, pos.z + offset_z)
		_has_target = true

	var direction: Vector3 = (_target - pos)
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		actor.velocity.x = direction.x * move_speed
		actor.velocity.z = direction.z * move_speed
	else:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0

	# Gravity handled by NPCController — wander only sets horizontal velocity.
	return Status.RUNNING

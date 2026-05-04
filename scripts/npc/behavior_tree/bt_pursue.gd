## BTPursue — leaf node: move toward a target node until within stop_distance.
## Returns SUCCESS when within stop_distance, RUNNING otherwise.
## Writes actor.velocity only — NEVER calls move_and_slide().
class_name BTPursue
extends BTNode

## Distance in metres at which pursuit is considered complete. Always set by NPCController.setup().
var stop_distance: float = 1.2
## Speed in m/s while pursuing. Always set by NPCController.setup().
var move_speed: float = 2.5

## Target node set by NPCController.setup(). Must be valid for this node to run.
var target: Node3D = null


func _tick(actor: CharacterBody3D, _delta: float) -> Status:
	if target == null or not is_instance_valid(target):
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		return Status.FAILURE

	var to_target: Vector3 = target.global_position - actor.global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	if dist <= stop_distance:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		return Status.SUCCESS

	var direction: Vector3 = to_target / dist
	actor.velocity.x = direction.x * move_speed
	actor.velocity.z = direction.z * move_speed
	return Status.RUNNING

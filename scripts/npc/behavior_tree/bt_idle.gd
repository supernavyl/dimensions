## BTIdle — leaf node: stand still for a fixed duration then return SUCCESS.
## Writes actor.velocity.x/z to zero. Does not call move_and_slide().
class_name BTIdle
extends BTNode

## Duration to remain idle in seconds. Always set by NPCController.setup() — not inspector-editable.
var duration: float = 2.0

var _elapsed: float = 0.0
var _started: bool = false


func _tick(actor: CharacterBody3D, delta: float) -> Status:
	if not _started:
		_elapsed = 0.0
		_started = true

	# Zero horizontal velocity — NPC stands still while idle.
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0

	_elapsed += delta
	if _elapsed >= duration:
		_started = false
		return Status.SUCCESS

	return Status.RUNNING

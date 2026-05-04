## BTSelector — composite that ticks children left-to-right.
## Returns SUCCESS on the first child that returns SUCCESS or RUNNING.
## Returns FAILURE only when all children return FAILURE.
class_name BTSelector
extends BTNode


func _tick(actor: CharacterBody3D, delta: float) -> Status:
	for child: Node in get_children():
		if not child is BTNode:
			continue
		var result: Status = (child as BTNode).tick(actor, delta)
		if result != Status.FAILURE:
			return result
	return Status.FAILURE

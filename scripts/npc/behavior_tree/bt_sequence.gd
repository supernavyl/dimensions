## BTSequence — composite that ticks children left-to-right.
## Returns SUCCESS only when all children return SUCCESS.
## Returns FAILURE on the first child that returns FAILURE.
## Returns RUNNING when a child returns RUNNING (stops ticking remaining siblings).
class_name BTSequence
extends BTNode


func _tick(actor: CharacterBody3D, delta: float) -> Status:
	for child: Node in get_children():
		if not child is BTNode:
			continue
		var result: Status = (child as BTNode).tick(actor, delta)
		if result != Status.SUCCESS:
			return result
	return Status.SUCCESS

## BTNode — abstract base for all behavior tree nodes.
## Subclasses implement _tick(actor, delta) and return a Status.
## Test hook: set meta(&"_test_result") to a Status int to override _tick.
class_name BTNode
extends Node

## Return values for tick().
enum Status {
	SUCCESS = 0,
	FAILURE = 1,
	RUNNING = 2,
}


## Ticks this node. Returns the test-hook result if the meta key is present,
## otherwise delegates to _tick(actor, delta).
func tick(actor: CharacterBody3D, delta: float) -> Status:
	if has_meta(&"_test_result"):
		return get_meta(&"_test_result") as Status
	return _tick(actor, delta)


## Override in subclasses. Default returns FAILURE so unimplemented nodes
## are safe in a composite.
func _tick(_actor: CharacterBody3D, _delta: float) -> Status:
	return Status.FAILURE

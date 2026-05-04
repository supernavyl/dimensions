## CompletionTracker — hidden survival timer.
## Instantiated programmatically in DimensionRoot.initialize() — NOT baked in .tscn.
## Emits dimension_completed once when _elapsed >= threshold.
class_name CompletionTracker
extends Node

## Emitted once when survival threshold is reached.
signal dimension_completed

## Survival threshold in seconds. Set from DimensionData.survival_threshold.
@export var threshold: float = 120.0

## Accumulated time since this tracker was added to the scene tree.
var _elapsed: float = 0.0
var _completed: bool = false


func _process(delta: float) -> void:
	if _completed:
		return
	_elapsed += delta
	_check_completion()


## Checks whether the elapsed time has met the threshold.
## Called from _process and exposed for test injection.
func _check_completion() -> void:
	if not _completed and _elapsed >= threshold:
		_completed = true
		dimension_completed.emit()


## Returns true when the dimension has been silently completed.
func is_complete() -> bool:
	return _completed

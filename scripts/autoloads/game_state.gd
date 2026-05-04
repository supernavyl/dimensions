## GameState — global completion tracking and final event gating.
## Autoload: no class_name (collision with autoload node name).
extends Node

## Emitted each time a dimension is completed. Carries running total.
signal dimension_completed(total: int)
## Emitted once when the required number of dimensions have been completed.
signal final_event_triggered

## Number of dimensions the player must complete to trigger the final event.
const DIMENSIONS_TO_FINAL: int = 7

## Running total of completed dimensions.
var completed_count: int = 0

var _final_triggered: bool = false


## Records one dimension completion. Fires final_event_triggered when threshold met.
func record_completion() -> void:
	completed_count += 1
	dimension_completed.emit(completed_count)
	if completed_count >= DIMENSIONS_TO_FINAL and not _final_triggered:
		_final_triggered = true
		final_event_triggered.emit()

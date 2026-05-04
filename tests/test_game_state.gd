## Tests for GameState autoload — record_completion() and final event gating.
extends GutTest

var _gs: Node  # fresh instance, NOT the autoload singleton

func before_each() -> void:
	_gs = load("res://scripts/autoloads/game_state.gd").new()
	add_child_autofree(_gs)

func test_initial_count_is_zero() -> void:
	assert_eq(_gs.completed_count, 0)

func test_single_completion_increments_count() -> void:
	_gs.record_completion()
	assert_eq(_gs.completed_count, 1)

func test_dimension_completed_signal_carries_total() -> void:
	watch_signals(_gs)
	_gs.record_completion()
	assert_signal_emitted_with_parameters(_gs, "dimension_completed", [1])

func test_final_event_fires_at_threshold() -> void:
	watch_signals(_gs)
	for i: int in range(_gs.DIMENSIONS_TO_FINAL):
		_gs.record_completion()
	assert_signal_emitted(_gs, "final_event_triggered")

func test_final_event_fires_exactly_once() -> void:
	watch_signals(_gs)
	for i: int in range(_gs.DIMENSIONS_TO_FINAL + 5):
		_gs.record_completion()
	assert_signal_emit_count(_gs, "final_event_triggered", 1)

func test_final_event_not_fired_below_threshold() -> void:
	watch_signals(_gs)
	for i: int in range(_gs.DIMENSIONS_TO_FINAL - 1):
		_gs.record_completion()
	assert_signal_not_emitted(_gs, "final_event_triggered")

func test_count_continues_past_threshold() -> void:
	for i: int in range(_gs.DIMENSIONS_TO_FINAL + 3):
		_gs.record_completion()
	assert_eq(_gs.completed_count, _gs.DIMENSIONS_TO_FINAL + 3)

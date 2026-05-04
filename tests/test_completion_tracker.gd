## Tests for CompletionTracker — threshold boundary, signal latch, is_complete().
extends GutTest

var _tracker: CompletionTracker

func before_each() -> void:
	_tracker = CompletionTracker.new()
	add_child_autofree(_tracker)

func test_not_complete_at_start() -> void:
	assert_false(_tracker.is_complete())

func test_elapsed_zero_does_not_complete() -> void:
	_tracker.threshold = 10.0
	_tracker._check_completion()
	assert_false(_tracker.is_complete())

func test_exact_threshold_completes() -> void:
	_tracker.threshold = 10.0
	_tracker._elapsed = 10.0
	_tracker._check_completion()
	assert_true(_tracker.is_complete())

func test_over_threshold_completes() -> void:
	_tracker.threshold = 10.0
	_tracker._elapsed = 100.0
	_tracker._check_completion()
	assert_true(_tracker.is_complete())

func test_dimension_completed_signal_emitted() -> void:
	watch_signals(_tracker)
	_tracker.threshold = 1.0
	_tracker._elapsed = 1.0
	_tracker._check_completion()
	assert_signal_emitted(_tracker, "dimension_completed")

func test_signal_only_emitted_once() -> void:
	watch_signals(_tracker)
	_tracker.threshold = 1.0
	_tracker._elapsed = 1.0
	_tracker._check_completion()
	_tracker._check_completion()
	_tracker._check_completion()
	assert_signal_emit_count(_tracker, "dimension_completed", 1)

func test_is_complete_returns_true_after_signal() -> void:
	_tracker.threshold = 5.0
	_tracker._elapsed = 10.0
	_tracker._check_completion()
	assert_true(_tracker.is_complete())

func test_threshold_zero_completes_immediately() -> void:
	_tracker.threshold = 0.0
	_tracker._elapsed = 0.0
	_tracker._check_completion()
	assert_true(_tracker.is_complete())

func test_process_not_running_after_complete() -> void:
	_tracker.threshold = 1.0
	_tracker._elapsed = 1.0
	_tracker._check_completion()
	var elapsed_after: float = _tracker._elapsed
	_tracker._process(999.0)
	assert_eq(_tracker._elapsed, elapsed_after)

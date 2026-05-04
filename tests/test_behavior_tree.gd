## Tests for BTSequence and BTSelector composites.
## Uses the meta(&"_test_result") hook to stub leaf results without
## real CharacterBody3D physics.
extends GutTest

## Minimal fake actor — we only need the interface, not physics.
var _actor: CharacterBody3D


func before_each() -> void:
	_actor = CharacterBody3D.new()
	add_child_autofree(_actor)


## Helper: create a BTNode stub whose tick() always returns the given status.
func _make_stub(status: BTNode.Status) -> BTNode:
	var node := BTNode.new()
	node.set_meta(&"_test_result", status)
	return node


# ---------------------------------------------------------------------------
# BTSequence
# ---------------------------------------------------------------------------

func test_sequence_all_success_returns_success() -> void:
	var seq := BTSequence.new()
	add_child_autofree(seq)
	seq.add_child(_make_stub(BTNode.Status.SUCCESS))
	seq.add_child(_make_stub(BTNode.Status.SUCCESS))
	assert_eq(seq.tick(_actor, 0.016), BTNode.Status.SUCCESS)


func test_sequence_first_failure_returns_failure() -> void:
	var seq := BTSequence.new()
	add_child_autofree(seq)
	seq.add_child(_make_stub(BTNode.Status.FAILURE))
	seq.add_child(_make_stub(BTNode.Status.SUCCESS))
	assert_eq(seq.tick(_actor, 0.016), BTNode.Status.FAILURE)


func test_sequence_running_child_short_circuits() -> void:
	var seq := BTSequence.new()
	add_child_autofree(seq)
	seq.add_child(_make_stub(BTNode.Status.RUNNING))
	# Second child would return FAILURE but should never be reached.
	seq.add_child(_make_stub(BTNode.Status.FAILURE))
	assert_eq(seq.tick(_actor, 0.016), BTNode.Status.RUNNING)


func test_sequence_empty_returns_success() -> void:
	var seq := BTSequence.new()
	add_child_autofree(seq)
	assert_eq(seq.tick(_actor, 0.016), BTNode.Status.SUCCESS)


func test_sequence_second_failure_after_success_returns_failure() -> void:
	var seq := BTSequence.new()
	add_child_autofree(seq)
	seq.add_child(_make_stub(BTNode.Status.SUCCESS))
	seq.add_child(_make_stub(BTNode.Status.FAILURE))
	assert_eq(seq.tick(_actor, 0.016), BTNode.Status.FAILURE)


# ---------------------------------------------------------------------------
# BTSelector
# ---------------------------------------------------------------------------

func test_selector_first_success_returns_success() -> void:
	var sel := BTSelector.new()
	add_child_autofree(sel)
	sel.add_child(_make_stub(BTNode.Status.SUCCESS))
	sel.add_child(_make_stub(BTNode.Status.FAILURE))
	assert_eq(sel.tick(_actor, 0.016), BTNode.Status.SUCCESS)


func test_selector_all_failure_returns_failure() -> void:
	var sel := BTSelector.new()
	add_child_autofree(sel)
	sel.add_child(_make_stub(BTNode.Status.FAILURE))
	sel.add_child(_make_stub(BTNode.Status.FAILURE))
	assert_eq(sel.tick(_actor, 0.016), BTNode.Status.FAILURE)


func test_selector_running_short_circuits() -> void:
	var sel := BTSelector.new()
	add_child_autofree(sel)
	sel.add_child(_make_stub(BTNode.Status.RUNNING))
	# Second child would return SUCCESS but should not be reached.
	sel.add_child(_make_stub(BTNode.Status.SUCCESS))
	assert_eq(sel.tick(_actor, 0.016), BTNode.Status.RUNNING)


func test_selector_empty_returns_failure() -> void:
	var sel := BTSelector.new()
	add_child_autofree(sel)
	assert_eq(sel.tick(_actor, 0.016), BTNode.Status.FAILURE)


func test_selector_skips_failure_and_returns_first_success() -> void:
	var sel := BTSelector.new()
	add_child_autofree(sel)
	sel.add_child(_make_stub(BTNode.Status.FAILURE))
	sel.add_child(_make_stub(BTNode.Status.FAILURE))
	sel.add_child(_make_stub(BTNode.Status.SUCCESS))
	assert_eq(sel.tick(_actor, 0.016), BTNode.Status.SUCCESS)


# ---------------------------------------------------------------------------
# BTNode test hook
# ---------------------------------------------------------------------------

func test_bt_node_test_hook_overrides_tick() -> void:
	var node := BTNode.new()
	add_child_autofree(node)
	node.set_meta(&"_test_result", BTNode.Status.SUCCESS)
	assert_eq(node.tick(_actor, 0.016), BTNode.Status.SUCCESS)


func test_bt_node_without_hook_returns_failure() -> void:
	var node := BTNode.new()
	add_child_autofree(node)
	assert_eq(node.tick(_actor, 0.016), BTNode.Status.FAILURE)

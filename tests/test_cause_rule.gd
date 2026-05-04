## Tests for CauseRule — timer condition, zone condition, registration, cleanup.
extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_dm() -> DeathManager:
	var dm := DeathManager.new()
	add_child_autofree(dm)
	return dm


func _make_player() -> CharacterBody3D:
	var p := CharacterBody3D.new()
	add_child_autofree(p)
	return p


func _make_data(rule_id: StringName = &"test_rule", timer: float = 0.0, zone: AABB = AABB()) -> DimensionData:
	var d := DimensionData.new()
	d.rule_id = rule_id
	d.template_id = &"void"
	d.seed = 1
	d.survival_threshold = 120.0
	d.npc_count_min = 1
	d.npc_count_max = 1
	d.gravity_scale = 1.0
	d.fog_density = 0.0
	d.ambient_color = Color.BLACK
	if timer > 0.0:
		d.rule_param[CauseRule.PARAM_TIMER] = timer
	if zone.size != Vector3.ZERO:
		d.rule_param[CauseRule.PARAM_ZONE] = zone
	return d


func _make_rule() -> CauseRule:
	var r := CauseRule.new()
	add_child_autofree(r)
	return r


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

func test_setup_registers_cause_with_rule_id() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	var data := _make_data(&"my_rule", 30.0)
	r.setup(_make_player(), dm, data)

	var count_before_setup: int = 2  # npc (pre-reg) + our cause
	assert_eq(dm.cause_count(), count_before_setup)


func test_setup_registered_cause_is_silent() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"silent_rule", 10.0))

	watch_signals(dm)
	dm.trigger(&"silent_rule")
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_true((args[0] as DeathCause).is_silent)


func test_setup_registered_cause_has_low_blood_intensity() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"quiet_rule", 10.0))

	watch_signals(dm)
	dm.trigger(&"quiet_rule")
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).blood_intensity, 0.3)


func test_setup_falls_back_to_rule_generic_when_rule_id_empty() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	var data := _make_data(&"", 5.0)  # empty rule_id
	r.setup(_make_player(), dm, data)

	assert_eq(r.rule_id, &"rule_generic")


func test_setup_uses_provided_rule_id() -> void:
	var r := _make_rule()
	var data := _make_data(&"dimension_3_curse", 5.0)
	r.setup(_make_player(), _make_dm(), data)
	assert_eq(r.rule_id, &"dimension_3_curse")


# ---------------------------------------------------------------------------
# Parameter parsing
# ---------------------------------------------------------------------------

func test_setup_reads_timer_from_rule_param() -> void:
	var r := _make_rule()
	r.setup(_make_player(), _make_dm(), _make_data(&"timer_rule", 42.5))
	assert_eq(r.trigger_after_seconds, 42.5)


func test_setup_reads_zone_from_rule_param() -> void:
	var zone := AABB(Vector3(1.0, 0.0, 1.0), Vector3(5.0, 3.0, 5.0))
	var r := _make_rule()
	r.setup(_make_player(), _make_dm(), _make_data(&"zone_rule", 0.0, zone))
	assert_eq(r.forbidden_zone, zone)


func test_setup_defaults_timer_to_zero_when_param_absent() -> void:
	var r := _make_rule()
	r.setup(_make_player(), _make_dm(), _make_data(&"no_timer"))
	assert_eq(r.trigger_after_seconds, 0.0)


func test_setup_defaults_zone_to_empty_when_param_absent() -> void:
	var r := _make_rule()
	r.setup(_make_player(), _make_dm(), _make_data(&"no_zone"))
	assert_eq(r.forbidden_zone, AABB())


# ---------------------------------------------------------------------------
# Timer condition
# ---------------------------------------------------------------------------

func test_timer_does_not_fire_before_threshold() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"timer_rule", 10.0))

	watch_signals(dm)
	# Accumulate 9.9 seconds — just under threshold.
	r._physics_process(9.9)
	assert_signal_not_emitted(dm, "player_died")


func test_timer_fires_exactly_at_threshold() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"timer_rule", 10.0))

	watch_signals(dm)
	r._physics_process(10.0)
	assert_signal_emitted(dm, "player_died")


func test_timer_fires_beyond_threshold() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"timer_rule", 5.0))

	watch_signals(dm)
	# A single large delta that overshoots the threshold.
	r._physics_process(999.0)
	assert_signal_emitted(dm, "player_died")


func test_timer_carries_correct_rule_id_in_cause() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"curse_of_time", 5.0))

	watch_signals(dm)
	r._physics_process(5.0)
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).cause_id, &"curse_of_time")


func test_timer_increments_across_multiple_frames() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	r.setup(_make_player(), dm, _make_data(&"timer_rule", 3.0))

	watch_signals(dm)
	r._physics_process(1.0)
	r._physics_process(1.0)
	# Still under threshold after 2s.
	assert_signal_not_emitted(dm, "player_died")
	r._physics_process(1.0)
	# Exactly 3.0 — should fire now.
	assert_signal_emitted(dm, "player_died")


func test_timer_does_not_fire_when_trigger_after_seconds_is_zero() -> void:
	# timer condition is disabled when trigger_after_seconds <= 0.
	var dm := _make_dm()
	var r := _make_rule()
	# No timer param — trigger_after_seconds defaults to 0.0.
	r.setup(_make_player(), dm, _make_data(&"no_timer_rule"))

	watch_signals(dm)
	r._physics_process(9999.0)
	assert_signal_not_emitted(dm, "player_died")


# ---------------------------------------------------------------------------
# Zone condition
# ---------------------------------------------------------------------------

func test_zone_triggers_death_when_player_inside() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	var zone := AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0))
	var player := _make_player()
	r.setup(player, dm, _make_data(&"zone_rule", 0.0, zone))

	player.global_position = Vector3(0.0, 0.0, 0.0)  # inside zone

	watch_signals(dm)
	r._physics_process(0.016)
	assert_signal_emitted(dm, "player_died")


func test_zone_does_not_trigger_when_player_outside() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	var zone := AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0))
	var player := _make_player()
	r.setup(player, dm, _make_data(&"zone_rule", 0.0, zone))

	player.global_position = Vector3(100.0, 0.0, 0.0)  # far outside zone

	watch_signals(dm)
	r._physics_process(0.016)
	assert_signal_not_emitted(dm, "player_died")


func test_zone_carries_correct_rule_id_in_cause() -> void:
	var dm := _make_dm()
	var r := _make_rule()
	var zone := AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0))
	var player := _make_player()
	r.setup(player, dm, _make_data(&"forbidden_zone_curse", 0.0, zone))

	player.global_position = Vector3.ZERO
	watch_signals(dm)
	r._physics_process(0.016)
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).cause_id, &"forbidden_zone_curse")


func test_zone_does_not_fire_when_zone_size_is_zero() -> void:
	# An AABB with zero size must never fire — size == Vector3.ZERO guard.
	var dm := _make_dm()
	var r := _make_rule()
	var player := _make_player()
	# Explicitly pass an AABB with a non-zero position but zero size.
	var empty_zone := AABB(Vector3(0.0, 0.0, 0.0), Vector3.ZERO)
	r.setup(player, dm, _make_data(&"empty_zone_rule", 0.0, empty_zone))

	player.global_position = Vector3.ZERO  # technically "inside" a zero-volume box
	watch_signals(dm)
	r._physics_process(0.016)
	assert_signal_not_emitted(dm, "player_died")


# ---------------------------------------------------------------------------
# Physics process null guards
# ---------------------------------------------------------------------------

func test_physics_process_exits_cleanly_when_player_null() -> void:
	var r := _make_rule()
	# No setup — _player and _death_manager are null.
	r._physics_process(0.016)
	assert_true(true)


func test_physics_process_exits_cleanly_when_death_manager_null() -> void:
	var r := _make_rule()
	r._player = CharacterBody3D.new()
	add_child_autofree(r._player)
	r._physics_process(0.016)
	assert_true(true)


# ---------------------------------------------------------------------------
# Cleanup — _exit_tree unregisters cause
# ---------------------------------------------------------------------------

func test_exit_tree_unregisters_cause_from_death_manager() -> void:
	var dm := _make_dm()
	# We need a CauseRule that is NOT autofree so we can free it manually.
	var r := CauseRule.new()
	add_child(r)
	r.setup(_make_player(), dm, _make_data(&"temp_rule", 30.0))

	# count: 1 npc + 1 temp_rule = 2
	assert_eq(dm.cause_count(), 2)

	# Freeing r calls _exit_tree, which should unregister.
	r.queue_free()
	# queue_free is deferred — we need to process the frame.
	await get_tree().process_frame

	assert_eq(dm.cause_count(), 1)  # only npc remains


func test_exit_tree_does_not_crash_when_death_manager_is_null() -> void:
	# If setup was never called, _death_manager is null.
	# _exit_tree must not crash.
	var r := CauseRule.new()
	add_child(r)
	r.queue_free()
	await get_tree().process_frame
	assert_true(true)


# ---------------------------------------------------------------------------
# Timer + zone interaction: timer takes priority (returns early)
# ---------------------------------------------------------------------------

func test_timer_return_prevents_zone_from_double_firing() -> void:
	# When both timer and zone are active, the timer branch returns early,
	# preventing zone from calling trigger a second time on the same frame.
	# DeathManager._triggered latch would absorb it anyway, but we verify
	# exactly one emission, not two.
	var dm := _make_dm()
	var r := _make_rule()
	var zone := AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0))
	var player := _make_player()
	r.setup(player, dm, _make_data(&"combo_rule", 5.0, zone))

	player.global_position = Vector3.ZERO  # inside zone
	watch_signals(dm)
	r._physics_process(5.0)  # timer fires, returns before zone check
	assert_signal_emit_count(dm, "player_died", 1)

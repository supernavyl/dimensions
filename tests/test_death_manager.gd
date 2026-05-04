## Tests for DeathManager — cause registration, trigger, one-shot latch.
extends GutTest

var _dm: DeathManager


func before_each() -> void:
	_dm = DeathManager.new()
	add_child_autofree(_dm)


func test_initial_cause_count_is_one() -> void:
	# DeathManager._ready pre-registers &"npc"
	assert_eq(_dm.cause_count(), 1)


func test_register_adds_cause() -> void:
	var c := DeathCause.new()
	c.cause_id = &"test"
	_dm.register_cause(c)
	assert_eq(_dm.cause_count(), 2)


func test_trigger_emits_player_died() -> void:
	var c := DeathCause.new()
	c.cause_id = &"test"
	_dm.register_cause(c)
	watch_signals(_dm)
	_dm.trigger(&"test")
	assert_signal_emitted(_dm, "player_died")


func test_trigger_player_died_carries_cause() -> void:
	var c := DeathCause.new()
	c.cause_id = &"test"
	c.blood_intensity = 1.8
	_dm.register_cause(c)
	watch_signals(_dm)
	_dm.trigger(&"test")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).cause_id, &"test")


func test_trigger_twice_emits_once() -> void:
	var c := DeathCause.new()
	c.cause_id = &"test"
	_dm.register_cause(c)
	watch_signals(_dm)
	_dm.trigger(&"test")
	_dm.trigger(&"test")
	assert_signal_emit_count(_dm, "player_died", 1)


func test_trigger_unknown_cause_emits_default() -> void:
	watch_signals(_dm)
	_dm.trigger(&"unknown_cause_id")
	assert_signal_emitted(_dm, "player_died")


func test_unregister_removes_cause() -> void:
	var c := DeathCause.new()
	c.cause_id = &"remove_me"
	_dm.register_cause(c)
	_dm.unregister_cause(&"remove_me")
	assert_eq(_dm.cause_count(), 1)  # only npc remains


func test_latch_resets_after_on_dimension_loaded() -> void:
	var c := DeathCause.new()
	c.cause_id = &"test"
	_dm.register_cause(c)
	_dm.trigger(&"test")  # sets _triggered = true
	watch_signals(_dm)
	_dm._on_dimension_loaded()  # reset latch
	_dm.trigger(&"test")  # should fire again
	assert_signal_emit_count(_dm, "player_died", 1)


# ---------------------------------------------------------------------------
# Gap: register_cause(null) — must warn and not crash
# ---------------------------------------------------------------------------

func test_register_null_cause_does_not_crash() -> void:
	# Passing null to register_cause must push_warning and return without modifying state.
	_dm.register_cause(null)
	# Count must remain unchanged (1 pre-registered npc cause).
	assert_eq(_dm.cause_count(), 1)


func test_register_null_cause_does_not_change_count() -> void:
	var c := DeathCause.new()
	c.cause_id = &"existing"
	_dm.register_cause(c)
	var count_before: int = _dm.cause_count()

	_dm.register_cause(null)

	assert_eq(_dm.cause_count(), count_before)


# ---------------------------------------------------------------------------
# Gap: unregister non-existent id — must be a no-op
# ---------------------------------------------------------------------------

func test_unregister_nonexistent_id_does_not_crash() -> void:
	_dm.unregister_cause(&"this_id_was_never_registered")
	assert_true(true)


func test_unregister_nonexistent_id_does_not_change_count() -> void:
	var count_before: int = _dm.cause_count()
	_dm.unregister_cause(&"phantom_id")
	assert_eq(_dm.cause_count(), count_before)


# ---------------------------------------------------------------------------
# Gap: default cause properties (unknown cause_id fallback)
# ---------------------------------------------------------------------------

func test_trigger_unknown_cause_default_is_not_silent() -> void:
	watch_signals(_dm)
	_dm.trigger(&"nonexistent")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_false((args[0] as DeathCause).is_silent)


func test_trigger_unknown_cause_default_has_standard_blood_intensity() -> void:
	watch_signals(_dm)
	_dm.trigger(&"nonexistent")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).blood_intensity, 1.0)


func test_trigger_unknown_cause_default_id_is_unknown() -> void:
	watch_signals(_dm)
	_dm.trigger(&"some_bogus_id")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).cause_id, &"unknown")


# ---------------------------------------------------------------------------
# Gap: overwrite warning — registering same cause_id twice replaces the entry
# ---------------------------------------------------------------------------

func test_register_duplicate_id_overwrites_existing() -> void:
	var c1 := DeathCause.new()
	c1.cause_id = &"dupe"
	c1.blood_intensity = 0.5
	_dm.register_cause(c1)

	var c2 := DeathCause.new()
	c2.cause_id = &"dupe"
	c2.blood_intensity = 2.0
	_dm.register_cause(c2)

	# Count must not grow — still one entry for &"dupe".
	assert_eq(_dm.cause_count(), 2)  # npc + dupe

	# The emitted cause must be c2 (the overwrite).
	watch_signals(_dm)
	_dm.trigger(&"dupe")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).blood_intensity, 2.0)


# ---------------------------------------------------------------------------
# Gap: npc pre-registered cause properties
# ---------------------------------------------------------------------------

func test_npc_cause_has_heavy_blood_intensity() -> void:
	# The npc cause is pre-registered in _ready with blood_intensity = 2.0.
	watch_signals(_dm)
	_dm.trigger(&"npc")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).blood_intensity, 2.0)


func test_npc_cause_is_not_silent() -> void:
	watch_signals(_dm)
	_dm.trigger(&"npc")
	var args: Array = get_signal_parameters(_dm, "player_died", 0)
	assert_false((args[0] as DeathCause).is_silent)

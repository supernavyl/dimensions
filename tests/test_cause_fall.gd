## Tests for CauseFall — fall detection, settle guard, null guards, cause registration.
##
## Physics constraint: CharacterBody3D.is_on_floor() always returns false without a
## live physics collision. Tests that depend on on_floor==true (lethal-fall trigger,
## non-lethal-fall no-trigger) cannot be exercised in a unit test environment without
## a PhysicsServer3D floor body. Those paths are marked PHYSICS_REQUIRED and skipped
## with a gut_p() explanation. Everything else is fully covered.
extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Minimal stub that exposes the fields CauseFall reads from _player.
## CharacterBody3D.new() works in tree but is_on_floor() always returns false
## without a physics body beneath it, so we use CharacterBody3D and set velocity
## directly — the settle-guard and null-guard tests do not depend on is_on_floor().
class PlayerStub extends CharacterBody3D:
	pass


func _make_dm() -> DeathManager:
	var dm := DeathManager.new()
	add_child_autofree(dm)
	return dm


func _make_player() -> CharacterBody3D:
	var p := PlayerStub.new()
	add_child_autofree(p)
	return p


func _make_cause_fall() -> CauseFall:
	var cf := CauseFall.new()
	add_child_autofree(cf)
	return cf


# ---------------------------------------------------------------------------
# Null guard tests
# ---------------------------------------------------------------------------

func test_physics_process_exits_cleanly_when_player_is_null() -> void:
	# CauseFall._physics_process must not crash when _player is null.
	# This verifies the null guard at the top of _physics_process.
	var cf := _make_cause_fall()
	# Do NOT call setup — _player and _death_manager remain null.
	cf._physics_process(0.016)
	# If we reach here without error the null guard works.
	assert_true(true)


func test_physics_process_exits_cleanly_when_death_manager_is_null() -> void:
	var cf := _make_cause_fall()
	# Assign only player, leave _death_manager null.
	cf._player = _make_player()
	cf._physics_process(0.016)
	assert_true(true)


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

func test_setup_registers_fall_cause() -> void:
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()

	var count_before: int = dm.cause_count()
	cf.setup(player, dm)
	assert_eq(dm.cause_count(), count_before + 1)


func test_setup_registers_cause_with_fall_id() -> void:
	# Verify the registered cause id is exactly &"fall".
	# We trigger with &"fall" and check the signal fires with the right id.
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, dm)

	watch_signals(dm)
	dm.trigger(&"fall")
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).cause_id, &"fall")


func test_setup_registered_cause_has_correct_blood_intensity() -> void:
	# DeathCause for fall is specified at blood_intensity 1.5 in cause_fall.gd.
	var dm := _make_dm()
	var cf := _make_cause_fall()
	cf.setup(_make_player(), dm)

	watch_signals(dm)
	dm.trigger(&"fall")
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_eq((args[0] as DeathCause).blood_intensity, 1.5)


func test_setup_registered_cause_is_not_silent() -> void:
	var dm := _make_dm()
	var cf := _make_cause_fall()
	cf.setup(_make_player(), dm)

	watch_signals(dm)
	dm.trigger(&"fall")
	var args: Array = get_signal_parameters(dm, "player_died", 0)
	assert_false((args[0] as DeathCause).is_silent)


func test_setup_called_twice_overwrites_cause_without_crash() -> void:
	# CauseFall is designed to persist across dimensions and call setup() again.
	# register_cause warns but must not crash.
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, dm)
	cf.setup(player, dm)
	# Still exactly one fall entry (overwritten, not doubled).
	# Count: 1 npc (pre-reg) + 1 fall = 2.
	assert_eq(dm.cause_count(), 2)


# ---------------------------------------------------------------------------
# State reset after setup()
# ---------------------------------------------------------------------------

func test_setup_resets_settled_to_false() -> void:
	var cf := _make_cause_fall()
	cf._settled = true  # simulate a previous frame
	cf.setup(_make_player(), _make_dm())
	assert_false(cf._settled)


func test_setup_resets_is_falling_to_false() -> void:
	var cf := _make_cause_fall()
	cf._is_falling = true
	cf.setup(_make_player(), _make_dm())
	assert_false(cf._is_falling)


func test_setup_resets_fall_start_y_to_zero() -> void:
	var cf := _make_cause_fall()
	cf._fall_start_y = 99.9
	cf.setup(_make_player(), _make_dm())
	assert_eq(cf._fall_start_y, 0.0)


# ---------------------------------------------------------------------------
# Settle guard
# ---------------------------------------------------------------------------

func test_settle_guard_skips_first_frame() -> void:
	# On the first _physics_process call after setup, _settled flips to true
	# and the function returns early — no death should be triggered.
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, dm)

	# At this point _settled == false.
	assert_false(cf._settled)

	watch_signals(dm)
	# Give the player a downward velocity so IF the settle guard were absent
	# the fall-tracking branch might engage.
	player.velocity = Vector3(0.0, -20.0, 0.0)
	cf._physics_process(0.016)

	# After first process call, settled becomes true.
	assert_true(cf._settled)
	# No death should have fired on frame 1.
	assert_signal_not_emitted(dm, "player_died")


func test_settle_guard_does_not_block_second_frame() -> void:
	# After the first frame, _settled == true and normal processing proceeds.
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, dm)

	# Burn the settle frame.
	cf._physics_process(0.016)
	assert_true(cf._settled)

	# Second frame must not early-return due to settle guard.
	# We verify _is_falling state changes correctly when velocity.y < 0
	# and is_on_floor() is false (always false in unit test without physics).
	player.velocity = Vector3(0.0, -10.0, 0.0)
	cf._physics_process(0.016)

	# is_on_floor() == false and vel_y < 0 → _is_falling should now be true.
	assert_true(cf._is_falling)


# ---------------------------------------------------------------------------
# Fall tracking — no-floor state (physics-safe: is_on_floor always false here)
# ---------------------------------------------------------------------------

func test_fall_tracking_records_start_y_when_falling_begins() -> void:
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, dm)

	# Burn settle frame.
	cf._physics_process(0.016)

	# Place player at a known height and set downward velocity.
	player.global_position = Vector3(0.0, 50.0, 0.0)
	player.velocity = Vector3(0.0, -8.0, 0.0)
	cf._physics_process(0.016)

	# _fall_start_y must have been set to the player's y at the moment
	# falling was first detected.
	assert_eq(cf._fall_start_y, 50.0)


func test_fall_tracking_does_not_record_start_when_moving_up() -> void:
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, _make_dm())

	# Burn settle frame.
	cf._physics_process(0.016)

	player.velocity = Vector3(0.0, 5.0, 0.0)  # moving upward
	cf._physics_process(0.016)

	assert_false(cf._is_falling)
	assert_eq(cf._fall_start_y, 0.0)


func test_fall_tracking_does_not_trigger_death_mid_fall() -> void:
	# While _is_falling == true and not on_floor, no trigger should fire.
	var dm := _make_dm()
	var cf := _make_cause_fall()
	var player := _make_player()
	cf.setup(player, dm)
	cf._physics_process(0.016)  # settle

	player.global_position = Vector3(0.0, 100.0, 0.0)
	player.velocity = Vector3(0.0, -20.0, 0.0)
	cf._physics_process(0.016)  # starts falling

	watch_signals(dm)
	# Continue falling — several more frames, still in air.
	player.global_position = Vector3(0.0, 80.0, 0.0)
	cf._physics_process(0.016)

	assert_signal_not_emitted(dm, "player_died")


# ---------------------------------------------------------------------------
# PHYSICS_REQUIRED paths — documented, not tested
# ---------------------------------------------------------------------------
# The following paths require is_on_floor() == true, which needs a
# PhysicsServer3D floor body. They cannot be covered in a unit test.
#
# 1. drop >= LETHAL_HEIGHT (6.0 m) → _death_manager.trigger(&"fall") called
# 2. drop < LETHAL_HEIGHT (non-lethal landing) → no trigger
#
# These must be covered in integration tests using the full player scene
# placed above a StaticBody3D floor at a known height differential.
# ---------------------------------------------------------------------------

func test_lethal_height_constant_is_six_metres() -> void:
	# At minimum, assert the constant is what the design doc specifies.
	# A mutation that changes LETHAL_HEIGHT would break this.
	assert_eq(CauseFall.LETHAL_HEIGHT, 6.0)

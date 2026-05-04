## CauseFall — monitors the player's vertical drop and triggers death on lethal falls.
## Child of DeathManager. Persists across dimensions; registers once in setup().
class_name CauseFall
extends Node

## Vertical drop in metres that constitutes a lethal fall.
const LETHAL_HEIGHT: float = 6.0

var _fall_start_y: float = 0.0
var _is_falling: bool = false

## One-frame settle delay: prevents a spurious trigger when the player is
## placed at spawn (which may briefly show velocity.y < 0 before physics settles).
var _settled: bool = false

var _death_manager: DeathManager = null
var _player: CharacterBody3D = null


## Resets fall-tracking state between dimension transitions.
## Called by main.gd._on_dimension_loaded() after player teleport.
## Does NOT re-register the cause — cause registration is permanent per CauseFall lifetime.
func reset_fall_state() -> void:
	_is_falling = false
	_fall_start_y = 0.0
	_settled = false


## Wires this cause to the player and its DeathManager.
## Registers the &"fall" cause once. Safe to call again after re-spawn — the
## register_cause overwrite warning is intentional and harmless here because
## CauseFall persists across dimensions while the player node does not change.
func setup(player: CharacterBody3D, dm: DeathManager) -> void:
	_player = player
	_death_manager = dm

	var fall_cause := DeathCause.new()
	fall_cause.cause_id = &"fall"
	fall_cause.blood_intensity = 1.5
	fall_cause.is_silent = false
	dm.register_cause(fall_cause)

	# Reset state so the settle guard fires on the next frame.
	_settled = false
	_is_falling = false
	_fall_start_y = 0.0


func _physics_process(_delta: float) -> void:
	if _player == null or _death_manager == null:
		return

	# Settle guard: skip the first frame after setup to avoid spurious triggers
	# while Godot initialises the physics state at the spawn position.
	if not _settled:
		_settled = true
		return

	var on_floor: bool = _player.is_on_floor()
	var vel_y: float = _player.velocity.y

	if not _is_falling and not on_floor and vel_y < 0.0:
		# Player just left the ground moving downward — record start height.
		_is_falling = true
		_fall_start_y = _player.global_position.y

	elif _is_falling and on_floor:
		# Player landed. Measure the total drop.
		var drop: float = _fall_start_y - _player.global_position.y
		_is_falling = false
		if drop >= LETHAL_HEIGHT:
			_death_manager.trigger(&"fall")

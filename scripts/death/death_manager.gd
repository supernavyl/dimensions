## DeathManager — tracks registered DeathCause resources and routes player death.
## Parented to Player in main.gd._ready(). One-shot latch prevents double-fire
## across a single dimension lifetime. Latch resets via dimension_loaded listener.
class_name DeathManager
extends Node

## Emitted when the player dies. Carries the matching DeathCause.
signal player_died(cause: DeathCause)

## Registered causes keyed by cause_id StringName.
var _causes: Dictionary = {}

## Prevents player_died from firing more than once before the next dimension loads.
var _triggered: bool = false


func _ready() -> void:
	# Pre-register the NPC kill cause so it is always available even before
	# any dimension has set up a CauseRule.
	var npc_cause := DeathCause.new()
	npc_cause.cause_id = &"npc"
	npc_cause.blood_intensity = 2.0
	npc_cause.is_silent = false
	_causes[&"npc"] = npc_cause

	# Connect to DimensionManager so the latch resets after each transition.
	DimensionManager.dimension_loaded.connect(_on_dimension_loaded)


## Registers a DeathCause. Warns if the cause_id is already registered;
## the new entry replaces the old one.
func register_cause(cause: DeathCause) -> void:
	if cause == null:
		push_warning("DeathManager.register_cause: received null cause — ignored")
		return
	if _causes.has(cause.cause_id):
		push_warning(
			"DeathManager: cause_id '%s' already registered — overwriting" % cause.cause_id
		)
	_causes[cause.cause_id] = cause


## Removes a registered cause by id. No-ops if the id is not present.
func unregister_cause(cause_id: StringName) -> void:
	_causes.erase(cause_id)


## Returns the number of currently registered causes.
func cause_count() -> int:
	return _causes.size()


## Fires player_died with the matching cause. Re-entrant calls are swallowed by
## the _triggered latch. Falls back to a default cause if cause_id is not registered.
func trigger(cause_id: StringName) -> void:
	if _triggered:
		return
	_triggered = true

	var cause: DeathCause = _causes.get(cause_id, null) as DeathCause
	if cause == null:
		push_warning(
			"DeathManager: trigger called with unknown cause_id '%s' — using default" % cause_id
		)
		cause = _default_cause()

	player_died.emit(cause)


## Called when the dimension finishes loading. Resets the trigger latch so the
## next dimension can fire a death event.
## ADR-001: reset only — must not call trigger from this listener.
func _on_dimension_loaded() -> void:
	_triggered = false


## Returns a minimal default cause used when an unregistered cause_id is triggered.
func _default_cause() -> DeathCause:
	var c := DeathCause.new()
	c.cause_id = &"unknown"
	c.is_silent = false
	c.blood_intensity = 1.0
	return c

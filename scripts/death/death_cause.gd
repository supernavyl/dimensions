## DeathCause — Resource describing what killed the player.
## Passed through DeathManager.player_died and into DeathSequence.play().
class_name DeathCause
extends Resource

## Unique identifier for this cause (e.g. &"fall", &"npc", &"rule_timer").
@export var cause_id: StringName = &""
## Silent deaths fade slowly to black (no red flash).
@export var is_silent: bool = false
## Blood overlay intensity: 0 = none, 1 = normal, 2 = heavy.
@export var blood_intensity: float = 1.0

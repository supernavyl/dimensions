## DimensionData — Resource describing one procedurally generated dimension.
## Serializable, inspector-editable, passed to DimensionRoot.initialize().
class_name DimensionData
extends Resource

## Identifies which template class builds this dimension.
@export var template_id: StringName = &"void"
## RNG seed used to replicate the exact layout.
@export var seed: int = 0
## Hidden time threshold in seconds the player must survive.
@export var survival_threshold: float = 120.0
## Minimum number of NPCs spawned (Phase 3).
@export var npc_count_min: int = 1
## Maximum number of NPCs spawned (Phase 3).
@export var npc_count_max: int = 4
## Background and ambient tint color.
@export var ambient_color: Color = Color(0.05, 0.05, 0.07)
## Volumetric fog density (0 = none).
@export var fog_density: float = 0.02
## Gravity multiplier applied to the player's CharacterBody3D per-dimension.
@export var gravity_scale: float = 1.0
## Optional hidden rule identifier used by cause_rule.gd.
@export var rule_id: StringName = &""
## Arbitrary parameters for the hidden rule (e.g. zone AABB, timer duration).
@export var rule_param: Dictionary = {}


## Returns the template identifier (convenience accessor).
func get_template_id() -> StringName:
	return template_id

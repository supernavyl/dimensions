## NPCGoalGenerator — stateless factory for NPC behavioral goals.
## Call the static generate(rng) method to get a weighted-random Goal.
class_name NPCGoalGenerator
extends RefCounted

## Behavioral goal assigned to an NPC at spawn time.
enum Goal {
	WANDER = 0,
	PURSUE = 1,
	THREATEN = 2,
}

## Cumulative weight table: indices must match Goal enum values.
## WANDER = 40%, PURSUE = 35%, THREATEN = 25%.
const _WEIGHTS: Array[int] = [40, 75, 100]


## Returns a weighted-random Goal using the provided RNG.
## rng must not be null.
static func generate(rng: RandomNumberGenerator) -> Goal:
	var roll: int = rng.randi_range(1, 100)
	for i: int in range(_WEIGHTS.size()):
		if roll <= _WEIGHTS[i]:
			return i as Goal
	# Fallback — should be unreachable if weights sum to 100.
	return Goal.WANDER

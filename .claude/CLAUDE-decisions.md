# DIMENSIONS — Architectural Decisions

## ADR-001 — DimensionManager signal-listener invariant (Phase 3)
**Date:** 2026-05-04
**Status:** ACTIVE — must be respected by all Phase 3+ work

No `dimension_loaded` listener may call `trigger_death()` or any path that
re-enters `DimensionManager.load_next_dimension()` synchronously.

The `_dying` latch protects post-emit re-entry (it is reset to `false` only
AFTER `dimension_loaded.emit()` returns). However, the latch is a temporal
guard, not a structural one. Any future signal listener wired to
`dimension_loaded` that triggers another dimension transition will bypass this
protection and cause a double-load / corrupted state.

**Enforcement:** Code review gate on any `.connect(DimensionManager.dimension_loaded, ...)`.

---

## ADR-002 — No class_name on autoloads
**Date:** 2026-05-04
**Status:** ACTIVE

`game_state.gd` and `dimension_manager.gd` must NOT declare `class_name`.
Godot 4 registers autoloads by their node name globally; adding `class_name`
with the same name causes a collision and makes the autoload unreachable by
script name.

---

## ADR-003 — CompletionTracker instantiated in code, not baked in .tscn
**Date:** 2026-05-04
**Status:** ACTIVE

`CompletionTracker` is added as a child of `DimensionRoot` in
`DimensionRoot.initialize()` so that `threshold` can be set from
`DimensionData.survival_threshold` before the node enters the scene tree.

If `CompletionTracker` were baked into `dimension_root.tscn`, the threshold
would be the exported default (120s) for every dimension, ignoring procedural
generation. Do not add it to the .tscn.

---

## ADR-004 — jump_velocity Phase 3 debt
**Date:** 2026-05-04
**Status:** DEFERRED to Phase 3

`FPSController` exports `jump_velocity: float = 4.5` but no jump input is
wired. Phase 3 must either:
- Add `"jump"` to the input map in `project.godot` and implement the
  `is_on_floor() + is_action_just_pressed(&"jump")` branch, OR
- Remove the export entirely if jumping is not part of the design.

The export is currently inspector noise only — no runtime impact.

---

## ADR-005 — Templates build via .new() on Variant class reference
**Date:** 2026-05-04
**Status:** ACTIVE

`DimensionRoot._build_template()` resolves template classes from a `Dictionary`
at runtime and calls `.new()` on the `Variant`. This pattern works in GDScript 4
because class references are first-class values. It avoids a large static
`match` block and allows template registration without modifying DimensionRoot.

Constraint: all template classes must extend `Node3D` and expose:
- `var data: DimensionData` (set before `build()` is called)
- `func build(rng: RandomNumberGenerator) -> void`

---

## ADR-006 — Single-writer physics: BT leaves write velocity, NPCController calls move_and_slide
**Date:** 2026-05-04
**Status:** ACTIVE

`NPCController._physics_process` is the **only** site that calls `move_and_slide()`.
All behavior tree leaf nodes (`BTWander`, `BTIdle`, `BTPursue`, `BTThreaten`) write
`actor.velocity.x` and `actor.velocity.z` only. They must never call `move_and_slide()`
themselves.

Rationale: multiple `move_and_slide()` calls per frame on the same body corrupt
velocity integration. Centralizing the call in `_physics_process` after the BT
tick ensures exactly one integration step per frame.

**Enforcement:** Code review gate on any `actor.move_and_slide()` call inside a
`BTNode` subclass. Reject without exception.

---

## ADR-007 — NPC spawn distance invariant: ≥ 2.0 m from player
**Date:** 2026-05-04
**Status:** ACTIVE

`DimensionRoot._pick_safe_spawn()` rejects candidate positions closer than 2.0 m
to the player using rejection sampling (up to 16 tries). If all 16 candidates fail,
the fallback pushes the NPC radially outward at exactly 2.0 m at a random angle.

The player must be relocated to `get_player_spawn()` **before** `_spawn_npcs()` is
called, so that spawn distances are measured from the correct in-world position and
not from world origin.

Rationale: NPCs spawning inside or on top of the player causes immediate kill-range
firing and a broken first impression of the dimension.

---

## ADR-008 — entered_kill_range signal is one-shot per NPC lifetime
**Date:** 2026-05-04
**Status:** ACTIVE

`NPCController` holds a `_kill_emitted: bool = false` latch. The latch is set to
`true` on the first frame that `global_position.distance_to(_player.global_position)
<= kill_range`. The signal `entered_kill_range` is emitted exactly once per NPC
lifetime regardless of how many subsequent frames the NPC remains in kill range.

Rationale: without the latch, `trigger_death()` would be called on every physics
frame the NPC is in range — even though `DimensionManager._dying` would absorb the
re-entrant calls, this would generate superfluous signal emissions and make the
signal semantics misleading. The latch makes intent explicit and removes the
dependency on `_dying` for correctness.

---

## ADR-009 — DeathSequence parented to current_scene, not _current_dimension (Phase 4)
**Date:** 2026-05-04
**Status:** ACTIVE

`DeathSequence` is added as a child of `get_tree().current_scene` (Main), not
of `_current_dimension`. This is enforced in `DimensionManager._play_death_sequence()`.

Rationale: `_current_dimension` is freed at the start of `load_next_dimension()`,
which is called immediately after the sequence finishes. If DeathSequence were
parented to the dimension, it would be freed mid-sequence the moment the dimension
transition begins, cutting the fade short and causing the `await` in
`DeathSequence.play()` to reference a freed node. Parenting to the stable scene
root avoids this lifetime dependency entirely.

---

## ADR-010 — DeathManager._triggered latch is reset-only from dimension_loaded listener (Phase 4)
**Date:** 2026-05-04
**Status:** ACTIVE — extends ADR-001

`DeathManager._on_dimension_loaded()` resets `_triggered = false` and does
nothing else. It must never call `trigger()` or any path that emits `player_died`.

Rationale: `dimension_loaded` is emitted from inside `load_next_dimension()`,
which is called from `_on_death_sequence_finished()`, which is itself wired to
`sequence_finished`. Any trigger call from the `dimension_loaded` handler would
re-enter the death path while `_dying` is still `true` (it resets at the end of
`load_next_dimension()`), creating a brief window where double-death could slip
through if the latch is cleared before `_dying` resets. The reset-only invariant
eliminates this class of bug entirely.

---

## ADR-011 — CauseRule instantiated in DimensionRoot, freed with the dimension (Phase 4)
**Date:** 2026-05-04
**Status:** ACTIVE

`CauseRule` is added as a child of `DimensionRoot` (not of the Player or
DeathManager). This means it is freed automatically when the dimension is freed.
`CauseRule._exit_tree()` calls `DeathManager.unregister_cause(rule_id)` to
clean up the registered cause before the node is gone.

Rationale: rules are dimension-scoped. Parenting to the player would require
manual cleanup logic in DeathManager or Main. Parenting to DimensionRoot ties the
rule lifetime directly to the dimension lifetime and leverages `_exit_tree()` as
the natural cleanup hook — no external orchestration needed.

`CauseFall` deliberately does NOT follow this pattern: fall detection is
player-physics-scoped and must persist across dimension transitions.

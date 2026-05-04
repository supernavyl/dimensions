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

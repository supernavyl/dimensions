# DIMENSIONS — Game Design Spec
_2026-05-04_

## Concept

First-person psychological survival across procedurally generated dimensions. Beautiful and wrong simultaneously. Every death is unexpected, visceral, and disturbing. Every dimension is different. No progress carries over. The game ends when you've survived enough dimensions — but you never know how many that is.

---

## Core Loop

1. **Wake** in a new dimension — first person, no HUD, no health bar, no inventory
2. **Exist** — explore, interact with AI NPCs, grab and affect objects
3. **Die** — unexpectedly, from anything, always disturbing — cut to black
4. **Wake again** — new dimension, absolute zero, nothing carried over except false memories
5. **Survive long enough** — dimension marked complete (hidden, no indicator)
6. **Repeat** until enough dimensions complete → final event triggers

---

## Dimensions

Each dimension is procedurally generated with:

- **Aesthetic** — unique visual identity. Anything is possible: a classroom mid-lecture, a nightclub at 3am, a hospital corridor, a void, urban decay, a family dinner, organic/biological space, clinical white, a rooftop, an empty mall. Mundane settings are often the most disturbing — everything looks normal, something is wrong.
- **Physics rules** — gravity, time flow, material behavior may differ
- **Atmosphere** — sound design, lighting, color grading, fog density
- **Threat logic** — what in this dimension can kill you, and how

Dimensions are beautiful first. The wrongness is subtle initially — something slightly off about proportions, NPC behavior, light direction, sound. The longer you survive the more apparent it becomes.

No two dimensions share the same template seed. The player never returns to a completed dimension.

---

## NPCs

A small number per dimension (2–8 depending on type). NPCs can be:

- **Humanoid** — people at a party, a stranger in a hallway, a crowd dancing
- **Intelligent objects** — a door that makes decisions, furniture that watches
- **Abstract entities** — shapes, forces, presences that behave with intent

All NPCs run behavior trees with randomized goals, states, and priorities generated at dimension spawn. Goals are not scripted — they emerge from their current state and environment. NPCs are the primary source of death.

NPCs are **weird on AI** — their behavior follows internal logic the player cannot fully read. They may appear normal. They are not.

---

## Death

No health bar. No damage indicator. No warning system.

Death can come from:
- An NPC acting on its own logic
- Environmental physics (fall, crush, flood, fire)
- The dimension's hidden rules (stay too long in a zone, touch the wrong thing)
- The player's own actions (overdose in a club dimension, walking into something)
- Psychological events — screen distortion, audio collapse, reality failure

**Every death is a scene.** It plays out physically — blood, collapse, impact — scaled to the dimension's aesthetic. Some deaths are loud and violent. Some are quiet and deeply wrong. All are unexpected.

**The Re:Zero effect:** the player carries memories from past dimensions. This creates false confidence — they think they know how dimensions work, how NPCs behave, what is safe. That knowledge is wrong. Each dimension has its own rules. Overconfidence is the primary killer.

After death: no game-over screen, no score, no summary. Cut to black. Wake.

---

## Completion

Each dimension has a hidden survival threshold — a time + behavioral condition the player cannot see or measure. When met, the dimension is silently marked complete. No pop-up, no fanfare. The player may not even realize it happened until they die and something feels different.

The number of dimensions required to trigger the final event is unknown to the player.

---

## Final Event

When enough dimensions are completed, the final event triggers on the next death. What exactly happens is left open for implementation — but it must feel like a revelation, not a reward. Something that recontextualizes everything.

---

## Controls & Feel

- **Movement** — standard FPS (WASD + mouse)
- **Interaction** — single key, context-sensitive (grab, inspect, talk)
- **No UI** — all feedback is diegetic (sound, visual, physical)
- **No minimap, no compass, no objective markers**
- **No pause menu in-dimension** — pausing breaks immersion

---

## Tech Stack

- **Engine** — Godot 4 (GDScript)
- **NPC AI** — Behavior trees (Godot's built-in + custom nodes), randomized at spawn
- **Procedural generation** — Dimension template system with randomized seeds per axis (aesthetic, physics, NPC count/type, threat logic, completion threshold)
- **Death system** — Trigger library (environmental, NPC-caused, self-caused, rule-caused), each with its own animation/VFX set
- **No persistence** — no save files, no progress stored between sessions (meta completion count stored only)
- **Audio** — Procedural ambient + diegetic sound events, no music by default

---

## What This Is Not

- Not a roguelike with unlocks
- Not a horror game (though it may be frightening)
- Not a narrative game (though it has a conclusion)
- Not a combat game (though violence is possible)
- Not a puzzle game (though understanding helps)

It is a psychological experience about existing somewhere wrong, dying before you understand why, and doing it again.

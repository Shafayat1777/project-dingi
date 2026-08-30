# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Dingi" — a 2D physics-platformer built in **Godot 4.7** (Forward Plus renderer, Jolt Physics for 3D, `d3d12` rendering driver on Windows). GDScript only, no external build system, no package manager, no test framework.

There is no CLI build/lint/test pipeline — this is a Godot editor project. Open `project.godot` in the Godot 4.7 editor to run, debug, or edit scenes. To run headless from a terminal (if Godot is on PATH):

```
godot --path .
```

There is no automated test suite; verification is done by running the game in the editor and manually exercising the mechanic being changed.

## Architecture

**Scenes (`scenes/`) + Scripts (`scripts/`) are split** and mirror each other by feature folder (`Character`, `Map`, `Throwable`, `Items`, `Global`). A `.tscn` defines node structure; the paired `.gd` (same base name) holds behavior. `.uid` files alongside scripts are Godot's internal resource IDs — don't hand-edit them.

**Global singleton — `HeldItemManager` (`scripts/Global/HeldItemManager.gd`)**
Autoloaded (see `[autoload]` in `project.godot`). Single source of truth for what the player is currently carrying:
- Tracks `held_item` / `near_item` (both `RigidBody2D`) and `is_held`.
- `hold()`, `drop()`, `throw()` reparent the physics body between the world and a `Marker2D` held-position node, toggling `freeze` and zeroing `collision_layer`/`collision_mask` while held (restored on drop/throw).
- Emits `item_picked_up` / `item_thrown` signals — UI (`HeldItemUI.gd`) and prompts subscribe to these rather than polling.
- Any pickup/throwable object interacts with this singleton, not directly with the player.

**Player (`scripts/character/`)**
- `character_movement.gd` — `CharacterBody2D` physics movement (accel/friction/jump), pushes `RigidBody2D`s it collides with via `apply_central_impulse` in the `move_and_slide()` collision loop.
- `grab_area.gd` — an `Area2D` child of the player that detects nearby `RigidBody2D`s and drives `HeldItemManager.hold/drop/throw` from input actions (`pickup`, `drop`, `shoot`).
- `trajectory.gd` — aim-preview line (parabolic trajectory prediction) plus throwing a hook-rope projectile (`hook_rope_generation.tscn`) toward the mouse when not currently holding an item.

**Throwables (`scripts/Throwable/`)**
- `grenade.gd` / debris-type projectiles: simple `RigidBody2D.launch(rotation, velocity)`, self-destruct via `VisibleOnScreenNotifier2D` (`_on_visible_on_screen_notifier_2d_screen_exited`).
- `hook.gd` — projectile that also updates its own sprite rotation/flip based on velocity direction.
- `line_hook.gd` — throw-and-recall grappling hook: `is_thrown`/`is_recalling` state machine, drawn via a `Line2D` connecting player and hook (`top_level = true` so the rope isn't affected by parent transforms). Re-throwing/recalling triggered by the `shoot` action depending on current state.

**Rope simulation (`scripts/Map/static_rope.gd`, mirrored logic in `scripts/Throwable/hook_rope.gd`)**
Procedurally builds a rope out of `rope_piece.tscn` segments connected by `PinJoint2D`s:
1. Instantiate one sample segment to read its `CapsuleShape2D` height → `segment_spacing`.
2. Instantiate `rope_length` segments, positioned by cumulative spacing from the anchor (`StaticBody2D` or `Hook`).
3. Create a `PinJoint2D` per link, chaining segment→segment (first joint anchors to the static/hook body).
`hook_rope.gd` additionally decrements `mass` per segment (`base_mass - mass_decrement * i`, floored at 0.01) so the rope tapers.

## Input actions (`project.godot` → `[input]`)

`shoot`, `aim`, `grab`, `pickup`, `drop`, `left`, `right`, `jump`, `climb_up`, `climb_down` — defined in `project.godot`, not in code. Check this section before adding new bindings rather than hardcoding keycodes in scripts.

## Physics layers (`project.godot` → `[layer_names]`)

`1=world`, `2=player`, `3=object`, `4=hook`. Respect these when setting `collision_layer`/`collision_mask` on new bodies.

## Gotchas seen in existing code

- `HeldItemManager.hold/drop/throw` mutate `collision_layer`/`collision_mask` directly and restore saved values — if adding a new held-item type, make sure it doesn't rely on its layer/mask while held.
- Several scripts contain commented-out dead code (e.g. `grab_area.gd`) and stray `print()` debug statements (e.g. `HeldItemManager.gd`) — clean these up incidentally if already touching the function, but don't do drive-by cleanup elsewhere.

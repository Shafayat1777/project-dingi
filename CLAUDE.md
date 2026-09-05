# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Dingi" — a 2D physics-platformer built in **Godot 4.7** (Forward Plus renderer, Jolt Physics for 3D, `d3d12` rendering driver on Windows). GDScript only, no external build system, no package manager, no test framework.

Premise (from README): a relaxing physics-based side-scrolling adventure about navigating the flooded ruins of Dhaka. The player is a lone boatman crossing the submerged remains of Bangladesh's capital after the Buriganga River swallowed the city, solving environmental puzzles and helping stranded survivors on the way toward a distant, rumored dry land. This motivates the water/buoyancy systems being a core mechanic, not a side feature.

There is no CLI build/lint/test pipeline — this is a Godot editor project. Open `project.godot` in the Godot 4.7 editor to run, debug, or edit scenes. To run headless from a terminal (if Godot is on PATH):

```
godot --path .
```

There is no automated test suite; verification is done by running the game in the editor and manually exercising the mechanic being changed.

## Before writing code

Before implementing anything new, search `scripts/` and `scenes/` for an existing feature folder or script that does something similar (e.g. another throwable, another physics body, another UI prompt) and follow its structure/conventions rather than inventing a new pattern. This codebase is small and consistent by design — new code should look like it was written by the same person who wrote the rest of it.

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

**Water simulation (`scripts/Water/`)**
Spring-mesh water (Van der Windrift-style) driving both visuals and buoyancy:
- `water_body.gd` (`water_body.tscn`) owns an array of `water_spring.gd` (`water_spring.tscn`) instances spaced `distance_between_springs` apart. Each `_physics_process`, it runs Hooke's-law spring updates (`k`/`d`) per spring, then does `passes` iterations of neighbor-spread (`spread`/`spread_damping`) so disturbances ripple sideways, then rebuilds a `SmoothPathModified` border curve (`water_border`) and redraws the `Water_Polygon` fill from it. `water_state` (`STILL`/`NORMAL`/`STORMY`, an `@export` enum with a `set()`) swaps the spring constants and idle-wave params via `apply_water_state()` — set it in the editor or from code to change a body's behavior, don't hand-tune `k`/`d`/`spread` directly. `apply_idle_wave()` adds a continuous sine ripple (`wave_direction` LEFT/RIGHT) even with nothing touching the water, and randomly splashes springs when `STORMY`.
- `water_spring.gd` is an `Area2D`-based single spring: tracks its own `height`/`velocity`, applies drag (`water_drag`) to any `RigidBody2D`/`CharacterBody2D` inside it, and emits a `splash(index, speed)` signal on body enter/exit (consumed by `water_body.gd` to perturb the spring and spawn `water_splash.tscn` particles above `particle_splash_threshold`).
- `buoyant_object.gd` is attached to a `RigidBody2D` that should float; it reads the object's `CollisionShape2D` (`Rectangle`/`Circle`/`Capsule`) to size itself, then each physics frame samples the water surface height under it via `water_body.springs` (`get_water_height_at`, linear-interpolated between the two bracketing springs) and applies a buoyancy force scaled by `submersion_ratio` and `water_density`, a damping force opposing vertical velocity, and a stabilizing torque toward upright. Requires `water_body_path` to be wired to the relevant `water_body.tscn` instance in the editor.
- `smooth_path_modified.gd` (`class_name SmoothPathModified`) is a generic `Path2D` subclass that auto-computes smooth in/out tangents from neighboring points (`spline_length`) and draws itself as a polyline — used for the water surface border but not water-specific itself.

## Input actions (`project.godot` → `[input]`)

`shoot`, `aim`, `grab`, `pickup`, `drop`, `left`, `right`, `jump`, `climb_up`, `climb_down` — defined in `project.godot`, not in code. Check this section before adding new bindings rather than hardcoding keycodes in scripts.

## Physics layers (`project.godot` → `[layer_names]`)

`1=world`, `2=player`, `3=object`, `4=hook`, `5=water`. Respect these when setting `collision_layer`/`collision_mask` on new bodies.

## Gotchas seen in existing code

- `HeldItemManager.hold/drop/throw` mutate `collision_layer`/`collision_mask` directly and restore saved values — if adding a new held-item type, make sure it doesn't rely on its layer/mask while held.
- Several scripts contain commented-out dead code (e.g. `grab_area.gd`) and stray `print()` debug statements (e.g. `HeldItemManager.gd`) — clean these up incidentally if already touching the function, but don't do drive-by cleanup elsewhere.

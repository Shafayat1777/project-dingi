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

**Scenes (`scenes/`) + Scripts (`scripts/`) are split** and mirror each other by feature folder (`Boat`, `Character`, `Map`, `Throwable`, `Items`, `Global`, `Water`). A `.tscn` defines node structure; the paired `.gd` (same base name) holds behavior. `.uid` files alongside scripts are Godot's internal resource IDs — don't hand-edit them.

**Global singleton — `HeldItemManager` (`scripts/Global/HeldItemManager.gd`)**
Autoloaded (see `[autoload]` in `project.godot`). Just shared state: `held_item` (`RigidBody2D`) and `is_held` (`bool`). It holds no logic itself — pickup/drop/throw behavior lives per-item in `GrabObject` (below), which reads and writes these fields so only one thing can be held globally at a time.

**Pickup/carry system is item-side, not player-side (`scripts/Global/`)**
- `grab_object.gd` (`class_name GrabObject`) is attached to each pickupable `RigidBody2D` itself (as a child `Node2D`), not to the player. It polls `pickup`/`drop`/`shoot` input every `_physics_process` and only acts if the player is within range (tracked via a `Pickable-Position` `Marker2D` handed to it by a proximity signal) and `HeldItemManager.is_held` allows it. `pick_up()` reparents the object onto the target marker and zeroes its collision layer/mask (saved for restore); `drop()`/`throw()` reparent it back to the current scene, restore collision, and give it a velocity (a fixed toss for drop, aimed at the mouse for throw).
- `proximity_highlight.gd` (`class_name InteractionPrompt`) is an `Area2D` also attached per-item; it shows a floating `Label` ("Press E to interact" by default) and toggles an outline shader on the item's `Sprite2D` when the player enters range, and feeds `GrabObject` the `Pickable-Position` marker via `_on_proximity_highlight_body_entered/exited` signals wired in the item's scene. The label is `top_level = true` and repositioned every `_process` from a fixed world-space offset computed once in `_calculate_offset()`, so it stays upright and centered regardless of the item's own rotation/flip.
- Any new pickupable object should get both scripts attached (see `scenes/movable_object.tscn` or `scenes/Throwable/*.tscn` for the pattern), not a copy of player-side grab logic.

**Player (`scripts/character/`)**
- `character_movement.gd` — `CharacterBody2D` physics movement (accel/friction/jump). Also drives all player→object contact forces from the `move_and_slide()` slide-collision loop: standing on top of a `RigidBody2D` applies a continuous downward force (so floating objects dip/bob instead of just absorbing one impulse), pushing a submerged object (`is_submerged` on the collider) applies a continuous sideways force, and any other side contact applies a one-shot `apply_central_impulse`.
- `trajectory.gd` — aim-preview line (parabolic trajectory prediction) shown while holding `aim`. Its own `throw()` (spawning `hook_rope_generation.tscn`) is currently dead code (never called — the actual grapple-hook throw is handled independently by `line_hook.gd` on the `shoot` action).

**Boat (`scripts/Boat/`, `scenes/Boat/boat.tscn`)**
A rideable, floating `RigidBody2D` composed of sibling `Node`/`Node2D` components under the boat scene, each owning one concern:
- `boat.gd` — root script on the boat `RigidBody2D` itself; toggles `linear_damp`/friction depending on `is_on_water` (set externally by `buoyancy2.gd`).
- `boat_highlight.gd` — listens for the player entering/exiting a detection `Area2D`, shows an outline + "press E" label, and on `interact` calls `BoatMount.mount()`/`dismount()` depending on `boat.is_occupied`.
- `boat_mount.gd` (`BoatMount`) — the actual mount/dismount logic: reparents the player `CharacterBody2D` onto the boat (disabling its own `CollisionShape2D` and physics process while aboard), positions it at an `ExitMarker` on dismount, and toggles `BoatDriver.set_active()`.
- `boat_driver.gd` (`BoatDriver`) — only runs while `active` (i.e. while mounted); applies rowing force from `left`/`right` input directly to the boat body, capped at `max_speed`.
- `cargo_weight.gd` (`CargoWeight`) — tracks `RigidBody2D`s inside a cargo `Area2D` (`_on_cargo_area_body_entered/exited`) and sums their mass onto `base_mass` so a loaded boat rides lower/handles heavier.
- `buoyancy2.gd` — a second, boat-specific buoyancy implementation (separate from `scripts/Water/buoyant_object.gd`): samples water height at both edges of the collision shape via `water_body.springs`, applies a per-side vertical force scaled by submersion, plus damping and a righting torque, and sets `is_on_water` on the boat body which `boat.gd` reacts to. **Not currently attached to `scenes/Boat/boat.tscn`** — the script exists but no node in the boat scene references it, so the boat presently has no buoyancy and won't float. Wire it onto a node in the boat scene before relying on boat buoyancy behavior.

**Throwables (`scripts/Throwable/`)**
- `grenade.gd` / debris-type projectiles: simple `RigidBody2D.launch(rotation, velocity)`, self-destruct via `VisibleOnScreenNotifier2D` (`_on_visible_on_screen_notifier_2d_screen_exited`).
- `hook.gd` — projectile that also updates its own sprite rotation/flip based on velocity direction.
- `line_hook.gd` — throw-and-recall grappling hook, entirely self-contained (reads `shoot`/`climb_up`/`climb_down`/`jump` input itself, doesn't go through `trajectory.gd`): `IDLE`/`FLYING`/`STUCK`/`RECALLING` state machine, drawn via a `Line2D` connecting player and hook (`top_level = true` so the rope isn't affected by parent transforms). While `STUCK`, it clamps the player onto a rope-length circle each physics frame (`constrain_rope`) for swing physics, and `climb_up`/`climb_down` reel the rope length in/out.

**Rope simulation (`scripts/Map/static_rope.gd`, mirrored logic in `scripts/Throwable/hook_rope.gd`)**
Procedurally builds a rope out of `rope_piece.tscn` segments connected by `PinJoint2D`s:
1. Instantiate one sample segment to read its `CapsuleShape2D` height → `segment_spacing`.
2. Instantiate `rope_length` segments, positioned by cumulative spacing from the anchor (`StaticBody2D` or `Hook`).
3. Create a `PinJoint2D` per link, chaining segment→segment (first joint anchors to the static/hook body).
`hook_rope.gd` additionally decrements `mass` per segment (`base_mass - mass_decrement * i`, floored at 0.01) so the rope tapers.

**Water simulation (`scripts/Water/`)**
Spring-mesh water (Van der Windrift-style) driving both visuals and buoyancy:
- `water_body.gd` (`water_body.tscn`) owns an array of `water_spring.gd` (`water_spring.tscn`) instances spaced `distance_between_springs` apart. Each `_physics_process`, it runs Hooke's-law spring updates (`k`/`d`) per spring, then does `passes` iterations of neighbor-spread (`spread`/`spread_damping`) so disturbances ripple sideways, then rebuilds a `SmoothPathModified` border curve (`water_border`) and redraws the `Water_Polygon` fill from it. `water_state` (`STILL`/`NORMAL`/`STORMY`, an `@export` enum with a `set()`) swaps the spring constants and idle-wave params via `apply_water_state()` — set it in the editor or from code to change a body's behavior, don't hand-tune `k`/`d`/`spread` directly. `apply_idle_wave()` adds a continuous sine ripple (`wave_direction` LEFT/RIGHT) even with nothing touching the water, and randomly splashes springs when `STORMY`.
  - `ravine_start_index`/`ravine_end_index` restrict wave motion and border opacity to a spring index range (e.g. a narrow visible gap in the terrain); springs outside are pinned flat. Leave `ravine_start_index` at `-1` to apply wave motion body-wide.
  - Splash impacts (not idle wave motion) accumulate per-spring `foam_energy`, decayed each frame and pushed to `water_body.gdshader` as a foam buffer (`push_foam_to_shader`) — this is what drives the shader's foam rendering, not spring height directly.
  - Owns a pool of purely decorative `floating_debris.tscn` instances (leaves/moss/lily pads/branches/petals — no art assets exist, so `floating_debris.gd` draws procedural shapes via `_draw()`), positioned each physics frame by sampling spring height at each piece's drifting x (`update_floating_debris`).
- `water_spring.gd` is an `Area2D`-based single spring: tracks its own `height`/`velocity`, applies drag (`water_drag`) to any `RigidBody2D`/`CharacterBody2D` inside it, and emits a `splash(index, speed)` signal on body enter/exit (consumed by `water_body.gd` to perturb the spring and spawn `water_splash.tscn` particles above `particle_splash_threshold`).
- `buoyant_object.gd` is attached to a generic `RigidBody2D` that should float; it reads the object's `CollisionShape2D` (`Rectangle`/`Circle`/`Capsule`) to size itself, then each physics frame samples the water surface height under it via `water_body.springs` (`get_water_height_at`, linear-interpolated between the two bracketing springs) and applies a buoyancy force scaled by `submersion_ratio` and `water_density`, a damping force opposing vertical velocity, and a stabilizing torque toward upright. Requires `water_body_path` to be wired to the relevant `water_body.tscn` instance in the editor. The boat uses its own separate `scripts/Boat/buoyancy2.gd` instead of this script — don't confuse the two when touching buoyancy behavior.
- `smooth_path_modified.gd` (`class_name SmoothPathModified`) is a generic `Path2D` subclass that auto-computes smooth in/out tangents from neighboring points (`spline_length`) and draws itself as a polyline — used for the water surface border but not water-specific itself.
- `reflection_patch.gd` — a standalone decorative `Polygon2D` reusing `water_body.gdshader` (with `spring_count` left at 0 so the shader's foam logic no-ops) purely for its mirror-reflection effect, for placing a reflective patch anywhere without a real simulated water body. Spawns its own non-physical `floating_debris` instances (with their `PushArea` freed before entering the tree) for decoration.

## Input actions (`project.godot` → `[input]`)

`shoot`, `aim`, `grab`, `pickup`, `drop`, `left`, `right`, `jump`, `climb_up`, `climb_down`, `interact` — defined in `project.godot`, not in code. Check this section before adding new bindings rather than hardcoding keycodes in scripts.

## Physics layers (`project.godot` → `[layer_names]`)

`1=world`, `2=player`, `3=object`, `4=hook`, `5=water`, `6=boat_interior` — respect these when setting `collision_layer`/`collision_mask` on new bodies.

## Gotchas seen in existing code

- Pickup/drop/throw state lives in the item's own `GrabObject`, keyed against the shared `HeldItemManager.held_item`/`is_held` — if adding a new held-item type, attach `grab_object.gd` + `proximity_highlight.gd` to it rather than writing new pickup logic against the player.
- Two independent buoyancy implementations exist (`scripts/Water/buoyant_object.gd` for general objects, `scripts/Boat/buoyancy2.gd` for the boat) — check which one a scene actually uses before tuning water-force constants.
- `trajectory.gd` still contains an unused `throw()` method and a commented-out call site; the real grapple-hook throw path is `line_hook.gd`'s own `_input` handler.
- `cargo_weight.gd` has a leftover `print(boat.mass)` debug statement in `_recalculate()`.

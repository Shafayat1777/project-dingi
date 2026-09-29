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

The project's main scene (`run/main_scene`) is `scenes/Global/main_menue.tscn`, not a level — running the project starts at the main menu, and "New Game" loads `scenes/Map/level_1.tscn`. Open/run `level_1.tscn` directly in the editor (F6) to skip the menu while testing. `export_presets.cfg` defines a single "Windows Desktop" export preset (output `../../Dingi.exe`, i.e. outside the repo).

## Before writing code

Before implementing anything new, search `scripts/` and `scenes/` for an existing feature folder or script that does something similar (e.g. another throwable, another physics body, another UI prompt) and follow its structure/conventions rather than inventing a new pattern. This codebase is small and consistent by design — new code should look like it was written by the same person who wrote the rest of it.

## Architecture

**Scenes (`scenes/`) + Scripts (`scripts/`) are split** and mirror each other by feature folder (`Boat`, `Character`, `Map`, `Throwable`, `Items`, `Global`, `Water`). A `.tscn` defines node structure; the paired `.gd` (same base name) holds behavior. `.uid` files alongside scripts are Godot's internal resource IDs — don't hand-edit them.

**Global singleton — `HeldItemManager` (`scripts/Global/HeldItemManager.gd`)**
Autoloaded (see `[autoload]` in `project.godot`; the only other autoload is `PauseMenue`, covered under Main menu below). Just shared state: `held_item` (`RigidBody2D`) and `is_held` (`bool`). It holds no logic itself — pickup/drop/throw behavior lives per-item in `GrabObject` (below), which reads and writes these fields so only one thing can be held globally at a time.

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

**Main menu / pause menu (`scripts/Global/`, `scenes/Global/main_menue.tscn`)**
One scene doubles as both the title screen and the in-game pause menu (note the project-wide "menue" spelling in file/node names — keep it consistent rather than "fixing" it in one place):
- `pause_menue.gd` — second autoload, registered as `PauseMenue` in `project.godot`. `process_mode = Always`; on the `pause` action (Esc) in `_unhandled_input` it toggles `open_menu()`/`close_menu()`. `open_menu()` instantiates `main_menue.tscn` (preloaded as `MAIN_MENU`) with `process_mode = Always`, adds it to `get_tree().root` on top of the running level, sets `pause_menu = true`, and pauses the tree; `close_menu()` frees it and unpauses. Also holds shared state `full_screen` so the fullscreen toggle survives the menu being freed/reinstanced.
- `main_menue.gd` (root `Node2D` of `main_menue.tscn`) — in `_ready` shows "New Game" or "Resume" depending on `PauseMenue.pause_menu` (buttons fetched via `%` unique names), so the same scene reads as a title screen at startup and a pause menu in-game. Buttons are `TextureButton`s using `assets/ui/* Button.png` (normal) / `*  col_Button.png` (hover) pairs. "New Game" → `change_scene_to_file(level_1.tscn)`, "Resume" → `PauseMenue.close_menu()`, "Quit" → `get_tree().quit()`. "Options" is a placeholder that currently also just loads `level_1.tscn`.
- `check_button.gd` — the "Full Screen" `CheckButton` in the menu; syncs from/to `PauseMenue.full_screen` and calls `DisplayServer.window_set_mode(FULLSCREEN/WINDOWED)`.

**Tutorial UI (`scripts/TutorialUi/`, `scenes/TutorialUi/*.tscn`)**
One-shot intro/skill popups instanced directly into a level scene (see `TutorialUi`, `JumpTutorial`, `GrabTutorial`, `HookTutorial`, `SwingTutorial` nodes in `scenes/Map/level_1.tscn`). Two flavors:
- **Delayed intro popup** — `tutorial_ui.tscn` / `tutorial_1.gd`: root `CanvasLayer` (`process_mode = Always`) hides itself, waits 1.5s, then shows and pauses the tree. `tutorial_1_button.gd` now drives a single-step "Next"→"Ok" button (movement key prompt only, `IntroText` set directly — the old separate `WalkTutorial` label node was removed from the scene).
- **Trigger-zone skill popups** (`jump_tutorial.gd`, `grab_tutorial.gd`, `hook_tutorial.gd`, `swing_tutorial.gd`, all identical): root `Node2D` with a child `CanvasLayer` (hidden in `_ready`) and an `Area2D`; `process_mode = Node.PROCESS_MODE_WHEN_PAUSED` so the zone still detects the player while another popup has already paused the tree. On `_on_area_2d_body_entered`, if `body is CharacterBody2D` and it hasn't already fired (`body_passed` guard, one-shot), shows the `CanvasLayer` and pauses. Each has a paired `*_button.gd` on the panel's Next/Ok `Button` driving a `click_count`-indexed sequence of `intro_text` (`RichTextLabel`) strings (bbcode + inline `res://assets/ui/keyboard_*.png`/`mouse_*.png` images), ending on "Ok" which hides `root` + `root.get_node('CanvasLayer')` and unpauses.
- `tutorial_nine_patch_rect.gd` sizes a `NinePatchRect` to fit its `MarginContainer` content and re-centers it in the viewport whenever that content resizes (`_fit_to_content`/`_center`), so the panel auto-fits its text instead of being manually sized — shared by all the popups above.
- `jump_tutorial_button.gd` sets its first `intro_text` string in its own `_ready()` (via an `@onready` reference to the sibling `IntroText`) rather than leaving it baked into the `.tscn` — edit the popup's opening text in the script, not the scene.
- Follow the trigger-zone pattern (per-skill `Node2D` + `Area2D` + self-fitting `NinePatchRect` + `click_count`-driven button script, one-shot via `body_passed`) for future skill-intro popups; reserve the delayed-show pattern for the game's opening intro only.

**Kill zones / respawn (`scripts/Map/kill_zone_1.gd`, `scripts/Map/water_kill_zone.gd`, `scripts/TutorialUi/object_kill_zone.gd`)**
All are plain `Area2D`s (no scene-graph relation to the tutorial system despite one living under `scripts/TutorialUi/`) that reset something falling out of bounds back to a `Marker2D`:
- `kill_zone_1.gd` — for the player: on `_on_body_entered` with a `CharacterBody2D`, starts a `Timer` (delay before respawn) which on timeout snaps `character.position`/`velocity` to the `@export var spawn: Marker2D`. Used in `level_1.tscn` as `KillZone1`/`KillZone2`/`KillZone3`, each wired to its own `Spawn-N` marker placed just above it.
- `water_kill_zone.gd` (`scenes/Map/water_kill_zone.tscn`, a long thin `Area2D` masked to the player layer) — player-falls-in-water variant of `kill_zone_1.gd`: same `Timer`-delayed respawn to `spawn`, but additionally resets an `@export var boat: RigidBody2D` to `@export var boatspawn: Marker2D` (via `set_deferred` on `global_position`/velocities) so the player and boat are put back together. Used in `level_1.tscn` as `WaterKillZone` → `Spawn-4` / `Boat Spawn`.
- `object_kill_zone.gd` — for dropped/thrown `RigidBody2D`s: on `_on_body_entered`, immediately (`set_deferred`, no timer) teleports the body to `@export var spawn: Marker2D` and zeroes its linear/angular velocity, so a thrown object that falls off the level respawns at a shared `ObjectSpawner` marker instead of being lost. Used as `ObjectKillZone`/`ObjectKillZone2` in `level_1.tscn`, both pointing at the same `ObjectSpawner`.
- New instant-death or fall-out-of-bounds areas should reuse one of these scripts (player, player+boat, or object) rather than writing new respawn logic.

**Level bounds (`scenes/Map/level_1.tscn`)**
`InvisWall` / `InvusWall2` are `StaticBody2D`s with a tall `SegmentShape2D` on the `boundary` layer (9), placed at the level's left and right edges. The player and boat masks include `boundary` (the boat's `collision_mask` is `world | object | boundary`), so both are stopped at the level edges. Add new edge walls the same way rather than with tile collision.

**Dock / Market UI (`scripts/Map/`, `scenes/Map/market_ui.tscn`)**
`market_ui.tscn` is a self-contained scene instanced into `dock_1.tscn` (as `MarketUI`), replacing what used to be a bare `EnterMarket` Area2D node living directly in the dock scene. Node structure:
```
MarketUi (Node2D)
├── area2d (Area2D, script: dock_1_enter_market.gd, ui → CanvasLayer)
│   ├── CollisionShape2D
│   └── Label ("Press 'E' to enter Market")
└── CanvasLayer (script: dock_ui.gd, process_mode = 2 i.e. Always, so it still runs while paused)
    └── PanelContainer2 → MarginContainer
        ├── TextureRect (background image, e.g. assets/map/city_img.jpeg)
        └── VBoxContainer
            ├── Button ("Market")   — wired to CanvasLayer._on_button_pressed
            ├── Button2 ("Quest")   — wired to CanvasLayer._on_button_2_pressed
            ├── Button3 ("Workshop") — wired to CanvasLayer._on_button_3_pressed
            └── Button4 ("Exit")    — wired to CanvasLayer._on_button_4_pressed
```
Sibling panels under `CanvasLayer` (all start hidden in `_ready`): `DockMenu` (the button list above), `Shop`, `Quests`, `Workshop`, plus a shared `BackButton`.
- `dock_1_enter_market.gd` (on `area2d`) tracks `player_inside` via `_on_body_entered/exited` (checks `body is CharacterBody2D`), shows the "press E" `Label` on enter, and on `interact` (via `_unhandled_input`) shows the `@export var ui: CanvasLayer` (wired in the Inspector to the sibling `CanvasLayer`) and pauses the tree (`get_tree().paused = true`).
- `dock_ui.gd` (on `CanvasLayer`) is a simple panel switcher: `_on_button_pressed`/`_on_button_2_pressed`/`_on_button_3_pressed` hide `DockMenu` and show `Shop`/`Quests`/`Workshop` respectively (and show `BackButton`), `_on_back_button_pressed` reverses that back to `DockMenu`, and `_on_button_4_pressed` (Exit) hides every panel, hides itself, unpauses, and calls `get_viewport().set_input_as_handled()` so the `interact` press doesn't leak through while paused. `interact` while `visible` also closes it the same way as Exit.
- "Market"/"Quest"/"Workshop" now just swap to placeholder panels (`Shop`/`Quests`/`Workshop`) with a Back button — no real shop/quest/workshop content yet. Follow this show/hide-panel + Back-button pattern when building those out rather than introducing a new navigation scheme.
- Follow this scene's pattern (self-contained scene: entry-trigger Area2D + Label + pausing CanvasLayer UI, instanced into the map scene) for future dock/UI entry points rather than adding loose Area2D nodes to map scenes directly.

## Input actions (`project.godot` → `[input]`)

`shoot`, `aim`, `grab`, `pickup`, `drop`, `left`, `right`, `jump`, `climb_up`, `climb_down`, `interact`, `pause` (Esc, handled by the `PauseMenue` autoload) — defined in `project.godot`, not in code. Check this section before adding new bindings rather than hardcoding keycodes in scripts.

## Physics layers (`project.godot` → `[layer_names]`)

`1=world`, `2=player`, `3=object`, `4=hook`, `5=water`, `6=boat_interior`, `7=dock`, `8=boat`, `9=boundary` — respect these when setting `collision_layer`/`collision_mask` on new bodies.

## Gotchas seen in existing code

- Pickup/drop/throw state lives in the item's own `GrabObject`, keyed against the shared `HeldItemManager.held_item`/`is_held` — if adding a new held-item type, attach `grab_object.gd` + `proximity_highlight.gd` to it rather than writing new pickup logic against the player.
- Two independent buoyancy implementations exist (`scripts/Water/buoyant_object.gd` for general objects, `scripts/Boat/buoyancy2.gd` for the boat) — check which one a scene actually uses before tuning water-force constants.
- `trajectory.gd` still contains an unused `throw()` method and a commented-out call site; the real grapple-hook throw path is `line_hook.gd`'s own `_input` handler.
- `cargo_weight.gd` has a leftover `print(boat.mass)` debug statement in `_recalculate()`.
- `camera_pan.gd`'s `clamp_offset_to_limits` derives its offset bounds from a camera-center position (`cam_center`, itself clamped by `half_view`) rather than raw player position, matching Godot's built-in camera clamp — don't reintroduce raw `player_pos` into the `min_offset`/`max_offset` math or the offset clamp will disagree with the engine's own limit clamp.

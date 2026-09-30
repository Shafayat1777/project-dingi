# Project settings reference

What's configured in `project.godot` and `export_presets.cfg`, decoded into readable form. Source of truth is always the files; if you change a setting in the editor, update this doc.

## Overview

| Setting | Value |
|---|---|
| Project name | `Dingi` |
| Engine | Godot **4.7**, `config/features = ("4.7", "Forward Plus")` |
| Renderer | Forward Plus (default, not overridden) |
| Windows graphics API | `rendering_device/driver.windows = "d3d12"` |
| 2D physics | Godot's built-in 2D physics (default; nothing overridden) |
| 3D physics | Jolt Physics (`physics/3d/physics_engine`) - irrelevant to gameplay, the game is 2D-only |
| Icon | `res://icon.svg` |
| Main scene | `run/main_scene = uid://cv4m7kv8bksn8` -> `scenes/Global/main_menue.tscn` (title/pause menu; "New Game" loads `scenes/Map/level_1.tscn`) |
| Scripting | GDScript only |

To skip the menu while testing, open `scenes/Map/level_1.tscn` and press **F6**.

---

## Display / resolution

```ini
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- **No `window/size/viewport_*` is set**, so the base viewport is Godot's default **1152 x 648** (16:9).
- **Stretch mode `canvas_items`**: the 2D scene is re-rendered at the window's resolution (sharp at any size; UI and world scale with the window) rather than upscaling a fixed low-res image.
- **Aspect `expand`**: keeps the base aspect visible and reveals *extra* world/UI on the sides (or top/bottom) when the window's aspect differs. On ultrawide windows the player sees more of the level horizontally. Keep this in mind for level design (things off-screen at 16:9 may be visible on ultrawide) and for UI anchoring.
- Fullscreen is not a project setting; it's toggled at runtime by `scripts/Global/check_button.gd` (`DisplayServer.window_set_mode` FULLSCREEN/WINDOWED), state kept in the `PauseMenue` autoload (`full_screen`).
- The player camera also applies `zoom = 1.2` (in `character.tscn`), so the visible world area is `viewport / 1.2`.

### Texture filtering

```ini
[rendering]
textures/canvas_textures/default_texture_filter=0
```

`0` = **Nearest**: pixel art stays crisp, no blur. New sprites inherit this unless a node overrides `texture_filter`.

---

## Autoloads (singletons)

| Name | Script | Notes |
|---|---|---|
| `HeldItemManager` | `scripts/Global/HeldItemManager.gd` | Shared state: `held_item` (RigidBody2D), `is_held` (bool). Logic lives in `GrabObject`. |
| `PauseMenue` | `scripts/Global/pause_menue.gd` | `process_mode = Always`; handles the `pause` action, spawns/frees the menu scene, holds `full_screen` and `pause_menu` state. |

Both are registered with a leading `*` (enabled as global-name singletons). Note the project-wide "menue" spelling: keep it consistent.

---

## Input map

Defined in `project.godot` `[input]` (all with deadzone 0.2). Use action names in code, never raw keycodes. Keys are stored as **physical keycodes** (layout-independent: they refer to the key position, so "WASD" stays WASD on AZERTY).

| Action | Binding | Used by |
|---|---|---|
| `left` | **A** | `character_movement.gd`, `boat_driver.gd`, `grab_object.gd` (facing) |
| `right` | **D** | same as above |
| `jump` | **Space** | `character_movement.gd` (jump), `hook_input.gd` (jump off rope) |
| `climb_up` | **W** | `rope_reel.gd` (reel in), `swing_controller.gd`, `dock_1.gd` |
| `climb_down` | **S** | `rope_reel.gd` (let rope out), `swing_controller.gd` |
| `interact` | **E** | boat mount/dismount (`boat_highlight.gd`), `lever.gd`, market entry (`dock_1_enter_market.gd`), `dock_ui.gd` |
| `pickup` | **F** | `grab_object.gd` - pick up an item |
| `drop` | **G** | `grab_object.gd` - drop held item (small toss) |
| `shoot` | **Left Mouse** | `hook_input.gd` (throw/recall hook when nothing is held), `grab_object.gd` (throw held item at mouse) |
| `aim` | **Right Mouse** | `trajectory.gd` (show aim preview) |
| `grab` | **Left Mouse** | **not referenced by any script** (unused; duplicate of `shoot`'s binding) |
| `pause` | **Esc** | `PauseMenue` autoload (`_unhandled_input`) |

Things to know:
- `shoot` does two jobs: with an item held it throws the item; with nothing held it throws the hook. The hook script checks `HeldItemManager.is_held` to avoid both firing.
- **Right mouse is used by both `aim` and `camera_pan.gd`**, which reads `MOUSE_BUTTON_RIGHT` directly (not via an action) for the look-ahead pan. Rebinding `aim` will not move the camera pan.
- The pickup prompt text is hardcoded ("Press 'F' to pickup" in `debris.tscn`); it does not follow rebinds.
- The boat prompt says `Press "E" to Enter` (hardcoded Label text in `boat.tscn`).
- Adding a binding: add it in Project Settings -> Input Map, then use `Input.is_action_*` / `event.is_action_pressed` with the action name.

---

## Physics layers (2D)

Named in `[layer_names]`. Bit value = what you see in a saved `collision_layer` / `collision_mask` number.

| # | Name | Bit value | Typical owners |
|---|---|---|---|
| 1 | `world` | 1 | Level TileMap (`physics_layer_0/collision_layer = 1`) |
| 2 | `player` | 2 | Character |
| 3 | `object` | 4 | Debris, broken plank, grenade, `movable_object` |
| 4 | `hook` | 8 | Line-Hook (also `rope_piece`, see quirks) |
| 5 | `water` | 16 | `water_spring` Areas |
| 6 | `boat_interior` | 32 | Boat `CargoArea` Area2D |
| 7 | `dock` | 64 | Dock TileMap / dock body |
| 8 | `boat` | 128 | Boat body (also `static_rope`, see quirks) |
| 9 | `boundary` | 256 | Invisible level-edge walls |

### Layer/mask values actually used in scenes

| Node | Layer | Mask | Reads as |
|---|---|---|---|
| Character | 2 | 391 | is **player**; hits world, player, object, boat, boundary |
| Boat body | 128 | 261 | is **boat**; hits world, object, boundary |
| Boat `CargoArea/Area2D` | 32 | 6 | is boat_interior; senses player + object |
| Boat `BoatHighlight/Area2D` | 1 (default) | 2 | senses player |
| Line-Hook | 8 | 5 (script sets mask to `stick_to_layers`) | is hook; Character overrides `stick_to_layers = 197` = world + object + dock + boat |
| Debris / broken plank / grenade / movable_object | 4 | 7 (plank/grenade: 5) | is object; hits world (+ player, + object for 7) |
| `water_spring` Area2D | 16 | 6 | is water; senses player + object |
| Level TileMap (`level_0`/`level_1`) | 1 | - | world |
| Dock TileMap | 64 | 0 | dock; its StaticBody: layer 64, mask 130 (player + boat) |
| Boundary walls `InvisWall`/`InvusWall2` (level_1) | 256 | 134 | is boundary; senses player, object, boat |
| `proximity_highlight`, tutorial triggers, kill zones (player), market entry | 0 | 2 | senses player only |
| `object_kill_zone` | 0 | 4 | senses objects only |
| `floating_debris` PushArea | 0 | 2 | senses player |

Decoding a mask: add the bit values (e.g. `391 = 256 + 128 + 4 + 2 + 1` -> boundary, boat, object, player, world).

### Quirks noticed (worth checking if physics behave oddly)

- **`rope_piece.tscn`** uses layer/mask `8` (the `hook` layer) and **`static_rope.tscn`** uses `128` (the `boat` layer). Rope pieces therefore only collide with other bodies on those layers. Possibly intentional (ropes collide with nothing else) but the layer names don't match their purpose.
- The **Character's mask (391) does not include `dock` (64)**, so the player doesn't collide with dock bodies through layers. Check `dock_1.gd` if dock interaction changes.
- `boundary` walls have mask 134 (player + object + boat) even though walls are static; the mask is only relevant for their own contact reporting.

---

## Groups

Not stored in `project.godot`; set on nodes in scenes. Relevant one: `water` (on `Water_Body` instances) - `scripts/Boat/buoyancy2.gd` finds the water via `get_tree().get_first_node_in_group("water")`.

---

## Export

`export_presets.cfg` has one preset:

| Field | Value |
|---|---|
| Name / platform | `Windows Desktop` |
| Export path | `../../Dingi.exe` (outside the repo, two levels up) |
| Architecture | x86_64 |
| Embed PCK | yes (single exe) |
| Export filter | all resources |
| Script export mode | `2` (compressed text) |
| Texture formats | S3TC/BPTC on, ETC2/ASTC off |
| Console wrapper | `debug/export_console_wrapper = 1` (console only in debug) |
| Product name | `Dingi Demo` |
| Company | `K6 Interactive` |
| File/product version | `0.1` |
| Icon | not set (`application/icon=""`; falls back to project icon) |
| Code signing | off; encryption off; shader baker off |

Exporting requires Godot's Windows export templates installed for 4.7.

---

## Editor-only settings

`[file_customization]` colors folders in the FileSystem dock: `assets/` purple, `scenes/` green, `scripts/` pink, `shaders/` orange. No runtime effect.

---

## Appendix: `project.godot` (with `[input]` events condensed)

The raw `[input]` block stores serialized `InputEventKey`/`InputEventMouseButton` objects (long single lines); their meaning is decoded in the table above, so they are shortened here.

```ini
; Engine configuration file.
config_version=5

[application]
config/name="Dingi"
run/main_scene="uid://cv4m7kv8bksn8"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]
HeldItemManager="*uid://2e2ijn4pbjhs"
PauseMenue="*uid://dhn7ugiqrm47v"

[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[file_customization]
folder_colors={
"res://assets/": "purple",
"res://scenes/": "green",
"res://scripts/": "pink",
"res://shaders/": "orange"
}

[input]
; shoot      = MouseButton 1 (left)
; left       = physical key 65  (A)
; right      = physical key 68  (D)
; jump       = physical key 32  (Space)
; aim        = MouseButton 2 (right)
; grab       = MouseButton 1 (left)   (unused in code)
; pickup     = physical key 70  (F)
; drop       = physical key 71  (G)
; climb_up   = physical key 87  (W)
; climb_down = physical key 83  (S)
; interact   = physical key 69  (E)
; pause      = physical key 4194305 (Escape)
; each action: "deadzone": 0.2

[layer_names]
2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="object"
2d_physics/layer_4="hook"
2d_physics/layer_5="water"
2d_physics/layer_6="boat_interior"
2d_physics/layer_7="dock"
2d_physics/layer_8="boat"
2d_physics/layer_9="boundary"

[physics]
3d/physics_engine="Jolt Physics"

[rendering]
textures/canvas_textures/default_texture_filter=0
rendering_device/driver.windows="d3d12"
```

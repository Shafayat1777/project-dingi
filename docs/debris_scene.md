# Debris — scene reference

The project has **two unrelated things called "debris"**. Don't mix them up:

| | Pickable Debris | Floating Debris |
|---|---|---|
| Scene | `scenes/Throwable/debris.tscn` | `scenes/water/floating_debris.tscn` |
| Script | `scripts/Global/grab_object.gd` (+ `proximity_highlight.gd` via sub-scene) | `scripts/Water/floating_debris.gd` |
| Root | `RigidBody2D` | `Node2D` |
| Purpose | Physical plank/log the player can pick up, drop, throw | Decorative leaves/moss/lily pads/branches/petals on water |
| Spawned by | Placed by hand in level scenes | Spawned in code by `water_body.gd` and `reflection_patch.gd` |

Note the folder-case inconsistency: `scenes/water/` (lowercase) for the floating debris scene vs `scripts/Water/`. Preload paths in code use the lowercase form (`res://scenes/water/floating_debris.tscn`). Keep it as-is.

---

## 1. Pickable Debris (`scenes/Throwable/debris.tscn`)

A wooden-post-looking `RigidBody2D` the player can carry. It has **no custom script of its own** — all behavior comes from two reusable components (the project's standard pickupable pattern; see CLAUDE.md "Pickup/carry system").

### Node structure

```
Debris (RigidBody2D)                    collision_layer=4 (object), collision_mask=7 (world|player|object), input_pickable=true
├── Sprite2D                            AtlasTexture from assets/tileset/Tiles.png, region Rect2(160, 296, 32, 56), rotation -90°
├── CollisionShape2D                    RectangleShape2D 26.5 x 52.5, pos (0.75, 0.25), rotation -90°
├── Proximity-Highlight                 (instance of scenes/Global/proximity_highlight.tscn)
│                                       popup_text = "Press 'F' to pickup", detection_size = (90, 40)
└── GrabObject (Node2D)                 script = scripts/Global/grab_object.gd
```

Signal connections (in the scene):
- `Proximity-Highlight.body_entered` → `GrabObject._on_proximity_highlight_body_entered`
- `Proximity-Highlight.body_exited`  → `GrabObject._on_proximity_highlight_body_exited`

Sprite and collision shape are both rotated -90° (lying on its side: the 32x56 tile is drawn horizontally, shape is 26.5 wide x 52.5 tall *before* rotation).

### Physics layers

`collision_layer = 4` → bit 3 → **object** (layer 3). `collision_mask = 7` → bits 1+2+3 → **world (1) + player (2) + object (3)**. It does not collide with water (5), boat (8), dock (7) or boundary (9) layers.

Consequence: the body has **no buoyancy** — no `buoyant_object.gd` is attached, so in water it sinks / is only affected by the water spring `Area2D`s' drag (`water_spring.gd` `water_drag`). Attach `scripts/Water/buoyant_object.gd` (and set `water_body_path`) if it should float.

### Component: `GrabObject` (`scripts/Global/grab_object.gd`, `class_name GrabObject`)

Attached as a child `Node2D`; treats `get_parent()` as the `RigidBody2D` to move. Exports `throw_force = 800`.

Runs every `_physics_process`:
1. Updates `facing_direction` from `left`/`right` axis (used for drop toss direction).
2. Calls `pick_up()`, `drop()`, `throw()`, each of which polls its own input action.

| Action | Trigger | What happens |
|---|---|---|
| `pick_up()` | `pickup` just pressed (**F**), `marker` set (player in range), `HeldItemManager.is_held == false` | Sets `freeze=true` (kinematic freeze mode), reparents the body under the player's `Pickable-Position` `Marker2D`, zeroes position/rotation, saves then zeroes collision layer/mask, sets `HeldItemManager.held_item/is_held` |
| `drop()` | `drop` just pressed and `HeldItemManager.held_item == object` | Reparents to `current_scene` keeping global position, restores layer/mask, unfreezes, `linear_velocity = (200 * facing_direction, -150)` |
| `throw()` | `shoot` just pressed (left mouse) and held | Same reparent/restore, then `linear_velocity = direction_to_mouse * throw_force` |

`marker` is set by `_on_proximity_highlight_body_entered` via `body.get_node_or_null("Pickable-Position")` (so only bodies that have that marker — the player — enable pickup) and cleared on exit. Note: it is cleared on exit only; when the body is picked up the marker stays valid as the item now sits under it.

Global state: `HeldItemManager` autoload (`scripts/Global/HeldItemManager.gd`) — `held_item: RigidBody2D`, `is_held: bool`. Only one item can be held at a time.

Caveats worth knowing:
- The whole pickup logic runs on every instance every physics frame; each one only acts if its own `marker` is set (player in *its* range) or it is the currently held item.
- `pick_up`/`drop`/`throw` all read `Input.is_action_just_pressed` in `_physics_process`, not `_input`.
- Drop/throw restore the layer/mask saved at pickup (`held_item_layer/mask`), so those must be captured before they're zeroed — already handled.

### Component: `Proximity-Highlight` (`scenes/Global/proximity_highlight.tscn`, `scripts/Global/proximity_highlight.gd`, `class_name InteractionPrompt`)

```
Proximity-Highlight (Area2D)     collision_layer=0, collision_mask=2 (player)
├── CollisionShape2D             RectangleShape2D (resized at runtime to detection_size)
└── Label                        prompt text
```

Exports: `popup_text` (default "Press E to interact"; Debris overrides to "Press 'F' to pickup"), `gap_above = 10`, `detection_size = (64, 64)` (Debris: 90x40).

Behavior:
- `_ready`: resizes the detection rectangle; sets and hides the label; finds the parent's `Sprite2D` (fallback `AnimatedSprite2D`) and, if it has no material, assigns a `ShaderMaterial` using `res://shaders/Objects/outline.gdshader`; sets `label.top_level = true`; waits one frame then `_calculate_offset()`.
- `_process`: positions the label at `parent.global_position + offset_from_target` with rotation 0, so it stays upright and centered above the item even while the RigidBody tumbles.
- `_on_body_entered/exited`: if the body is a `CharacterBody2D` (and the player isn't already holding something on enter) shows/hides the label and toggles the shader's `enabled` uniform.
- `_calculate_offset`: height from parent's `CollisionShape2D` (Rectangle/Circle/Capsule), falling back to sprite texture height; offset = `(-label.width/2, -height/2 - gap_above - label.height)`.

Gotchas:
- Height uses the shape's **unrotated** `size.y` (52.5 for Debris) even though the shape is rotated -90°, so the label floats a bit higher than the visual top of the lying post.
- The outline shader (`shaders/Objects/outline.gdshader`) has uniforms `enabled` (bool), `outline_color` (white default), `outline_width` (1.0), and draws a 4-neighbour alpha outline around the sprite's transparent pixels.
- The label text mentions **F** because `pickup` is bound to key F (`physical_keycode 70`) in `project.godot`; if the binding changes, update `popup_text` in the scene.

### Where it's used

Instanced directly under the level root:
- `scenes/Map/level_1.tscn`: `Debris` (2218, 482), `Debris2` (2381, 525), `Debris3` (2545, 536)
- `scenes/Map/level_0.tscn`: `Debris`, `Debris2`

Respawn if it falls out of the level: `object_kill_zone.gd` (teleports any `RigidBody2D` to the `ObjectSpawner` marker) — `ObjectKillZone`/`ObjectKillZone2` in `level_1.tscn`.

### How to make another pickable like this

Copy the structure: `RigidBody2D` + `Sprite2D` + `CollisionShape2D` + instance `proximity_highlight.tscn` + `Node2D` with `grab_object.gd`, then connect the two `body_entered/exited` signals as above. Use `collision_layer=4`, `collision_mask=7`. See also `scenes/movable_object.tscn` and other `scenes/Throwable/*.tscn`.

---

## 2. Floating Debris (`scenes/water/floating_debris.tscn`)

Purely cosmetic, procedurally drawn items drifting/bobbing on the water surface. No art assets: shapes are polygons drawn in `_draw()`.

### Node structure

```
FloatingDebris (Node2D)           script = scripts/Water/floating_debris.gd
└── PushArea (Area2D)             collision_layer=0, collision_mask=2 (player)
    └── CollisionShape2D          CircleShape2D radius 20
```

### Script: `scripts/Water/floating_debris.gd`

`enum DebrisType { LEAF, MOSS, LILY_PAD, BRANCH, PETAL }`, `@export var debris_type` (default LEAF), `@export var base_color = Color(0.35, 0.45, 0.15, 0.9)` (used by LEAF and MOSS only).

Fixed colors: `LILY_PAD_COLOR` (0.25,0.55,0.2), `BRANCH_COLOR` (0.32,0.22,0.14), `PETAL_COLORS` (4 pinks/peach pastels, one picked at random per petal).

**Runtime-set fields (assigned by the spawner before/after `add_child`):**

| Field | Meaning |
|---|---|
| `drift_speed` | px/s to the right; 0 for moss (static) |
| `bob_amplitude`, `bob_speed`, `bob_phase` | sine bobbing on the surface |
| `base_x` | drift position along x — owned by the spawner |
| `depth_offset` | fixed downward offset so some pieces sit inside the reflective fill |
| `push_offset` | smoothed displacement from the player — owned by this script |

`push_offset` is the contract that keeps the two update loops from fighting: the spawner writes `position` each physics frame as `base_x + push_offset.x`, `surface_y + bob + push_offset.y + depth_offset`; this script only smooths `push_offset`.

**`_ready`** → `randomize_shape()`.

**`_process(delta)`**: only for `LEAF`, with a `PushArea` present, sums a push away from every overlapping body (`push_strength = 6`, `push_radius = 20`, falloff `1 - dist/radius`), then `push_offset = push_offset.lerp(target, clamp(push_smoothing(6) * delta, 0, 1))`. So leaves get nudged away from the swimming/wading player and ease back afterwards. Other types ignore the player.

**`randomize_shape()`**: picks `scale_factor` 0.8–1.3, random rotation, builds `shape_points` per type, then scales points and `detail_lines` and calls `queue_redraw()`:

| Type | Shape | Color | Extras |
|---|---|---|---|
| LEAF | 8-point almond (~6x10 px) | `base_color` w/ hue ±0.03, value ×0.85–1.15 | center vein line |
| MOSS | 8 points around a circle, radius 3–6 (blobby) | same as leaf | — |
| LILY_PAD | 10-step arc radius 7 + center, with a 20° half-angle notch | `LILY_PAD_COLOR` jittered | per-vertex gradient (lighter warm center), 3 vein lines |
| BRANCH | thin pointed stick 28 x 3 px | `BRANCH_COLOR` jittered | 3 knot tick lines |
| PETAL | 8-point teardrop (~5x7 px) | random from `PETAL_COLORS` jittered | — |

**`_draw()`**: `draw_polygon` with per-vertex colors if provided (lily pad) else `draw_colored_polygon`; then the leaf vein and any `detail_lines` as 0.5px lines in `shape_color.darkened(0.3)`.

### Spawner 1: `scripts/Water/water_body.gd` (real water)

Preloads `floating_debris.tscn` and spawns in `_ready` via `spawn_floating_debris()`; moves them in `_physics_process` via `update_floating_debris(delta)`.

Exports (defaults): `leaf_count=30`, `moss_count=18`, `lily_pad_count=10`, `branch_count=8`, `petal_count=14`, `leaf_drift_speed_range=(4,10)`, `lily_pad_drift_speed_range=(1,3)`, `debris_bob_amplitude_range=(1,2.5)`, `debris_bob_speed_range=(0.8,1.6)`, `debris_depth_range=(0,140)`.

- Drift speeds: leaf/branch/petal use the leaf range, lily pad its own, moss 0.
- `add_debris` sets `z_index = foreground_z + 1`, random bob params/phase, `depth_offset` uniform in `debris_depth_range`, `base_x`, then `add_child` (children of the water body, so positions are local).
- `update_floating_debris`: advances `base_x` by `drift_speed*delta`, wrapping to the left edge past the right edge; sets position using `get_water_height_at_local_x(base_x)` (linear interpolation between bracketing springs, clamped at the ends) plus bob, push and depth.
- X range: `get_debris_world_x_range()` = first to last spring (the full visual span, not the ravine-limited wave range).
- `level_1.tscn` Water_Body overrides: `leaf_count=60`, `moss_count=35`, `petal_count=50`, `debris_depth_range=(0,200)`.

### Spawner 2: `scripts/Water/reflection_patch.gd` (decorative patch)

Same scene and shapes, but different plumbing (no springs):
- Frees `PushArea` before entering the tree (no collision/player interaction at all).
- Stores `drift_speed` and `baseline_y` as **meta** values (`set_meta`) instead of properties; bobbing uses `bob_amplitude/speed/phase`.
- Wraps horizontally within the polygon's local bounds; counteracts patch scale via `d.scale = 1/scale` so debris stays the same absolute size.
- Uses a throwaway "probe" instance only to read the `DebrisType` enum constants, then frees it.

---

## Ideas / open items

- Pickable Debris has no buoyancy and no weight tuning (default `RigidBody2D` mass); decide whether it should float (`buoyant_object.gd`).
- `popup_text` is hardcoded to "F"; it isn't derived from the input map.
- Floating debris: only `LEAF` reacts to the player; extending push to other types means changing the `debris_type == LEAF` check in `_process`.
- If `PushArea` is removed (as `reflection_patch.gd` does), `push_area` resolves to null and the push logic is skipped safely.

---

## Appendix: full source

Copies of the actual files as of writing. The files in the repo are the source of truth - if they differ, trust the repo and update this appendix.

### debris.tscn (pickable)

`scenes/Throwable/debris.tscn`

```ini
[gd_scene format=3 uid="uid://m6d5ugkostkw"]

[ext_resource type="Texture2D" uid="uid://hcoy34knh1nk" path="res://assets/tileset/Tiles.png" id="1_iq66d"]
[ext_resource type="PackedScene" uid="uid://bqoevqtoqjdr2" path="res://scenes/Global/proximity_highlight.tscn" id="2_gt442"]
[ext_resource type="Script" uid="uid://60t4gnt7v5qx" path="res://scripts/Global/grab_object.gd" id="3_eamrs"]

[sub_resource type="AtlasTexture" id="AtlasTexture_08r2w"]
atlas = ExtResource("1_iq66d")
region = Rect2(160, 296, 32, 56)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_6f4wy"]
size = Vector2(26.5, 52.5)

[node name="Debris" type="RigidBody2D" unique_id=1187859604]
collision_layer = 4
collision_mask = 7
input_pickable = true

[node name="Sprite2D" type="Sprite2D" parent="." unique_id=1751080509]
rotation = -1.5707964
texture = SubResource("AtlasTexture_08r2w")

[node name="CollisionShape2D" type="CollisionShape2D" parent="." unique_id=216633008]
position = Vector2(0.75, 0.24999997)
rotation = -1.5707964
shape = SubResource("RectangleShape2D_6f4wy")

[node name="Proximity-Highlight" parent="." unique_id=250086518 instance=ExtResource("2_gt442")]
popup_text = "Press 'F' to pickup"
detection_size = Vector2(90, 40)

[node name="GrabObject" type="Node2D" parent="." unique_id=1475393393]
script = ExtResource("3_eamrs")
metadata/_custom_type_script = "uid://60t4gnt7v5qx"

[connection signal="body_entered" from="Proximity-Highlight" to="GrabObject" method="_on_proximity_highlight_body_entered"]
[connection signal="body_exited" from="Proximity-Highlight" to="GrabObject" method="_on_proximity_highlight_body_exited"]

```

### proximity_highlight.tscn

`scenes/Global/proximity_highlight.tscn`

```ini
[gd_scene format=3 uid="uid://bqoevqtoqjdr2"]

[ext_resource type="Script" uid="uid://btr35cg5gbky0" path="res://scripts/Global/proximity_highlight.gd" id="1_uaxuy"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_6f4wy"]

[node name="Proximity-Highlight" type="Area2D" unique_id=250086518]
collision_layer = 0
collision_mask = 2
script = ExtResource("1_uaxuy")

[node name="CollisionShape2D" type="CollisionShape2D" parent="." unique_id=1316032357]
shape = SubResource("RectangleShape2D_6f4wy")
debug_color = Color(0.6346749, 0.52789843, 0, 0.41960785)

[node name="Label" type="Label" parent="." unique_id=1604855910]
offset_right = 40.0
offset_bottom = 23.0

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
[connection signal="body_exited" from="." to="." method="_on_body_exited"]

```

### grab_object.gd

`scripts/Global/grab_object.gd`

```gdscript
extends Node2D
class_name GrabObject

@export var throw_force: float = 800

var marker: Marker2D = null
var facing_direction: float = 1.0
var object: RigidBody2D
var held_item_layer: int = 0
var held_item_mask: int = 0

func _ready() -> void:
	object = get_parent()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("left", "right")

	if direction != 0:
		facing_direction = sign(direction)

	pick_up()
	drop()
	throw()

func _on_proximity_highlight_body_entered(body: Node2D) -> void:
	marker = body.get_node_or_null("Pickable-Position") as Marker2D

func _on_proximity_highlight_body_exited(body: Node2D) -> void:
	marker = null

func pick_up() -> void:
	if Input.is_action_just_pressed("pickup") and marker and not HeldItemManager.is_held:
		var target_marker := marker  # cache it before remove_child() can null the member var

		object.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		object.freeze = true
		var prev_parent = object.get_parent()
		prev_parent.remove_child(object)
		target_marker.add_child(object)

		object.position = Vector2.ZERO
		object.rotation = 0.0

		held_item_layer = object.collision_layer
		held_item_mask = object.collision_mask
		object.collision_layer = 0
		object.collision_mask = 0

		HeldItemManager.held_item = object
		HeldItemManager.is_held = true

func drop() -> void:
	if Input.is_action_just_pressed("drop") and HeldItemManager.held_item == object:
		var world = object.get_tree().current_scene
		var drop_pos = object.global_position

		object.get_parent().remove_child(object)
		world.add_child(object)
		object.global_position = drop_pos

		object.collision_layer = held_item_layer
		object.collision_mask = held_item_mask

		object.freeze = false
		object.sleeping = false
		object.linear_velocity = Vector2(200.0 * facing_direction, -150.0)

		HeldItemManager.held_item = null
		HeldItemManager.is_held = false

func throw() -> void:
	if Input.is_action_just_pressed("shoot") and HeldItemManager.held_item == object:
		var world = object.get_tree().current_scene
		var drop_pos = object.global_position

		object.get_parent().remove_child(object)
		world.add_child(object)
		object.global_position = drop_pos

		object.freeze = false
		object.sleeping = false

		object.collision_layer = held_item_layer
		object.collision_mask = held_item_mask

		var mouse_pos = object.get_global_mouse_position()
		var throw_direction = (mouse_pos - drop_pos).normalized()
		object.linear_velocity = throw_direction * throw_force

		HeldItemManager.held_item = null
		HeldItemManager.is_held = false

```

### proximity_highlight.gd

`scripts/Global/proximity_highlight.gd`

```gdscript
extends Area2D
class_name InteractionPrompt

@export var popup_text: String = "Press E to interact"
@export var gap_above: float = 10.0
@export var detection_size: Vector2 = Vector2(64, 64)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var character_body: CharacterBody2D = null

# CanvasItem is the common base class for BOTH Sprite2D and AnimatedSprite2D.
# Typing this as CanvasItem (instead of just Sprite2D) lets this one variable
# hold either type, so the outline shader works no matter which the object uses.
var target_sprite: CanvasItem = null

var offset_from_target: Vector2 = Vector2.ZERO  # cached local offset (relative to object), computed once

func _ready() -> void:
	# Set the detection zone size (this Area2D's own collision shape,
	# used to know when the player is close enough to interact).
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = detection_size

	label.text = popup_text
	label.hide()  # hidden until the player enters range

	# Look for a Sprite2D on the parent object first.
	target_sprite = get_parent().get_node_or_null("Sprite2D") as CanvasItem

	# If no Sprite2D was found, fall back to checking for an AnimatedSprite2D
	# instead (this is what your object uses).
	if target_sprite == null:
		target_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as CanvasItem

	# Apply the outline shader material to whichever sprite type was found.
	if target_sprite and target_sprite.material == null:
		target_sprite.material = ShaderMaterial.new()
		target_sprite.material.shader = load("res://shaders/Objects/outline.gdshader")

	# top_level = true makes this node ignore the parent's transform
	# completely (no inherited position, rotation, or scale/flip).
	label.top_level = true

	# Wait one frame so the Label's size is fully calculated based on its
	# text/font before we read label.size for centering.
	await get_tree().process_frame
	label.reset_size()

	_calculate_offset()

func _process(_delta: float) -> void:
	# Every frame, manually place the label at the object's current
	# global position plus our fixed offset, so it stays "above" the
	# object regardless of the object's rotation or flip.
	var target := get_parent() as Node2D
	label.global_position = target.global_position + offset_from_target
	label.rotation = 0.0  # keep it always upright, never rotated

func _on_body_entered(body: Node2D) -> void:
	# Only react to the player (CharacterBody2D), and only if the player
	# isn't currently holding something.
	if body is CharacterBody2D and not HeldItemManager.is_held:
		label.show()
		character_body = body
		_set_outline(true)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		label.hide()
		character_body = null
		_set_outline(false)

func _set_outline(value: bool) -> void:
	# Toggle the shader's "enabled" uniform on/off to turn the outline
	# effect on the sprite on or off. Works the same whether target_sprite
	# is a Sprite2D or AnimatedSprite2D, since both use "material" the same way.
	if target_sprite and target_sprite.material is ShaderMaterial:
		target_sprite.material.set_shader_parameter("enabled", value)

func _calculate_offset() -> void:
	var target := get_parent()
	var height := 0.0

	var col_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape and col_shape.shape:
		var shape := col_shape.shape
		if shape is RectangleShape2D:
			height = shape.size.y
		elif shape is CircleShape2D:
			height = shape.radius * 2
		elif shape is CapsuleShape2D:
			height = shape.height

	if height == 0.0:
		if target_sprite is Sprite2D and target_sprite.texture:
			height = target_sprite.texture.get_height() * target_sprite.scale.y

		elif target_sprite is AnimatedSprite2D:
			# Cast explicitly so the editor recognizes AnimatedSprite2D-specific
			# properties like sprite_frames and animation.
			var anim_sprite := target_sprite as AnimatedSprite2D

			var frames: SpriteFrames = anim_sprite.sprite_frames
			var anim: String = anim_sprite.animation
			if frames and frames.get_frame_count(anim) > 0:
				var tex: Texture2D = frames.get_frame_texture(anim, 0)
				if tex:
					height = tex.get_height() * anim_sprite.scale.y

	offset_from_target = Vector2(-label.size.x / 2, -(height / 2) - gap_above - label.size.y)

```

### HeldItemManager.gd

`scripts/Global/HeldItemManager.gd`

```gdscript
# HeldItemManager.gd
extends Node

var is_held: bool = false
var held_item: RigidBody2D = null

```

### outline.gdshader

`shaders/Objects/outline.gdshader`

```glsl
shader_type canvas_item;

uniform bool enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (enabled) {
		vec2 texel_size = outline_width / vec2(textureSize(TEXTURE, 0));

		float alpha = tex_color.a;
		if (alpha < 1.0) {
			float outline_alpha = 0.0;
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(texel_size.x, 0)).a);
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV - vec2(texel_size.x, 0)).a);
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0, texel_size.y)).a);
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV - vec2(0, texel_size.y)).a);

			if (outline_alpha > 0.0 && alpha < 0.1) {
				tex_color = outline_color;
				tex_color.a = outline_alpha;
			}
		}
	}

	COLOR = tex_color;
}
```

### floating_debris.tscn

`scenes/water/floating_debris.tscn`

```ini
[gd_scene format=3 uid="uid://c4f8n2wq7xk5v"]

[ext_resource type="Script" path="res://scripts/Water/floating_debris.gd" id="1_debris"]

[sub_resource type="CircleShape2D" id="CircleShape2D_debris"]
radius = 20.0

[node name="FloatingDebris" type="Node2D"]
script = ExtResource("1_debris")

[node name="PushArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="PushArea"]
shape = SubResource("CircleShape2D_debris")

```

### floating_debris.gd

`scripts/Water/floating_debris.gd`

```gdscript
extends Node2D

## Small floating leaf/moss decoration for water surfaces.
## Position is driven externally by water_body.gd (which samples the spring
## height at this node's x each physics frame) - this script only owns the
## procedural shape/color, drawn via _draw() the same way smooth_path_modified.gd
## draws the border line, since no leaf/moss art assets exist in the project.

enum DebrisType { LEAF, MOSS, LILY_PAD, BRANCH, PETAL }

@export var debris_type: DebrisType = DebrisType.LEAF
#used for LEAF/MOSS (their original shared color); LILY_PAD/BRANCH/PETAL use
#their own fixed tones instead, since one exported color doesn't suit all types
@export var base_color: Color = Color(0.35, 0.45, 0.15, 0.9)
const LILY_PAD_COLOR = Color(0.25, 0.55, 0.2, 0.95)
const BRANCH_COLOR = Color(0.32, 0.22, 0.14, 0.95)
#a small palette so petals sprinkle in varied pastel tones rather than all
#being identical
const PETAL_COLORS = [
	Color(0.95, 0.55, 0.65, 0.95),
	Color(0.98, 0.85, 0.9, 0.95),
	Color(0.9, 0.4, 0.5, 0.95),
	Color(0.98, 0.75, 0.55, 0.95),
]

#set by water_body.gd before spawning; drift_speed stays 0 for moss (static)
var drift_speed: float = 0.0
var bob_amplitude: float = 2.0
var bob_speed: float = 1.0
var bob_phase: float = 0.0

#water_body.gd owns base_x (drift/wrap) and reads push_offset each frame to
#compose the final position; this node only owns and smooths push_offset
#itself, so the two update loops never fight over .position directly
var base_x: float = 0.0
var push_offset: Vector2 = Vector2.ZERO

#fixed downward offset assigned once at spawn (water_body.gd), so some debris
#sits visibly within the reflective water fill rather than all of it lining up
#exactly on the surface line
var depth_offset: float = 0.0
@export var push_strength = 6.0
@export var push_radius = 20.0
@export var push_smoothing = 6.0
@onready var push_area: Area2D = $PushArea if has_node("PushArea") else null

var shape_points: PackedVector2Array = PackedVector2Array()
var shape_color: Color
var vein_length: float = 0.0
#optional per-vertex colors (same size as shape_points) for a subtle gradient
#fill instead of one flat color - used by LILY_PAD; empty for the other types
var shape_vertex_colors: PackedColorArray = PackedColorArray()
#tick mark positions for BRANCH knots, and lily-pad veins; local-space line
#segments drawn on top of the fill in _draw()
var detail_lines: Array = []

func _ready():
	randomize_shape()

func _process(delta):
	#continuously eases push_offset toward a target based on current overlap,
	#instead of one-off kicks on body_entered - smooth in both directions
	#(approach and recovery) and self-correcting if the character lingers
	var target_offset = Vector2.ZERO

	if debris_type == DebrisType.LEAF and push_area:
		for body in push_area.get_overlapping_bodies():
			var away = global_position - body.global_position
			var dist = away.length()
			if dist < 0.01:
				continue
			var proximity = clamp(1.0 - dist / push_radius, 0.0, 1.0)
			target_offset += (away / dist) * push_strength * proximity

	push_offset = push_offset.lerp(target_offset, clamp(push_smoothing * delta, 0.0, 1.0))

func randomize_shape():
	var scale_factor = randf_range(0.8, 1.3)
	rotation = randf_range(0.0, TAU)
	vein_length = 0.0
	detail_lines = []
	shape_vertex_colors = PackedColorArray()

	match debris_type:
		DebrisType.LEAF:
			shape_color = Color.from_hsv(
				base_color.h + randf_range(-0.03, 0.03),
				base_color.s,
				clamp(base_color.v * randf_range(0.85, 1.15), 0.0, 1.0),
				base_color.a
			)
			vein_length = 5.0 * scale_factor
			shape_points = PackedVector2Array([
				Vector2(0, -5), Vector2(2.5, -2), Vector2(3, 0), Vector2(2.5, 2),
				Vector2(0, 5), Vector2(-2.5, 2), Vector2(-3, 0), Vector2(-2.5, -2)
			])

		DebrisType.MOSS:
			shape_color = Color.from_hsv(
				base_color.h + randf_range(-0.03, 0.03),
				base_color.s,
				clamp(base_color.v * randf_range(0.85, 1.15), 0.0, 1.0),
				base_color.a
			)
			var point_count = 8
			var points = PackedVector2Array()
			for i in range(point_count):
				var angle = (TAU / point_count) * i
				var r = randf_range(3.0, 6.0)
				points.append(Vector2(cos(angle), sin(angle)) * r)
			shape_points = points

		DebrisType.LILY_PAD:
			shape_color = Color.from_hsv(
				LILY_PAD_COLOR.h + randf_range(-0.02, 0.02),
				LILY_PAD_COLOR.s,
				clamp(LILY_PAD_COLOR.v * randf_range(0.9, 1.1), 0.0, 1.0),
				LILY_PAD_COLOR.a
			)
			#a ring of points sweeping most of the way around, then back to
			#center - the missing wedge is the classic lily-pad notch
			var radius = 7.0
			var arc_points = 10
			var notch_half_angle = deg_to_rad(20.0)
			var points = PackedVector2Array()
			for i in range(arc_points + 1):
				var t = float(i) / float(arc_points)
				var angle = notch_half_angle + t * (TAU - notch_half_angle * 2.0)
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			points.append(Vector2.ZERO)
			shape_points = points

			#warm highlight at the center fading to the rim color, instead of
			#one flat green fill
			var highlight_color = Color.from_hsv(
				clamp(shape_color.h + 0.08, 0.0, 1.0),
				shape_color.s * 0.6,
				clamp(shape_color.v * 1.3, 0.0, 1.0),
				shape_color.a
			)
			var colors = PackedColorArray()
			for i in range(points.size() - 1):
				colors.append(shape_color)
			colors.append(highlight_color)
			shape_vertex_colors = colors

			detail_lines = [
				[Vector2.ZERO, Vector2(cos(1.2), sin(1.2)) * radius],
				[Vector2.ZERO, Vector2(cos(2.6), sin(2.6)) * radius],
				[Vector2.ZERO, Vector2(cos(4.4), sin(4.4)) * radius],
			]

		DebrisType.BRANCH:
			shape_color = Color.from_hsv(
				BRANCH_COLOR.h + randf_range(-0.02, 0.02),
				BRANCH_COLOR.s,
				clamp(BRANCH_COLOR.v * randf_range(0.85, 1.15), 0.0, 1.0),
				BRANCH_COLOR.a
			)
			#a thin, pointed-end stick
			shape_points = PackedVector2Array([
				Vector2(-14, 0), Vector2(-10, -1.5), Vector2(10, -1.5),
				Vector2(14, 0), Vector2(10, 1.5), Vector2(-10, 1.5)
			])
			detail_lines = [
				[Vector2(-5, -1.5), Vector2(-6, -3.0)],
				[Vector2(1, 1.5), Vector2(2, 3.0)],
				[Vector2(6, -1.5), Vector2(7, -3.0)],
			]

		DebrisType.PETAL:
			var petal_base = PETAL_COLORS[randi() % PETAL_COLORS.size()]
			shape_color = Color.from_hsv(
				petal_base.h + randf_range(-0.015, 0.015),
				petal_base.s,
				clamp(petal_base.v * randf_range(0.9, 1.1), 0.0, 1.0),
				petal_base.a
			)
			#a small rounded teardrop - narrow point at one end, wide rounded
			#curve at the other
			shape_points = PackedVector2Array([
				Vector2(0, -4), Vector2(2, -2), Vector2(2.5, 0.5),
				Vector2(1, 2.5), Vector2(0, 3), Vector2(-1, 2.5),
				Vector2(-2.5, 0.5), Vector2(-2, -2)
			])

	for i in range(shape_points.size()):
		shape_points[i] *= scale_factor
	for line in detail_lines:
		line[0] *= scale_factor
		line[1] *= scale_factor

	queue_redraw()

func _draw():
	if shape_points.size() == 0:
		return
	if shape_vertex_colors.size() == shape_points.size():
		draw_polygon(shape_points, shape_vertex_colors)
	else:
		draw_colored_polygon(shape_points, shape_color)
	if debris_type == DebrisType.LEAF and vein_length > 0.0:
		draw_line(Vector2(0, -vein_length), Vector2(0, vein_length), shape_color.darkened(0.3), 0.5)
	for line in detail_lines:
		draw_line(line[0], line[1], shape_color.darkened(0.3), 0.5)

```

### water_body.gd - debris section only (lines 99-203)

`scripts/Water/water_body.gd`

```gdscript
func get_debris_world_x_range() -> Vector2:
	#the water's visual fill (Water_Polygon) already spans the whole body, even
	#though wave motion/border opacity are ravine-restricted - debris follows
	#the visual span, not the narrower wave-only range
	return Vector2(springs[0].position.x, springs[springs.size() - 1].position.x)

#small drifting leaves + static moss patches floating on the surface, purely
#decorative (no art assets exist, so shapes are drawn procedurally - see
#scripts/Water/floating_debris.gd). Position is driven here each physics frame
#by sampling the spring height at each debris's x, reusing the same bracketing-
#spring interpolation buoyant_object.gd already uses for the same purpose.
@onready var floating_debris_scene = preload("res://scenes/water/floating_debris.tscn")
@export var leaf_count = 30
@export var moss_count = 18
@export var lily_pad_count = 10
@export var branch_count = 8
#"sprinkles" - kept sparse compared to the other debris types
@export var petal_count = 14
@export var leaf_drift_speed_range = Vector2(4.0, 10.0)
@export var lily_pad_drift_speed_range = Vector2(1.0, 3.0)
@export var debris_bob_amplitude_range = Vector2(1.0, 2.5)
@export var debris_bob_speed_range = Vector2(0.8, 1.6)
#most debris stays near the surface (small values), but a random few are
#assigned a deeper offset so they sit visibly within the reflective fill
#instead of every piece lining up exactly on the wavy border
@export var debris_depth_range = Vector2(0.0, 140.0)
var floating_debris = []

func spawn_floating_debris():
	var x_range = get_debris_world_x_range()

	for i in range(leaf_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.LEAF
		d.drift_speed = randf_range(leaf_drift_speed_range.x, leaf_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(moss_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.MOSS
		d.drift_speed = 0.0
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(lily_pad_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.LILY_PAD
		d.drift_speed = randf_range(lily_pad_drift_speed_range.x, lily_pad_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(branch_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.BRANCH
		d.drift_speed = randf_range(leaf_drift_speed_range.x, leaf_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(petal_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.PETAL
		d.drift_speed = randf_range(leaf_drift_speed_range.x, leaf_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

func add_debris(d, x_local: float):
	d.z_index = foreground_z + 1
	d.bob_amplitude = randf_range(debris_bob_amplitude_range.x, debris_bob_amplitude_range.y)
	d.bob_speed = randf_range(debris_bob_speed_range.x, debris_bob_speed_range.y)
	d.bob_phase = randf_range(0.0, TAU)
	#uniform across the full range, so debris spreads evenly through the water's
	#depth instead of clustering near the surface
	d.depth_offset = randf_range(debris_depth_range.x, debris_depth_range.y)
	d.base_x = x_local
	d.position.x = x_local
	add_child(d)
	floating_debris.append(d)

func update_floating_debris(delta):
	if springs.size() < 2:
		return
	var x_range = get_debris_world_x_range()
	var t = Time.get_ticks_msec() * 0.001

	for d in floating_debris:
		if d.drift_speed > 0.0:
			d.base_x += d.drift_speed * delta
			if d.base_x > x_range.y:
				d.base_x = x_range.x

		var bob = sin(t * d.bob_speed + d.bob_phase) * d.bob_amplitude
		d.position = Vector2(
			d.base_x + d.push_offset.x,
			get_water_height_at_local_x(d.base_x) + bob + d.push_offset.y + d.depth_offset
		)

func get_water_height_at_local_x(x_local: float) -> float:
	#same bracketing-spring linear interpolation buoyant_object.gd uses, kept
	#local here since debris positions are in this node's local space already
	for i in range(springs.size() - 1):
		var a = springs[i]
		var b = springs[i + 1]
		if x_local >= a.position.x and x_local <= b.position.x:
			var lerp_t = (x_local - a.position.x) / (b.position.x - a.position.x)
			return lerp(a.position.y, b.position.y, lerp_t)

	if x_local < springs[0].position.x:
		return springs[0].position.y
	return springs[springs.size() - 1].position.y

```

### reflection_patch.gd - debris section only (lines 46-135)

`scripts/Water/reflection_patch.gd`

```gdscript
	# instantiate one throwaway node first just to read its DebrisType enum
	# constants (matches how water_body.gd references d.DebrisType.LEAF after
	# instancing, rather than hardcoding the enum's underlying int values here)
	var probe = floating_debris_scene.instantiate()
	_spawn_debris(probe.DebrisType.LEAF, leaf_count)
	_spawn_debris(probe.DebrisType.MOSS, moss_count)
	_spawn_debris(probe.DebrisType.LILY_PAD, lily_pad_count)
	_spawn_debris(probe.DebrisType.BRANCH, branch_count)
	_spawn_debris(probe.DebrisType.PETAL, petal_count)
	probe.free()

func _spawn_debris(debris_type, count: int):
	var bounds = _get_local_bounds()
	if bounds.size == Vector2.ZERO:
		return

	for i in range(count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = debris_type
		# strip all physics before this node ever enters the tree - no
		# PushArea means no collision shape, no character interaction
		if d.has_node("PushArea"):
			d.get_node("PushArea").queue_free()

		# always positive, matching water_body.gd's leaf_drift_speed_range
		# convention - the main water's debris only ever drifts one direction,
		# so the patch's debris should flow the same way, not a random mix
		d.set_meta("drift_speed", randf_range(debris_drift_speed_range.x, debris_drift_speed_range.y))
		d.bob_amplitude = randf_range(debris_bob_amplitude_range.x, debris_bob_amplitude_range.y)
		d.bob_speed = randf_range(debris_bob_speed_range.x, debris_bob_speed_range.y)
		d.bob_phase = randf_range(0.0, TAU)
		d.set_meta("baseline_y", randf_range(bounds.position.y, bounds.position.y + bounds.size.y))

		# counteract this patch's own node scale so debris stays the same
		# absolute size as the main water's debris, regardless of how big/small
		# this particular patch has been resized to
		if scale.x != 0 and scale.y != 0:
			d.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)

		d.position = Vector2(randf_range(bounds.position.x, bounds.position.x + bounds.size.x), d.get_meta("baseline_y"))
		add_child(d)
		patch_debris.append(d)

func _get_local_bounds() -> Rect2:
	if polygon.size() == 0:
		return Rect2()
	var min_p = polygon[0]
	var max_p = polygon[0]
	for p in polygon:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return Rect2(min_p, max_p - min_p)

func _process(delta):
	if polygon.size() == 0 or not material:
		return

	var min_y = polygon[0].y
	var max_y = polygon[0].y
	for p in polygon:
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var edge_local_y = min_y if mirror_edge == MirrorEdge.BOTTOM else max_y
	var edge_world_y = (global_transform * Vector2(0, edge_local_y)).y

	var vp = get_viewport()
	var screen_point = vp.get_canvas_transform() * Vector2(global_position.x, edge_world_y)
	var viewport_height = vp.get_visible_rect().size.y
	if viewport_height > 0:
		material.set_shader_parameter("water_level", screen_point.y / viewport_height)

	_update_debris(delta)

func _update_debris(delta):
	if patch_debris.is_empty():
		return
	var bounds = _get_local_bounds()
	var t = Time.get_ticks_msec() * 0.001

	for d in patch_debris:
		var drift_speed = d.get_meta("drift_speed")
		var x = d.position.x + drift_speed * delta
		if x > bounds.position.x + bounds.size.x:
			x = bounds.position.x
		elif x < bounds.position.x:
			x = bounds.position.x + bounds.size.x

		var bob = sin(t * d.bob_speed + d.bob_phase) * d.bob_amplitude
		d.position = Vector2(x, d.get_meta("baseline_y") + bob)

```

# Character — scene reference

The player: a `CharacterBody2D` with run/jump/swing movement, a look-ahead camera, an aim-preview line, a carry marker for pickups, and the grappling hook as a child. Also the thing that pushes `RigidBody2D`s around when it walks/stands on them.

- Scene: `scenes/Character/character.tscn` (instanced as `Character` in `scenes/Map/level_1.tscn`)
- Sub-scene: `scenes/Character/trajectory.tscn`
- Scripts: `scripts/character/character_movement.gd`, `camera_pan.gd`, `trajectory.gd`
- Hook: see [line_hook_scene.md](line_hook_scene.md)

---

## Node structure

```
Character (CharacterBody2D)            script: character_movement.gd
│                                      collision_layer=2 (player), collision_mask=391 (world|player|object|boat|boundary)
├── CollisionShape2D                   RectangleShape2D 20 x 63, at (-1, 0.5)
├── AnimatedSprite2D                   pos (-2, -33), scale 2x, autoplay "default"; atlas frames 96x96 from assets/character/
├── Trajectory (instance)              scenes/Character/trajectory.tscn - aim-preview line (Node2D + Line2D)
├── Camera2D                           pos (0,-1), offset (0,-100), zoom 1.2, limits left=0 top=0 bottom=823, limit_smoothed; script: camera_pan.gd
├── Pickable-Position (Marker2D)       at (-1, -52) - where held items are reparented (GrabObject looks this up by name)
└── Line-Hook (instance)               scenes/Throwable/line_hook.tscn; stick_to_layers=197, player=".."
```

### Animations (`AnimatedSprite2D`, SpriteFrames)

| Name | Source | Frames | Speed | Loop | Used when |
|---|---|---|---|---|---|
| `default` | `IDLE.png` | 10 | 16 | yes | on floor, no input |
| `running` | `RUN.png` | 16 | 20 | yes | on floor, moving |
| `jump` | `ATTACK 1.png` frame at x=576 | 1 | 5 | no | not on floor (also used while swinging/falling) |

Frames are `AtlasTexture` regions of 96x96 cut from horizontal strips.

### Physics layers

- Layer `2` = **player**. Mask `391` = bits 1+2+3+8+9 = world, player, object, boat, boundary. (Does not collide with hook, water, boat_interior, dock.)
- Other things detect the player via layer 2: `proximity_highlight` Areas (mask 2), boat `BoatHighlight` Area (mask 2), kill zones, cargo area (mask 6 = player+object).

### Groups / lookups other scripts rely on

- Child named exactly **`Pickable-Position`** (`Marker2D`): `grab_object.gd` calls `body.get_node_or_null("Pickable-Position")`.
- Child named **`CollisionShape2D`** and **`Camera2D`**: `boat_mount.gd` disables the shape and calls `reset_smoothing()` on the camera by these names.
- `is_swinging` (bool) and `JUMP_VELOCITY` (const): written/read by the hook scripts.

---

## `character_movement.gd`

Constants/exports: `SPEED=300`, `ACCELERATION=1000`, `FRICTION=1000`, `JUMP_VELOCITY=-400`, `push_force=60`; exports `swing_push_force=600`, `standing_weight_force=400`, `water_push_force=300`. `is_swinging` is set by `SwingController`.

Each `_physics_process`:
1. **Gravity** when not on floor (`get_gravity()`).
2. **Jump** on `jump` just pressed while on floor. (Jumping off the rope is handled in `hook_input.gd`.)
3. **Horizontal movement:**
   - `is_swinging`: `velocity.x += direction * swing_push_force * delta` (pump the swing; no speed cap, no friction).
   - else: `move_toward` target speed with `ACCELERATION`, and `FRICTION` to stop when on floor.
4. **Animation:** off-floor → `jump` (flip by direction), moving → `running`, else `default`. Note `flip_h = direction < 0` is set when airborne even with `direction == 0`, so the sprite faces right when you jump/fall with no input.
5. `move_and_slide()`.
6. **Contact forces onto `RigidBody2D`s** from the slide-collision loop:
   - Standing on top (`normal.dot(UP) > 0.7`): continuous `apply_force(0, standing_weight_force)` at the contact point → floating objects dip/bob.
   - Side contact with a body whose `is_submerged` is true: continuous horizontal `apply_central_force(-normal.x * water_push_force)`.
   - Any other side contact: one-shot `apply_central_impulse(-normal * push_force)`.

`is_submerged` is defined on bodies using `buoyant_object.gd` / `buoyancy2.gd`.

## `camera_pan.gd` (on `Camera2D`)

Exports `max_look_ahead=150`, `pan_speed=5`. While **right mouse** is held, target offset = vector to the mouse, limited to `max_look_ahead`; otherwise zero. `offset` lerps toward it, then `clamp_offset_to_limits` keeps the offset within the camera limits.

`clamp_offset_to_limits` derives bounds from a camera-center position (`cam_center`, itself clamped by `half_view`) — **not** raw player position — to match Godot's built-in limit clamp. If the player leaves the map area, `ref_pos` is clamped to the limits so both axes freeze together. Don't reintroduce raw `player_pos` into the `min_offset/max_offset` math (documented in CLAUDE.md).

Camera limits set in the scene: `limit_left=0`, `limit_top=0`, `limit_bottom=823`; `limit_right` is left at default (large) — level width is enforced by invisible boundary walls, not the camera.

## `trajectory.gd` + `trajectory.tscn`

```
Trajectory (Node2D)      trajectory.gd
└── Line2D               red→green gradient, rounded joints/caps
```

Every `_process`: `look_at(mouse)`; while `aim` is held, shows the Line2D and draws a 60-point parabola (`TIME_STEP=0.05`, `gravity=980`, `initial_velocity=(800,0)` rotated to aim); hides on `aim` release. The `shoot`+`throw()` branch is dead code (`pass`, commented `throw()`) — the real hook throw is in `hook_input.gd`. Because the node calls `look_at` every frame, the whole Trajectory node rotates toward the mouse at all times.

---

## Interactions

- **Pickups:** items reparent under `Pickable-Position` (see [debris_scene.md](debris_scene.md), `grab_object.gd`).
- **Boat:** `boat_mount.gd` reparents the Character under the Boat, disables its `_physics_process` and `CollisionShape2D`; on dismount teleports to the boat's `ExitMarker` (see [boat_scene.md](boat_scene.md)). The hook and camera come along as children.
- **Respawn:** `kill_zone_1.gd` / `water_kill_zone.gd` reposition the character to a `Marker2D`.
- **Pause:** `PauseMenue` autoload pauses the tree (Esc).

## Open items / gotchas

- `character_movement.gd` comment "swing-jumps are handled in line_hook.gd" is stale (now `hook_input.gd`).
- No coyote time, jump buffering or variable jump height.
- No air-speed cap while swinging (`swing_push_force` keeps adding velocity).
- `Trajectory` is always rotating toward the mouse even when not shown.

---

## Appendix: full source

Copies as of writing; the repo is the source of truth. The full `character.tscn` is ~250 lines, mostly `AtlasTexture` sub-resources; only the node section (from the `[node name="Character"` line onward) is reproduced.

### character.tscn (node section only)

`scenes/Character/character.tscn`

```ini
[node name="Character" type="CharacterBody2D" unique_id=376624278]
collision_layer = 2
collision_mask = 391
script = ExtResource("1_yenhn")

[node name="CollisionShape2D" type="CollisionShape2D" parent="." unique_id=1778992500]
position = Vector2(-1, 0.5)
shape = SubResource("RectangleShape2D_tuv23")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="." unique_id=2140670731]
position = Vector2(-2, -33)
scale = Vector2(2, 2)
sprite_frames = SubResource("SpriteFrames_6f4wy")
autoplay = "default"

[node name="Trajectory" parent="." unique_id=2144881746 instance=ExtResource("5_6xo28")]

[node name="Camera2D" type="Camera2D" parent="." unique_id=1323451590]
position = Vector2(0, -1)
offset = Vector2(0, -100)
zoom = Vector2(1.2, 1.2)
limit_left = 0
limit_top = 0
limit_bottom = 823
limit_smoothed = true
script = ExtResource("6_8idae")

[node name="Pickable-Position" type="Marker2D" parent="." unique_id=1815041864]
position = Vector2(-1, -52)

[node name="Line-Hook" parent="." unique_id=118512847 node_paths=PackedStringArray("player") instance=ExtResource("8_5lfdo")]
stick_to_layers = 197
player = NodePath("..")

```

### trajectory.tscn

`scenes/Character/trajectory.tscn`

```ini
[gd_scene format=3 uid="uid://5wipwqvwd6kx"]

[ext_resource type="Script" uid="uid://u533edynsrqj" path="res://scripts/character/trajectory.gd" id="1_02x5l"]

[sub_resource type="Gradient" id="Gradient_08r2w"]
colors = PackedColorArray(1, 0, 0, 1, 0, 0.99215686, 0.39607844, 1)

[node name="Trajectory" type="Node2D" unique_id=2144881746]
script = ExtResource("1_02x5l")

[node name="Line2D" type="Line2D" parent="." unique_id=1694604824]
gradient = SubResource("Gradient_08r2w")
joint_mode = 2
begin_cap_mode = 2
end_cap_mode = 2

```

### character_movement.gd

`scripts/character/character_movement.gd`

```gdscript
extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 300.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0
const JUMP_VELOCITY = -400.0
var push_force = 60.0

@export var swing_push_force := 600.0
@export var standing_weight_force := 400.0
@export var water_push_force := 300.0

var is_swinging := false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("left", "right")

	# swing-jumps are handled in line_hook.gd, not here
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if is_swinging:
		if direction != 0:
			velocity.x += direction * swing_push_force * delta
	else:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		elif is_on_floor():
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	if not is_on_floor():
		animated_sprite_2d.flip_h = direction < 0
		animated_sprite_2d.play("jump")

	elif direction != 0:
		animated_sprite_2d.flip_h = direction < 0
		animated_sprite_2d.play("running")
	
	else:
		animated_sprite_2d.play("default")

	move_and_slide()

	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidBody2D:
			var normal = c.get_normal()
			if normal.dot(Vector2.UP) > 0.7:
				# continuous weight, not an impulse, so a floating object dips and bobs
				collider.apply_force(Vector2(0, standing_weight_force), c.get_position() - collider.global_position)
			elif "is_submerged" in collider and collider.is_submerged:
				# continuous force outlasts the water drag that kills a one-shot impulse
				collider.apply_central_force(Vector2(-normal.x, 0) * water_push_force)
			else:
				collider.apply_central_impulse(-normal * push_force)

```

### camera_pan.gd

`scripts/character/camera_pan.gd`

```gdscript
extends Camera2D

@export var max_look_ahead: float = 150.0
@export var pan_speed: float = 5.0

func _process(delta):
	var target_offset = Vector2.ZERO

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_pos = get_global_mouse_position()
		var player_pos = get_parent().global_position
		var direction = mouse_pos - player_pos
		target_offset = direction.limit_length(max_look_ahead)

	offset = offset.lerp(target_offset, delta * pan_speed)
	offset = clamp_offset_to_limits(offset)

func clamp_offset_to_limits(desired_offset: Vector2) -> Vector2:
	var player_pos = get_parent().global_position
	var half_view = (get_viewport_rect().size / zoom) / 2.0

	# If the player has left the map area entirely, freeze both axes together
	var out_of_bounds = (
		player_pos.x < limit_left or player_pos.x > limit_right or
		player_pos.y < limit_top or player_pos.y > limit_bottom
	)

	var ref_pos = player_pos
	if out_of_bounds:
		ref_pos = Vector2(
			clamp(player_pos.x, limit_left, limit_right),
			clamp(player_pos.y, limit_top, limit_bottom)
		)

	# Matches Godot's internal camera clamp (accounts for half the view size)
	var cam_center = Vector2(
		clamp(ref_pos.x, limit_left + half_view.x, limit_right - half_view.x),
		clamp(ref_pos.y, limit_top + half_view.y, limit_bottom - half_view.y)
	)

	var min_offset = Vector2(
		limit_left + half_view.x - cam_center.x,
		limit_top + half_view.y - cam_center.y
	)
	var max_offset = Vector2(
		limit_right - half_view.x - cam_center.x,
		limit_bottom - half_view.y - cam_center.y
	)

	desired_offset.x = clamp(desired_offset.x, min_offset.x, max_offset.x)
	desired_offset.y = clamp(desired_offset.y, min_offset.y, max_offset.y)
	return desired_offset

```

### trajectory.gd

`scripts/character/trajectory.gd`

```gdscript
extends Node2D

@onready var line_2d: Line2D = $Line2D

@export var initial_velocity: Vector2 = Vector2(800, 0) # y = -600
@export var gravity: float = 980.0


const MAX_POINTS = 60
const TIME_STEP = 0.05  # how far apart in time each point is

#func _ready() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())

	if Input.is_action_pressed("aim"):
		line_2d.show()
		update_trajectory(delta)
		if Input.is_action_just_pressed("shoot"):
			if HeldItemManager.is_held == false:
				pass
				#throw()
	if Input.is_action_just_released("aim"):
		line_2d.hide()

func update_trajectory(_delta: float) -> void:
	line_2d.clear_points()
	
	var start_pos = global_position
	var velocity = initial_velocity.rotated(rotation)  # aim it with the node

	for i in MAX_POINTS:
		var t = i * TIME_STEP
		var point = start_pos + velocity * t + 0.5 * Vector2(0, gravity) * t * t
		line_2d.add_point(to_local(point))

```

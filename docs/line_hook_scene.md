# Line-Hook — scene reference

The grappling hook / rope. A `RigidBody2D` that is thrown at the mouse, sticks to world/objects/boat/dock, and lets the player swing, reel and tow objects. It is **instanced as a child of the Character scene** (node `Line-Hook`), not placed in levels.

> **Repo note:** `CLAUDE.md` still describes a single `scripts/Throwable/line_hook.gd`. That file no longer exists. The hook was split into small components under `scripts/HookRope/` (documented here). Comments in `character_movement.gd` ("swing-jumps are handled in line_hook.gd") are stale — the jump-off-rope logic is now in `hook_input.gd`.

- Scene: `scenes/Throwable/line_hook.tscn`
- Scripts: `scripts/HookRope/*.gd`
- Instanced in: `scenes/Character/character.tscn` (see [character_scene.md](character_scene.md))

---

## Node structure

```
Line-Hook (RigidBody2D)             script: hook.gd (class_name Hook)
│                                   collision_layer=8 (hook), collision_mask=5 (world|object), attached_friction=0.9
├── Sprite2D                        AtlasTexture from assets/items/rope_and_hook.png, region Rect2(0, 1, 16, 30)
├── CollisionShape2D                CircleShape2D r=5, at (0, -6)  (the hook tip)
├── Line2D                          width 3, brown (0.63, 0.42, 0.25) - the rope, drawn by RopeLineRenderer
├── HookAttachment (Node)           hook_attachment.gd   - what happens on first contact
├── HookInput (Node)                hook_input.gd        - shoot / jump input
├── HookRecaller (Node)             hook_recaller.gd     - recall + return-to-player
├── HookThrower (Node)              hook_thrower.gd      - throw + max range check
├── RopeReel (Node)                 rope_reel.gd         - climb_up/climb_down changes rope length, winches objects
├── RopeLineRenderer (Node)         rope_line_renderer.gd, segment_count=20  - verlet rope visual
└── SwingController (Node)          swing_controller.gd  - spring/damper rope physics on the player
```

Every component script does `@onready var hook: Hook = get_parent()` and reaches the others through `hook.<component>` (e.g. `hook.thrower.throw()`). Adding a new behavior = new child `Node` with a script following that convention, then call it from `hook.gd`'s `_physics_process` or from an existing component.

### Overrides when instanced in Character

`character.tscn` sets on the `Line-Hook` instance: `stick_to_layers = 197` (boat 128 + dock 64 + object 4 + world 1) and `player = NodePath("..")`. The scene file's own defaults are the script defaults.

`line_hook.tscn` contains lines like `throw_speed = null`, `recall_speed = null`, `max_range = null` … (Godot serialized exports that were reset). Worth verifying in the editor that these resolve to the script defaults below; if the hook ever behaves with 0 speed/range, that's where to look.

---

## State machine (`hook.gd`)

`enum State { IDLE, FLYING, STUCK, RECALLING }`

```
IDLE --shoot (nothing held)--> FLYING --body_entered--> STUCK
                                 |                        |
                        distance >= max_range             |
                                 v                        |
                             RECALLING <----shoot---------+   (also from FLYING via shoot)
                                 |            <---jump while is_swinging (with jump impulse)
                       within 20px of player
                                 v
                               IDLE (hidden, frozen)
```

`_physics_process` per state: `RECALLING → recaller.recall_hook()`, `FLYING → thrower.check_range()`, `STUCK → reel.handle_reel(delta)` then `swing_controller.constrain_rope(delta)`. `rope_renderer.simulate(delta)` runs every frame regardless.

`_ready`: `top_level = true` (ignores the player's transform), two initial Line2D points, `hide()`, `freeze = true`, `collision_mask = stick_to_layers`, contact monitor on (4 contacts), `body_entered` → `attachment._on_body_entered`.

### Exports (`Hook`)

| Export | Default | Meaning |
|---|---|---|
| `throw_speed` | 800 | launch speed toward mouse |
| `recall_speed` | 1000 | return speed |
| `max_range` | 500 | throw range and max rope length |
| `min_range` | 5 | shortest rope when reeled in |
| `reel_speed` | 200 | px/s the rope length changes on climb_up/down |
| `stick_to_layers` | 5 (world+object) | physics layers the hook sticks to (Character overrides to 197) |
| `player` | – | the `CharacterBody2D` (assign in inspector) |
| `attached_friction` | 0.1 (scene: 0.9) | friction temporarily applied to a stuck `RigidBody2D` so it can be dragged |
| `drag_strength` | 900 | extra pull (acceleration, px/s²) on a stuck object once rope is taut |
| `reel_pull_strength` | 600 | winch force on a stuck object while climb_up/down held |

Runtime vars: `state`, `stuck_body`, `current_rope_length`, `attach_offset` (stick point relative to `stuck_body` origin), `_original_physics_material`.

`attach_stuck_body(body, offset)` swaps in a low-friction `PhysicsMaterial`; `detach_stuck_body()` restores the original. **Always use `detach_stuck_body()`** rather than `stuck_body = null` or the object keeps the altered friction.

---

## Components

**`HookInput` (`_input`)**
- `shoot`: `IDLE` and `HeldItemManager.is_held == false` → `thrower.throw()`; `FLYING`/`STUCK` → `recaller.recall()`. (Shoot while holding a pickup throws the *pickup* via `GrabObject`, not the hook.)
- `jump` while `player.is_swinging`: sets `player.velocity.y = player.JUMP_VELOCITY` **then** recalls (order matters: `recall()` clears `is_swinging`).

**`HookThrower`**
- `throw()`: show, `FLYING`, detach any body, unfreeze, layer = 8 (hook), mask = `stick_to_layers`, teleport to the player's global position, `linear_velocity = dir_to_mouse * throw_speed`, rotate to face the direction.
- `check_range()`: if farther than `max_range` from the player → `RECALLING`.

**`HookAttachment.on_body_entered`** (ignored if already STUCK/RECALLING): state `STUCK`, freeze (deferred), zero velocity, `current_rope_length = min(distance to player, max_range)`; if the body is a `RigidBody2D`, `attach_stuck_body(body, hook_pos - body_pos)`.

**`HookRecaller`**
- `recall()`: `RECALLING`, detach body, `player.is_swinging = false`, unfreeze, clear collision layer and mask (deferred) so it flies through everything.
- `recall_hook()` (each frame): velocity toward player at `recall_speed`; within 20px → `IDLE`, frozen, hidden.

**`RopeReel.handle_reel`** (only while STUCK): `climb_up` shortens, `climb_down` lengthens `current_rope_length` by `reel_speed*delta`, clamped to `[min_range, max_range]`. If stuck to a `RigidBody2D`, also applies a winch force (`dir * sign * mass * reel_pull_strength`) toward/away from the player.

**`SwingController.constrain_rope`** (only while STUCK) — spring-damper, not a hard circle clamp:
1. If stuck to a body, moves the hook to `stuck_body.global_position + attach_offset` (follows the object).
2. `stretch = distance - current_rope_length`. If ≤ 0: slack, `is_swinging = false`, return.
3. `tension = dir*stretch*spring_stiffness(40) + (-dir * v_along_rope * spring_damping(6))`.
4. If a body is stuck and climb_up/down is held ("reeling_object"): `is_swinging = false`, tension is **not** applied to the player (prevents the player being yanked toward the object). Otherwise `is_swinging = true`, `player.velocity += tension*delta`, and a position safety push if `stretch > max_stretch(30)`.
5. If stuck to a body: applies `-tension` to it (Newton's 3rd) plus `-dir * mass * drag_strength` (mass-independent tow acceleration).

`player.is_swinging` is read by `character_movement.gd` to switch to air-control swing mode (see the character doc).

**`RopeLineRenderer`** — visual only; a verlet chain drawn into `Line2D`.
- Exports: `segment_count` (20 in scene, 12 default), `gravity` 900, `damping` 0.98, `stiffness_iterations` 8.
- `simulate(delta)`: IDLE → clear line and reset. Otherwise anchors point 0 to the player and last point to the hook, integrates the middle points with gravity, runs constraint passes with segment length = `current_rope_length / (n-1)` while STUCK (so slack/reeling is visible) or the live distance otherwise.
- `get_pull_direction()` / `get_chain_length()` exist but are currently **not used** by the swing physics.

---

## Interactions with other systems

- **Pickups:** `HookInput` refuses to throw while `HeldItemManager.is_held`; the same `shoot` action throws held items in `grab_object.gd`.
- **Objects towed:** any `RigidBody2D` on `stick_to_layers` (e.g. Debris, planks) can be pulled with the rope.
- **Boat:** boat layer (128) is in the Character's `stick_to_layers`, so the hook can stick to the boat.
- **Mounted on boat:** the hook lives under the player, and mounting only disables the player's `_physics_process`, not `HookInput._input`, so from the code the hook can still be thrown while aboard.
- `trajectory.gd` (aim preview) is unrelated to this hook; it's a separate dead-end throw preview (see character doc).

## Open items / gotchas

- Throw starts at the player's origin (`player.global_position`, i.e. feet area), not at the hand.
- `rope_line_renderer.gd` comments reference a "Verlet Rope + Elastic Swing section above" that doesn't exist anymore (it was in older docs).
- Hook `Sprite2D` has no code that rotates/flips it other than the body's `rotation = dir.angle()`.
- Update `CLAUDE.md` (Throwables section) to point at `scripts/HookRope/` instead of `line_hook.gd`.

---

## Appendix: full source

Copies as of writing; the repo is the source of truth.

### line_hook.tscn

`scenes/Throwable/line_hook.tscn`

```ini
[gd_scene format=3 uid="uid://1ltmwanatlap"]

[ext_resource type="Texture2D" uid="uid://cibdl2wkv15" path="res://assets/items/rope_and_hook.png" id="1_hxp0v"]
[ext_resource type="Script" uid="uid://btg4hpnykdlh6" path="res://scripts/HookRope/hook.gd" id="1_lq7qr"]
[ext_resource type="Script" uid="uid://bfg0mhmnvs8i0" path="res://scripts/HookRope/hook_thrower.gd" id="3_c14pe"]
[ext_resource type="Script" uid="uid://chw16tyeg40b7" path="res://scripts/HookRope/hook_recaller.gd" id="4_8y1r0"]
[ext_resource type="Script" uid="uid://0kbqemj5weno" path="res://scripts/HookRope/hook_input.gd" id="5_h4sia"]
[ext_resource type="Script" uid="uid://brfjoryq7ocip" path="res://scripts/HookRope/hook_attachment.gd" id="6_t3xxt"]
[ext_resource type="Script" uid="uid://dl7gwat5li3s8" path="res://scripts/HookRope/rope_line_renderer.gd" id="7_mdl75"]
[ext_resource type="Script" uid="uid://cmjeq6lg4fo16" path="res://scripts/HookRope/rope_reel.gd" id="8_rrmg5"]
[ext_resource type="Script" uid="uid://c4oh4hfdcp1q0" path="res://scripts/HookRope/swing_controller.gd" id="9_ad5qi"]

[sub_resource type="AtlasTexture" id="AtlasTexture_0u4sf"]
atlas = ExtResource("1_hxp0v")
region = Rect2(0, 1, 16, 30)

[sub_resource type="CircleShape2D" id="CircleShape2D_tfdxj"]
radius = 5.0

[node name="Line-Hook" type="RigidBody2D" unique_id=118512847]
collision_layer = 8
collision_mask = 5
script = ExtResource("1_lq7qr")
throw_speed = null
recall_speed = null
max_range = null
min_range = null
reel_speed = null
stick_to_layers = null
attached_friction = 0.9
drag_strength = null
reel_pull_strength = null

[node name="Sprite2D" type="Sprite2D" parent="." unique_id=730607294]
texture = SubResource("AtlasTexture_0u4sf")

[node name="CollisionShape2D" type="CollisionShape2D" parent="." unique_id=229557611]
position = Vector2(0, -6)
shape = SubResource("CircleShape2D_tfdxj")

[node name="Line2D" type="Line2D" parent="." unique_id=925682593]
width = 3.0
default_color = Color(0.6313726, 0.41960785, 0.24705882, 1)

[node name="HookAttachment" type="Node" parent="." unique_id=1320885367]
script = ExtResource("6_t3xxt")
metadata/_custom_type_script = "uid://brfjoryq7ocip"

[node name="HookInput" type="Node" parent="." unique_id=132183862]
script = ExtResource("5_h4sia")
metadata/_custom_type_script = "uid://0kbqemj5weno"

[node name="HookRecaller" type="Node" parent="." unique_id=1940227680]
script = ExtResource("4_8y1r0")
metadata/_custom_type_script = "uid://chw16tyeg40b7"

[node name="HookThrower" type="Node" parent="." unique_id=1547658690]
script = ExtResource("3_c14pe")
metadata/_custom_type_script = "uid://bfg0mhmnvs8i0"

[node name="RopeReel" type="Node" parent="." unique_id=1856089103]
script = ExtResource("8_rrmg5")
metadata/_custom_type_script = "uid://cmjeq6lg4fo16"

[node name="RopeLineRenderer" type="Node" parent="." unique_id=1720715364]
script = ExtResource("7_mdl75")
segment_count = 20
metadata/_custom_type_script = "uid://dl7gwat5li3s8"

[node name="SwingController" type="Node" parent="." unique_id=1277707392]
script = ExtResource("9_ad5qi")
metadata/_custom_type_script = "uid://c4oh4hfdcp1q0"

```

### hook.gd

`scripts/HookRope/hook.gd`

```gdscript
class_name Hook
extends RigidBody2D

enum State { IDLE, FLYING, STUCK, RECALLING }

@export var throw_speed := 800.0
@export var recall_speed := 1000.0
@export var max_range := 500.0
@export var min_range := 5.0
@export var reel_speed := 200.0  # how fast climb_up/climb_down changes rope length
@export_flags_2d_physics var stick_to_layers := 1 + 4  # tick World/Objects etc. in inspector
@export var player: CharacterBody2D  # assign the character node in inspector
@export_range(0.0, 1.0) var attached_friction := 0.1  # friction applied to a stuck RigidBody2D while attached
@export var drag_strength := 900.0     # extra pull toward the player on an attached object, once taut
@export var reel_pull_strength := 600.0  # winch force (mass-normalized) on a stuck RigidBody2D while climb_up/down held

@onready var line: Line2D = $Line2D
@onready var thrower: HookThrower = $HookThrower
@onready var recaller: HookRecaller = $HookRecaller
@onready var attachment: HookAttachment = $HookAttachment
@onready var reel: RopeReel = $RopeReel
@onready var swing_controller: SwingController = $SwingController
@onready var rope_renderer: RopeLineRenderer = $RopeLineRenderer
@onready var input_handler: HookInput = $HookInput

var state := State.IDLE
var stuck_body: RigidBody2D = null
var current_rope_length := 0.0
var attach_offset := Vector2.ZERO  # hook's stick point, relative to stuck_body's origin
var _original_physics_material: PhysicsMaterial = null

func _ready():
	top_level = true
	line.clear_points()
	line.add_point(Vector2.ZERO)  # point 0 - player side
	line.add_point(Vector2.ZERO)  # point 1 - hook side
	hide()
	freeze = true  # hook stays still until thrown

	collision_mask = stick_to_layers
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(attachment._on_body_entered)

func _physics_process(delta):
	match state:
		State.RECALLING:
			recaller.recall_hook()
		State.FLYING:
			thrower.check_range()
		State.STUCK:
			reel.handle_reel(delta)
			swing_controller.constrain_rope(delta)

	rope_renderer.simulate(delta)

# Attaches to a movable object the hook stuck to: records where on the body
# it stuck (offset) and temporarily overrides its friction so it can be
# dragged instead of fighting ground friction the whole way.
func attach_stuck_body(body: RigidBody2D, offset: Vector2) -> void:
	stuck_body = body
	attach_offset = offset
	_original_physics_material = body.physics_material_override
	var mat := PhysicsMaterial.new()
	mat.friction = attached_friction
	body.physics_material_override = mat

# Restores the object's original friction and clears stuck_body. Always use
# this (not "stuck_body = null" directly) so friction is never left changed.
func detach_stuck_body() -> void:
	if stuck_body:
		stuck_body.physics_material_override = _original_physics_material
	stuck_body = null

```

### hook_attachment.gd

`scripts/HookRope/hook_attachment.gd`

```gdscript
class_name HookAttachment
extends Node

@onready var hook: Hook = get_parent()

func _on_body_entered(body: Node) -> void:
	if hook.state == Hook.State.STUCK or hook.state == Hook.State.RECALLING:
		return

	hook.state = Hook.State.STUCK
	hook.set_deferred("freeze", true)
	hook.linear_velocity = Vector2.ZERO

	# rope starts at whatever length it was when it stuck, capped at max_range
	hook.current_rope_length = min(
		hook.global_position.distance_to(hook.player.global_position),
		hook.max_range
	)

	if body is RigidBody2D:
		hook.attach_stuck_body(body, hook.global_position - body.global_position)

```

### hook_input.gd

`scripts/HookRope/hook_input.gd`

```gdscript
class_name HookInput
extends Node

@onready var hook: Hook = get_parent()

func _input(event):
	if event.is_action_pressed("shoot"):
		if hook.state == Hook.State.IDLE and HeldItemManager.is_held == false:
			hook.thrower.throw()
		elif hook.state == Hook.State.FLYING or hook.state == Hook.State.STUCK:
			hook.recaller.recall()

	# jump while swinging: give the jump impulse first (while we still know
	# is_swinging was true), then recall — otherwise recall() clears the flag
	# before the player's own _physics_process ever sees it was true
	if event.is_action_pressed("jump") and hook.player.is_swinging:
		hook.player.velocity.y = hook.player.JUMP_VELOCITY
		hook.recaller.recall()

```

### hook_recaller.gd

`scripts/HookRope/hook_recaller.gd`

```gdscript
class_name HookRecaller
extends Node

@onready var hook: Hook = get_parent()

func recall():
	hook.state = Hook.State.RECALLING
	hook.detach_stuck_body()
	hook.player.is_swinging = false
	hook.freeze = false
	hook.set_deferred("collision_layer", 0)
	hook.set_deferred("collision_mask", 0)

func recall_hook():
	var dir = (hook.player.global_position - hook.global_position).normalized()
	hook.linear_velocity = dir * hook.recall_speed
	hook.rotation = dir.angle()

	if hook.global_position.distance_to(hook.player.global_position) < 20:
		hook.state = Hook.State.IDLE
		hook.detach_stuck_body()
		hook.player.is_swinging = false
		hook.freeze = true
		hook.linear_velocity = Vector2.ZERO
		hook.hide()

```

### hook_thrower.gd

`scripts/HookRope/hook_thrower.gd`

```gdscript
class_name HookThrower
extends Node

@onready var hook: Hook = get_parent()

func throw():
	hook.show()
	hook.state = Hook.State.FLYING
	hook.detach_stuck_body()
	hook.freeze = false
	hook.set_deferred("collision_layer", 8)  # Layer 4 = Hook
	hook.set_deferred("collision_mask", hook.stick_to_layers)
	hook.global_position = hook.player.global_position

	var dir = (hook.get_global_mouse_position() - hook.global_position).normalized()
	hook.linear_velocity = dir * hook.throw_speed
	hook.rotation = dir.angle()  # optional: point sprite toward mouse

func check_range():
	if hook.global_position.distance_to(hook.player.global_position) >= hook.max_range:
		hook.state = Hook.State.RECALLING

```

### rope_reel.gd

`scripts/HookRope/rope_reel.gd`

```gdscript
class_name RopeReel
extends Node

@onready var hook: Hook = get_parent()

func handle_reel(delta):
	if Input.is_action_pressed("climb_up"):
		hook.current_rope_length -= hook.reel_speed * delta
		_winch_stuck_body(1.0)
	if Input.is_action_pressed("climb_down"):
		hook.current_rope_length += hook.reel_speed * delta
		_winch_stuck_body(-1.0)

	hook.current_rope_length = clamp(hook.current_rope_length, hook.min_range, hook.max_range)

# When attached to a movable object (not static geometry like a TileMap),
# climbing also winches the object itself toward (climb_up) or away from
# (climb_down) the player - on top of whatever passive drag SwingController
# already applies once the rope is taut. sign > 0 pulls in, sign < 0 lets out.
func _winch_stuck_body(sign: float) -> void:
	if not hook.stuck_body:
		return
	var dir = (hook.player.global_position - hook.stuck_body.global_position).normalized()
	hook.stuck_body.apply_central_force(dir * sign * hook.stuck_body.mass * hook.reel_pull_strength)

```

### rope_line_renderer.gd

`scripts/HookRope/rope_line_renderer.gd`

```gdscript
class_name RopeLineRenderer
extends Node

@export var segment_count := 12         # number of points in the rope chain
@export var gravity := 900.0            # sag strength, px/sec^2
@export var damping := 0.98             # velocity retention per step (verlet "friction")
@export var stiffness_iterations := 8   # constraint relaxation passes per step (higher = stiffer/less stretchy)

@onready var hook: Hook = get_parent()

var points: PackedVector2Array = []
var old_points: PackedVector2Array = []
var initialized := false

# Called from Hook._physics_process every physics step while state != IDLE.
func simulate(delta: float) -> void:
	if hook.state == Hook.State.IDLE:
		initialized = false
		hook.line.clear_points()
		return

	var start = hook.player.global_position
	var end = hook.global_position

	if not initialized:
		_init_points(start, end)
		initialized = true

	_integrate(delta)
	_apply_constraints(start, end)
	_draw()

func _init_points(start: Vector2, end: Vector2) -> void:
	points.resize(segment_count)
	old_points.resize(segment_count)
	for i in segment_count:
		var t = float(i) / float(segment_count - 1)
		var p = start.lerp(end, t)
		points[i] = p
		old_points[i] = p

func _integrate(delta: float) -> void:
	# skip the two anchor points (index 0 = player side, last = hook side)
	for i in range(1, points.size() - 1):
		var current = points[i]
		var velocity = (current - old_points[i]) * damping
		var next = current + velocity + Vector2.DOWN * gravity * delta * delta
		old_points[i] = current
		points[i] = next

func _apply_constraints(start: Vector2, end: Vector2) -> void:
	# rope "length" the constraints try to hold: current_rope_length while STUCK
	# (so reeling and slack are visible), otherwise just the live hook-player distance
	var rope_length: float
	if hook.state == Hook.State.STUCK:
		rope_length = hook.current_rope_length
	else:
		rope_length = start.distance_to(end)
		if rope_length < 1.0:
			rope_length = 1.0

	var segment_length = rope_length / float(points.size() - 1)

	for _iter in stiffness_iterations:
		points[0] = start
		points[points.size() - 1] = end

		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i + 1]
			var diff = p2 - p1
			var dist = diff.length()
			if dist == 0.0:
				continue
			var error = (dist - segment_length) / dist
			var correction = diff * 0.5 * error

			if i != 0:
				points[i] += correction
			if i + 1 != points.size() - 1:
				points[i + 1] -= correction

	points[0] = start
	points[points.size() - 1] = end

func _draw() -> void:
	hook.line.clear_points()
	for i in points.size():
		hook.line.add_point(hook.to_local(points[i]))

# Total length of the simulated chain right now (can be > current_rope_length
# when the rope is being stretched taut). Not used for the swing force (see
# note in the Verlet Rope + Elastic Swing section above) — kept for potential
# future use (e.g. visually tinting the rope when overstretched).
func get_chain_length() -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

# Direction from the player anchor (points[0]) toward the next chain point —
# i.e. the direction the rope is actually pulling the player, following the
# rope's curve rather than a straight line to the hook.
func get_pull_direction() -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var to_next = points[1] - points[0]
	if to_next.length() < 0.001:
		return Vector2.ZERO
	return to_next.normalized()

```

### swing_controller.gd

`scripts/HookRope/swing_controller.gd`

```gdscript
class_name SwingController
extends Node

@export var spring_stiffness := 40.0   # how hard the rope pulls back once it's stretched taut
@export var spring_damping := 6.0      # how quickly the bounce/oscillation settles
@export var max_stretch := 30.0        # hard safety cap so a weak spring can't stretch forever

@onready var hook: Hook = get_parent()

func constrain_rope(delta):
	# if stuck to a movable object, the hook follows its actual stick point
	# (not the object's origin, which could be a noticeably different spot)
	if hook.stuck_body:
		hook.global_position = hook.stuck_body.global_position + hook.attach_offset

	var to_hook = hook.global_position - hook.player.global_position
	var dist = to_hook.length()
	var stretch = dist - hook.current_rope_length

	if stretch <= 0.0:
		# rope has slack - no pull, player moves/falls freely
		hook.player.is_swinging = false
		return

	var dir = to_hook / dist

	# spring-damper: pulls back proportional to how stretched the rope is,
	# damped against the velocity component running along the rope, so it
	# settles into a swing instead of oscillating forever
	var velocity_along_rope = hook.player.velocity.dot(dir)
	var spring_force = dir * stretch * spring_stiffness
	var damping_force = -dir * velocity_along_rope * spring_damping
	var tension = spring_force + damping_force

	# While RopeReel is actively winching an attached RigidBody2D, it shrinks/
	# lengthens current_rope_length on purpose to drive the tow (see
	# rope_reel.gd) - that "stretch" is the object being reeled, not the
	# player straining against the rope. Feeding it into the player's own
	# velocity was what caused the player to get yanked toward the object for
	# a frame. So: skip applying tension to the player while that's happening,
	# but keep applying the full tension/drag to the object below - the tow
	# itself is unaffected, only the leak into the player is cut.
	var reeling_object = hook.stuck_body != null and (
		Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down")
	)

	if reeling_object:
		hook.player.is_swinging = false
	else:
		hook.player.is_swinging = true
		hook.player.velocity += tension * delta

		# safety net: only kicks in past max_stretch, otherwise it's pure spring
		if stretch > max_stretch:
			hook.player.global_position += dir * (stretch - max_stretch)

	# Newton's third law: the rope pulls the attached object back with the
	# same tension it exerts on the player, just reversed. apply_central_force
	# still divides by the body's own mass, so light objects (e.g. pickupable
	# items) get dragged noticeably but bounded by the spring's own limits —
	# unlike a fixed constant force, which can fling a low-mass body violently.
	if hook.stuck_body:
		hook.stuck_body.apply_central_force(-tension)

		# on top of that, a dedicated drag pull toward the player once taut.
		# multiplying by the body's own mass cancels out apply_central_force's
		# division by mass, so this behaves as a plain acceleration
		# (drag_strength px/sec^2) regardless of how heavy the object is —
		# consistent towing feel for light or heavy attached objects alike.
		hook.stuck_body.apply_central_force(-dir * hook.stuck_body.mass * hook.drag_strength)

```

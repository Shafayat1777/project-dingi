# Trajectory - scene reference

The aim-preview line. While the player holds **right mouse** (`aim`), a red-to-green parabola is drawn from the player toward the mouse, showing where a projectile launched at 800 px/s would fly under gravity. It is a visual aid only: it does not throw anything.

- Scene: `scenes/Character/trajectory.tscn`
- Script: `scripts/character/trajectory.gd`
- Instanced in: `scenes/Character/character.tscn` (node `Trajectory`, child of `Character`) - see [character_scene.md](character_scene.md)
- Related: [line_hook_scene.md](line_hook_scene.md) (the actual hook throw, unrelated to this preview), [debris_scene.md](debris_scene.md) (`grab_object.gd` throws held items at `throw_force = 800`)

---

## Node structure

```
Trajectory (Node2D)           script: trajectory.gd  (rotates toward the mouse every frame)
└── Line2D                    gradient red (1,0,0) -> green (0,0.99,0.40); joint_mode=2, begin_cap_mode=2, end_cap_mode=2 (round)
```

No physics bodies, no collision layers. Position is the Character's origin (the node has no offset in the scene), so the line starts at the player's feet/origin, not the hands or the `Pickable-Position` marker (0, -52).

## Script: `trajectory.gd`

Exports and constants:

| Name | Value | Meaning |
|---|---|---|
| `initial_velocity` | `Vector2(800, 0)` | launch velocity in the node's local frame (the comment `# y = -600` is stale); rotated by the node's rotation to aim |
| `gravity` | `980.0` | px/s^2, matches Godot's default 2D gravity |
| `MAX_POINTS` | 60 | points in the line |
| `TIME_STEP` | 0.05 | seconds between points, so the line covers 3 s of flight |

`_process(delta)` every frame:
1. `look_at(get_global_mouse_position())` - the whole node (and the Line2D child) always rotates to face the mouse, even when the line is hidden.
2. While `aim` is held: `line_2d.show()` and `update_trajectory()`. There is a leftover `shoot` check inside that branch: if `shoot` is just pressed and `HeldItemManager.is_held == false` it does `pass` (the old `throw()` call is commented out).
3. On `aim` released: `line_2d.hide()`.

`update_trajectory()`: clears the Line2D, computes `velocity = initial_velocity.rotated(rotation)`, then for `i` in 0..59 with `t = i * 0.05` adds `to_local(start + velocity*t + 0.5*(0, gravity)*t^2)`. Standard projectile formula in world space, converted to the Line2D's local space so it draws correctly despite the node being rotated.

## How it relates to real throws

- **Held-item throw** (`grab_object.gd throw()`, `shoot` while carrying): sets `linear_velocity = direction_to_mouse * throw_force` with `throw_force = 800`, so the preview's 800 px/s and 980 gravity match the physics of a thrown `RigidBody2D` (subject to the project's default damping). This looks like what the preview was built for, but the script does not check whether anything is held.
- **Hook** (`HookThrower.throw()`): launched toward the mouse at `throw_speed = 800`, but it is its own `RigidBody2D` with its own rules (contact stick, range limit, recall). This preview does not model it and is not tied to it.

## Gotchas / open items

- The line ignores collisions: it draws the full 3 s arc through walls and water.
- It shows on any `aim` press, whether or not an item is held or the hook is available.
- The start point is the character origin, whereas a held item is released from `Pickable-Position` about 52 px higher, so the preview is slightly off from the real launch point.
- `_ready()` has a commented-out line that hid the mouse cursor (`Input.MOUSE_MODE_HIDDEN`).
- Dead code: the `shoot`/`pass`/`#throw()` block. The old `throw()` that spawned `hook_rope_generation.tscn` no longer exists.
- Rotation runs every frame via `look_at`, so a hidden Trajectory still does (cheap) work; moving it under the `aim` check would avoid that.
- `aim` (right mouse) is also read directly as `MOUSE_BUTTON_RIGHT` by `camera_pan.gd` for the look-ahead pan, so holding aim also pans the camera.

---

## Appendix: full source

Copies as of writing; the repo is the source of truth.

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

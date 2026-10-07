# Boat — scene reference

A rideable floating `RigidBody2D`. The player walks up, presses `interact` to board, rows with `left`/`right`, and presses `interact` again to get off. It floats via its own buoyancy script, and objects placed on it add to its mass.

- Scene: `scenes/Boat/boat.tscn` (instanced as `Boat` in `scenes/Map/level_1.tscn`)
- Scripts: `scripts/Boat/*.gd`
- Shader: `shaders/Boat/boat_outline.gdshader`
- Art: `assets/boat/spr_fishing_boat_6_strip9.png`, region `Rect2(0, 16, 64, 32)`

> **Repo note:** `CLAUDE.md` says `buoyancy2.gd` is not attached to the boat. It **is** attached now (node `Buoyancy`, `buoyancy_damping = 10`). Update that paragraph.

---

## Node structure

```
Boat (RigidBody2D)                       script: boat.gd
│                                        collision_layer=128 (boat), collision_mask=261 (world|object|boundary)
├── Sprite2D                             scale 4x, ShaderMaterial (boat_outline.gdshader)
├── CollisionShape2D                     CapsuleShape2D r=13 h=182, rotated -90° (horizontal), at (-7, 43)
├── CargoArea (Node2D)                   script: cargo_weight.gd
│   └── Area2D                           layer=32 (boat_interior), mask=6 (player|object)
│       └── CollisionShape2D             Rect 141 x 20 at (-8.5, 18)
├── BoatHighlight (Node2D)               script: boat_highlight.gd
│   ├── Area2D                           mask=2 (player)
│   │   └── CollisionShape2D             Rect 237 x 78 at (-8.5, 16)  - "near the boat" zone
│   └── Label                            'Press "E" to Enter'
├── BoatMount (Node2D)                   script: boat_mount.gd
│   └── ExitMarker (Marker2D)            at (0, -45) - where the player lands on dismount
├── BoatDriver (Node2D)                  script: boat_driver.gd
└── Buoyancy (Node2D)                    script: buoyancy2.gd, buoyancy_damping = 10
```

Signal connections (in scene):
- `CargoArea/Area2D.body_entered/exited` → `CargoArea._on_cargo_area_body_entered/exited`
- `BoatHighlight/Area2D.body_entered/exited` → `BoatHighlight._on_area_2d_body_entered/exited`

Every component grabs the boat via `get_parent()` and sibling nodes by name (`BoatMount`, `BoatDriver`, `Sprite2D`, `CollisionShape2D`) — **renaming those nodes breaks the scripts**.

### Physics layers

- Boat body: layer 8 (**boat**), collides with world, object, boundary (not the player — the player rides *inside* it as a child).
- `CargoArea/Area2D`: layer 6 (**boat_interior**), detects player (2) + object (3). Only `RigidBody2D`s count as cargo, so the player doesn't add mass.
- Water detection: `water_spring.gd` Areas detect the boat body; boat opts out of their drag (see `receives_water_drag` below).
- The hook can stick to the boat (layer 8 is in the Character's `stick_to_layers`).

---

## Components

**`boat.gd` (root)**
- `is_on_water` (setter re-applies settings). On water: `linear_damp = 0.5`, friction 0. Off water: `linear_damp = 0.2`, friction 1. Creates a `PhysicsMaterial` if none.
- State: `is_occupied`, `driver`.
- `hook_pull_multiplier` (`@export_range(0, 1)`, default 0.3): scales how hard the grappling hook pulls the boat while the player drives it. Read by `swing_controller.gd`; lower = heavier boat / more water resistance.
- `receives_water_drag = false`: a flag read by `water_spring.gd` so the spring doesn't apply its per-frame velocity drag to the boat (it fought rowing and buoyancy).

**`buoyancy2.gd`** — samples water at the two horizontal ends of the collision shape:
- Finds `water_body` via `get_first_node_in_group("water")` (the water body must be in group `water`).
- Sizes itself from the `CollisionShape2D` (rect / circle / capsule) and takes the shape's rotation into account (`object_width/height`).
- Each physics frame, for each side (±half width): `submersion_ratio` from the depth relative to `get_water_height_at(x)` (linear interpolation between bracketing springs, using **global** spring positions), force = `water_density * gravity * half_width_m * height_m * ratio`, clamped to `max_buoyancy_force`, applied at that side's point → produces both lift and a righting torque.
- If submerged: vertical velocity damping and angular damping (`buoyancy_damping * mass`).
- Sets `body.is_on_water = is_submerged` (consumed by `boat.gd`).
- Exports: `water_density=12`, `buoyancy_damping=0.5` (scene: 10), `pixels_per_meter=100`, `max_buoyancy_force=60000`.
- Separate from `scripts/Water/buoyant_object.gd` (used for generic objects). Don't mix the two when tuning.

**`cargo_weight.gd`** — `base_mass = 5`. Sets `boat.mass = base_mass` on ready; tracks `RigidBody2D`s in the cargo area in a dictionary `aboard {body: mass}`; on enter/exit recomputes `boat.mass = base_mass + sum`. Contains a leftover `print(boat.mass)` in `_recalculate()`.

**`boat_highlight.gd`** — 
- Tracks `nearby_player` from the Area2D signals; when the player is near and the boat is empty: shows the label and enables the outline (`sprite.material.set_shader_parameter("outline_enabled", true)`).
- `_unhandled_input` on `interact`: if occupied → `boat_mount.dismount()` (re-shows the prompt if the player is still in range); else if a player is nearby → `boat_mount.mount(nearby_player)` and hides prompt/outline.

**`boat_mount.gd`**
- `mount(player)`: ignores if already occupied; remembers `original_parent`; `player.set_physics_process(false)`; disables the player's `CollisionShape2D` (deferred); reparents the player under the boat at the boat's global position; `Camera2D.reset_smoothing()`; sets `is_occupied`, `driver`, and `boat_driver.set_active(true)`.
- `dismount()`: reparents back to `original_parent` at `ExitMarker`'s global position, resets camera smoothing, re-enables collider and physics, clears occupancy, `set_active(false)`.

**`boat_driver.gd`** — active only while mounted. `left`/`right` held → `apply_central_force(∓row_force, 0)` (`row_force=600`) and sets `sprite.flip_h` (**right = flipped, left = not flipped**, i.e. the art faces left by default). Velocity capped to `max_speed=250` via `limit_length`.

**`boat_outline.gdshader`** — `canvas_item`; uniforms `outline_enabled`, `outline_color` (white), `darkness_threshold` (0.25). Instead of drawing a border outside the sprite, it recolors the sprite's own darkest pixels (max(r,g,b) < threshold) to the outline color when enabled — it relies on the boat art having dark outline pixels.

---

## Flow summary

```
walk into BoatHighlight/Area2D -> label + outline on
press interact -> BoatMount.mount(): player becomes child of boat, frozen, camera smoothing reset
hold left/right -> BoatDriver forces (boat body), sprite flips
Buoyancy2 (every frame) -> lift/torque/damping, sets is_on_water -> boat.gd damp/friction
objects dropped in CargoArea -> CargoWeight adds mass
press interact -> BoatMount.dismount(): player placed at ExitMarker
```

Respawn: `water_kill_zone.gd` moves the boat back to the `Boat Spawn` marker together with the player (it uses `@export var boat` and `@export var boatspawn`).

## Open items / gotchas

- `cargo_weight.gd` still prints the mass on every change.
- Sprite art faces left; flip logic is inverted compared to the usual `flip_h = direction < 0`.
- While mounted, the player's `Line-Hook` input is not disabled (only `_physics_process` is). `SwingController` detects the driver case (player's parent is a `RigidBody2D` whose `driver` is the player) and applies the rope tension to the boat as `tension * mass * hook_pull_multiplier` instead of to the player, so reeling toward a tilemap anchor moves the boat rather than yanking the player off it. Hooking the boat itself from the boat is not handled.
- Higher mass from cargo also reduces the acceleration from the fixed 600 row force; buoyancy force is not mass-scaled other than by submersion, so heavy cargo sinks the boat lower (intended).
- Multiple water bodies: `buoyancy2.gd` picks the first node in group `water` only.

---

## Appendix: full source

Copies as of writing; the repo is the source of truth.

### boat.tscn

`scenes/Boat/boat.tscn`

```ini
[gd_scene format=3 uid="uid://ddp25awxgllci"]

[ext_resource type="Script" uid="uid://cumgthy85r8bx" path="res://scripts/Boat/boat.gd" id="1_0r3a7"]
[ext_resource type="Shader" uid="uid://wf16v5pqeghj" path="res://shaders/Boat/boat_outline.gdshader" id="1_mxnvt"]
[ext_resource type="Texture2D" uid="uid://dvtwqq8fxhlj5" path="res://assets/boat/spr_fishing_boat_6_strip9.png" id="1_u1y6a"]
[ext_resource type="Script" uid="uid://dk41nxpk5ow5n" path="res://scripts/Boat/cargo_weight.gd" id="2_kr7uc"]
[ext_resource type="Script" uid="uid://bpgegsqa7wbhi" path="res://scripts/Boat/boat_highlight.gd" id="3_v47qu"]
[ext_resource type="Script" uid="uid://c8l4wkpxgosi8" path="res://scripts/Boat/boat_mount.gd" id="6_uv258"]
[ext_resource type="Script" uid="uid://c28u3tjdag2oh" path="res://scripts/Boat/boat_driver.gd" id="7_fg55p"]
[ext_resource type="Script" uid="uid://c615ojffmd7go" path="res://scripts/Boat/buoyancy2.gd" id="8_bnnrb"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_v47qu"]
shader = ExtResource("1_mxnvt")
shader_parameter/outline_enabled = false
shader_parameter/outline_color = Color(1, 1, 1, 1)
shader_parameter/darkness_threshold = 0.25

[sub_resource type="AtlasTexture" id="AtlasTexture_08r2w"]
atlas = ExtResource("1_u1y6a")
region = Rect2(0, 16, 64, 32)

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_tkc8d"]
radius = 13.0
height = 182.0

[sub_resource type="RectangleShape2D" id="RectangleShape2D_08r2w"]
size = Vector2(141, 20)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_6f4wy"]
size = Vector2(237, 78)

[node name="Boat" type="RigidBody2D" unique_id=1550122346]
collision_layer = 128
collision_mask = 261
script = ExtResource("1_0r3a7")

[node name="Sprite2D" type="Sprite2D" parent="." unique_id=2113326389]
material = SubResource("ShaderMaterial_v47qu")
scale = Vector2(4, 4)
texture = SubResource("AtlasTexture_08r2w")

[node name="CollisionShape2D" type="CollisionShape2D" parent="." unique_id=473146049]
position = Vector2(-7, 43)
rotation = -1.5707964
shape = SubResource("CapsuleShape2D_tkc8d")

[node name="CargoArea" type="Node2D" parent="." unique_id=1360502144]
script = ExtResource("2_kr7uc")

[node name="Area2D" type="Area2D" parent="CargoArea" unique_id=38036388]
collision_layer = 32
collision_mask = 6

[node name="CollisionShape2D" type="CollisionShape2D" parent="CargoArea/Area2D" unique_id=646331058]
position = Vector2(-8.5, 18)
shape = SubResource("RectangleShape2D_08r2w")
debug_color = Color(0.94191134, 0.1639674, 0.45427108, 0.41960785)

[node name="BoatHighlight" type="Node2D" parent="." unique_id=46514307]
script = ExtResource("3_v47qu")

[node name="Area2D" type="Area2D" parent="BoatHighlight" unique_id=310866210]
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="BoatHighlight/Area2D" unique_id=888278076]
position = Vector2(-8.5, 16)
shape = SubResource("RectangleShape2D_6f4wy")
debug_color = Color(0.233735, 0.63270146, 0.23578152, 0.41960785)

[node name="Label" type="Label" parent="BoatHighlight" unique_id=1413812194]
offset_left = -69.0
offset_top = -56.0
offset_right = 66.0
offset_bottom = -33.0
text = "Press \"E\" to Enter"

[node name="BoatMount" type="Node2D" parent="." unique_id=1065890955]
script = ExtResource("6_uv258")

[node name="ExitMarker" type="Marker2D" parent="BoatMount" unique_id=327407641]
position = Vector2(0, -45)

[node name="BoatDriver" type="Node2D" parent="." unique_id=1294157406]
script = ExtResource("7_fg55p")

[node name="Buoyancy" type="Node2D" parent="." unique_id=1163057670]
script = ExtResource("8_bnnrb")
buoyancy_damping = 10.0

[connection signal="body_entered" from="CargoArea/Area2D" to="CargoArea" method="_on_cargo_area_body_entered"]
[connection signal="body_exited" from="CargoArea/Area2D" to="CargoArea" method="_on_cargo_area_body_exited"]
[connection signal="body_entered" from="BoatHighlight/Area2D" to="BoatHighlight" method="_on_area_2d_body_entered"]
[connection signal="body_exited" from="BoatHighlight/Area2D" to="BoatHighlight" method="_on_area_2d_body_exited"]

```

### boat.gd

`scripts/Boat/boat.gd`

```gdscript
extends RigidBody2D

@export var is_on_water: bool = true:
	set(value):
		is_on_water = value
		_apply_surface_settings()

# scales the hook's pull on the boat while the player drives it (1.0 = full,
# lower = heavier boat / more water resistance); read by swing_controller.gd
@export_range(0.0, 1.0, 0.01) var hook_pull_multiplier: float = 0.3

var is_occupied: bool = false
var driver: CharacterBody2D = null

# opted out of water_spring.gd's per-frame velocity drag — the boat already
# gets its own surface friction/linear_damp via _apply_surface_settings(),
# and the extra drag fought rowing (boat_driver.gd) and buoyancy2.gd's forces
var receives_water_drag: bool = false

func _ready() -> void:
	_apply_surface_settings()

func _apply_surface_settings() -> void:
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()

	if is_on_water:
		linear_damp = 0.5
		physics_material_override.friction = 0.0
	else:
		linear_damp = 0.2
		physics_material_override.friction = 1.0

```

### boat_driver.gd

`scripts/Boat/boat_driver.gd`

```gdscript
extends Node

@onready var boat: RigidBody2D = get_parent()

@export var row_force: float = 600.0      # continuous push while held down
@export var max_speed: float = 250.0

var active: bool = false
var sprite: Sprite2D

func _ready() -> void:
	sprite = get_parent().get_node('Sprite2D')

func set_active(state: bool) -> void:
	active = state

func _physics_process(_delta: float) -> void:
	if not active:
		return

	if Input.is_action_pressed("left"):
		boat.apply_central_force(Vector2(-row_force, 0))
		sprite.flip_h = false
	elif Input.is_action_pressed("right"):
		boat.apply_central_force(Vector2(row_force, 0))
		sprite.flip_h = true
	if boat.linear_velocity.length() > max_speed:
		boat.linear_velocity = boat.linear_velocity.limit_length(max_speed)

```

### boat_highlight.gd

`scripts/Boat/boat_highlight.gd`

```gdscript
extends Node2D

@onready var boat: RigidBody2D = get_parent()
@onready var boat_mount: Node = get_parent().get_node("BoatMount")
@onready var sprite: Sprite2D = get_parent().get_node("Sprite2D")
@onready var label: Label = $Label

var nearby_player: CharacterBody2D = null

func _ready() -> void:
	label.hide()

func set_highlighted(state: bool) -> void:
	sprite.material.set_shader_parameter("outline_enabled", state)

func show_prompt() -> void:
	label.show()

func hide_prompt() -> void:
	label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if boat.is_occupied:
		boat_mount.dismount()
		if nearby_player != null:
			show_prompt()  # player likely still standing right next to it after dismount
	elif nearby_player != null:
		boat_mount.mount(nearby_player)
		hide_prompt()      # already aboard, no need to keep prompting "enter"
		set_highlighted(false)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	
	nearby_player = body
	
	if not boat.is_occupied:
		show_prompt()
		set_highlighted(true)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return

	if body == nearby_player:
		nearby_player = null

	hide_prompt()
	set_highlighted(false)

```

### boat_mount.gd

`scripts/Boat/boat_mount.gd`

```gdscript
# BoatMount.gd — attached to the BoatMount (Node) component
extends Node2D

@onready var boat: RigidBody2D = get_parent()
@onready var exit_marker: Marker2D = $ExitMarker
@onready var boat_driver: Node = get_parent().get_node("BoatDriver")

var original_parent: Node = null

func mount(player: CharacterBody2D) -> void:
	if boat.is_occupied:
		return  # already have someone aboard, ignore

	original_parent = player.get_parent()
	# Freeze the player's own movement/animation logic
	player.set_physics_process(false)

	# Disable the player's own collider while riding, so it doesn't
	# independently collide with the world/cargo area while mounted
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	player_shape.set_deferred("disabled", true)

	# Reparent onto the boat, then restore world position
	# (reparenting resets local position relative to the new parent)
	original_parent.remove_child(player)
	boat.add_child(player)
	player.global_position = boat.global_position
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").reset_smoothing()

	boat.is_occupied = true
	boat.driver = player
	boat_driver.set_active(true)

func dismount() -> void:
	var player: CharacterBody2D = boat.driver
	if player == null:
		return

	boat.remove_child(player)
	original_parent.add_child(player)
	player.global_position = exit_marker.global_position
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").reset_smoothing()

	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	player_shape.set_deferred("disabled", false)

	player.set_physics_process(true)

	boat.is_occupied = false
	boat.driver = null
	boat_driver.set_active(false)

```

### buoyancy2.gd

`scripts/Boat/buoyancy2.gd`

```gdscript
extends Node2D

@onready var water_body = get_tree().get_first_node_in_group("water")
@onready var body: RigidBody2D = get_parent()
@onready var collision_shape: CollisionShape2D = body.get_node("CollisionShape2D")

var object_width: float
var object_height: float
var is_submerged := false

@export var water_density = 12.0
@export var buoyancy_damping = 0.5
@export var pixels_per_meter = 100.0
@export var max_buoyancy_force = 60000.0

func _ready() -> void:
	var shape = collision_shape.shape
	var w: float
	var h: float
	if shape is RectangleShape2D:
		w = shape.size.x
		h = shape.size.y
	elif shape is CircleShape2D:
		w = shape.radius * 2
		h = shape.radius * 2
	elif shape is CapsuleShape2D:
		w = shape.radius * 2
		h = shape.height
	else:
		push_warning("Unsupported collision shape for buoyancy sizing, using default 32x32")
		w = 32.0
		h = 32.0

	var r = collision_shape.rotation
	object_width = abs(w * cos(r)) + abs(h * sin(r))
	object_height = abs(w * sin(r)) + abs(h * cos(r))

func _physics_process(delta: float) -> void:
	if not water_body:
		
		
		return

	var gravity_mag = body.get_gravity().length()
	var half_width = object_width / 2.0
	is_submerged = false

	for side in [-1.0, 1.0]:
		var point = body.to_global(collision_shape.position + Vector2(side * half_width, 0))
		var water_height = get_water_height_at(point.x)
		var submersion_depth = point.y - water_height

		if submersion_depth > -object_height / 2.0:
			is_submerged = true
			var submersion_ratio = clamp((submersion_depth + object_height / 2.0) / object_height, 0.0, 1.0)

			var half_width_m = half_width / pixels_per_meter
			var height_m = object_height / pixels_per_meter
			var buoyancy_force = water_density * gravity_mag * half_width_m * height_m * submersion_ratio
			buoyancy_force = clamp(buoyancy_force, 0.0, max_buoyancy_force)

			body.apply_force(Vector2(0, -buoyancy_force), point - body.global_position)

	if is_submerged:
		body.apply_central_force(Vector2(0, -body.linear_velocity.y * buoyancy_damping * body.mass))
		body.apply_torque(-body.angular_velocity * buoyancy_damping * body.mass)

	if "is_on_water" in body:
		body.is_on_water = is_submerged

func get_water_height_at(x_position: float) -> float:
	var springs = water_body.springs
	if springs.size() == 0:
		return body.global_position.y

	for i in range(springs.size() - 1):
		var spring_a = springs[i]
		var spring_b = springs[i + 1]
		if x_position >= spring_a.global_position.x and x_position <= spring_b.global_position.x:
			var t = (x_position - spring_a.global_position.x) / (spring_b.global_position.x - spring_a.global_position.x)
			return lerp(spring_a.global_position.y, spring_b.global_position.y, t)

	if x_position < springs[0].global_position.x:
		return springs[0].global_position.y
	return springs[springs.size() - 1].global_position.y

```

### cargo_weight.gd

`scripts/Boat/cargo_weight.gd`

```gdscript
# CargoWeight.gd
extends Node

@export var base_mass: float = 5.0
var cargo_weight: float = 0.0
var aboard: Dictionary = {}

@onready var boat: RigidBody2D = get_parent()

func _ready() -> void:
	boat.mass = base_mass

func _on_cargo_area_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D):
		return
	if aboard.has(body):
		return

	aboard[body] = body.mass
	_recalculate()

func _on_cargo_area_body_exited(body: Node2D) -> void:
	if not aboard.has(body):
		return
	aboard.erase(body)
	_recalculate()

func _recalculate() -> void:
	cargo_weight = 0.0
	for w in aboard.values():
		cargo_weight += w
	boat.mass = base_mass + cargo_weight
	print(boat.mass)

```

### boat_outline.gdshader

`shaders/Boat/boat_outline.gdshader`

```glsl
shader_type canvas_item;

uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float darkness_threshold : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = tex;

	if (outline_enabled && tex.a > 0.0) {
		float brightness = max(tex.r, max(tex.g, tex.b));
		if (brightness < darkness_threshold) {
			COLOR = vec4(outline_color.rgb, tex.a);
		}
	}
}
```

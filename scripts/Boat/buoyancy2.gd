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
		var point = collision_shape.global_transform * Vector2(side * half_width, 0)
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

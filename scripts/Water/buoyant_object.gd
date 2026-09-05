extends RigidBody2D

@export var water_body_path: NodePath
@onready var water_body = get_node(water_body_path)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var object_width: float
var object_height: float
var is_submerged := false


@export var water_density = 8.0
@export var buoyancy_damping = 0.3
@export var pixels_per_meter = 100.0
@export var max_buoyancy_force = 20000.0


func _ready():
	var shape = collision_shape.shape
	if shape is RectangleShape2D:
		object_width = shape.size.x
		object_height = shape.size.y
	elif shape is CircleShape2D:
		object_width = shape.radius * 2
		object_height = shape.radius * 2
	elif shape is CapsuleShape2D:
		object_width = shape.radius * 2
		object_height = shape.height
	else:
		push_warning("Unsupported collision shape for buoyancy sizing, using default 32x32")
		object_width = 32.0
		object_height = 32.0


func _physics_process(delta):
	if not water_body:
		return

	var gravity_mag = get_gravity().length()
	var half_width = object_width / 2.0
	is_submerged = false

	# sample the water at both edges (not just the center) so a tilted object
	# gets more force on its more-submerged side instead of one lump center force
	for side in [-1.0, 1.0]:
		var point = to_global(Vector2(side * half_width, 0))
		var water_height = get_water_height_at(point.x)
		var submersion_depth = point.y - water_height

		if submersion_depth > -object_height / 2.0:
			is_submerged = true
			var submersion_ratio = clamp((submersion_depth + object_height / 2.0) / object_height, 0.0, 1.0)

			# force uses displaced area (not mass) so mass isn't canceled out by F/mass;
			# dimensions are in meters so the force stays in gravity's scale, not pixel^2
			var half_width_m = half_width / pixels_per_meter
			var height_m = object_height / pixels_per_meter
			var buoyancy_force = water_density * gravity_mag * half_width_m * height_m * submersion_ratio
			buoyancy_force = clamp(buoyancy_force, 0.0, max_buoyancy_force)

			apply_force(Vector2(0, -buoyancy_force), point - global_position)

	if is_submerged:
		apply_central_force(Vector2(0, -linear_velocity.y * buoyancy_damping * mass))
		apply_torque(-angular_velocity * buoyancy_damping * mass)

func get_water_height_at(x_position: float) -> float:
	var springs = water_body.springs
	if springs.size() == 0:
		return global_position.y
	
	for i in range(springs.size() - 1):
		var spring_a = springs[i]
		var spring_b = springs[i + 1]
		if x_position >= spring_a.global_position.x and x_position <= spring_b.global_position.x:
			var t = (x_position - spring_a.global_position.x) / (spring_b.global_position.x - spring_a.global_position.x)
			return lerp(spring_a.global_position.y, spring_b.global_position.y, t)
	
	if x_position < springs[0].global_position.x:
		return springs[0].global_position.y
	return springs[springs.size() - 1].global_position.y

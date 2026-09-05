extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $GrabArea

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
		if direction != 0:
			pickup_area.position.x = abs(pickup_area.position.x) * sign(direction)
	elif direction != 0:
		animated_sprite_2d.flip_h = direction < 0
		animated_sprite_2d.play("running")
		pickup_area.position.x = abs(pickup_area.position.x) * sign(direction)
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

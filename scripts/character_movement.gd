extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var push_force = 60.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Handle animations based on state
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
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * push_force)

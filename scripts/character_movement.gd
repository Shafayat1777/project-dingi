extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $GrabArea

const SPEED = 300.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0
const JUMP_VELOCITY = -400.0
var push_force = 60.0
var nearby_item: RigidBody2D = null
var is_grabbed: bool = false

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
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# Handle animations based on state
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
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * push_force)
		
		debris_pick_up()

func debris_pick_up() -> void:
	if Input.is_action_just_pressed("pickup"):
		if nearby_item is RigidBody2D:
			is_grabbed = true
	
	if nearby_item is RigidBody2D and is_grabbed:
		nearby_item.position = Vector2(position.x, position.y - 50)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		HeldItemManager.pick_up(body)
		nearby_item = body


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		HeldItemManager.drop(body)

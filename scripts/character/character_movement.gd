extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $GrabArea
@onready var pickable_position: Marker2D = $"Pickable-Position"

const SPEED = 300.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0
const JUMP_VELOCITY = -400.0
var push_force = 60.0
var facing_direction: float = 1.0

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
	
	if direction != 0:
		facing_direction = sign(direction)
		
	debris_pick_up()
	debris_drop()
	debris_throw()

	
func debris_pick_up() -> void:
	if Input.is_action_just_pressed("pickup") and HeldItemManager.is_held == false:
		if HeldItemManager.held_item is RigidBody2D and HeldItemManager.held_item.input_pickable:
			HeldItemManager.hold(HeldItemManager.held_item, pickable_position)
	
	if HeldItemManager.held_item is RigidBody2D and HeldItemManager.is_held:
		HeldItemManager.held_item.global_position  = Vector2(global_position.x, global_position.y - 50)

func debris_drop() -> void:
	if Input.is_action_just_pressed("drop") and HeldItemManager.is_held:
		HeldItemManager.drop(HeldItemManager.held_item, facing_direction)

func debris_throw() -> void:
	if Input.is_action_just_pressed("shoot") and HeldItemManager.is_held:
		HeldItemManager.throw(HeldItemManager.held_item, facing_direction)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body.input_pickable:
		HeldItemManager.show_label(body)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and HeldItemManager.is_held == false:
		HeldItemManager.hide_label(body)

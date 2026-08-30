extends Area2D

var facing_direction: float = 1.0
@export var pickable_position: Marker2D

func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("left", "right")
	
	if direction != 0:
		facing_direction = sign(direction)
	
	debris_pick_up()
	debris_drop()
	debris_throw()

func debris_pick_up() -> void:
	#if Input.is_action_just_pressed("pickup") and HeldItemManager.is_held == false:
		#if HeldItemManager.held_item is RigidBody2D and HeldItemManager.held_item.input_pickable:
			#HeldItemManager.hold(HeldItemManager.held_item, pickable_position)
	#
	#if HeldItemManager.held_item is RigidBody2D and HeldItemManager.is_held:
		#HeldItemManager.held_item.global_position  = Vector2(global_position.x, global_position.y - 50)

	if Input.is_action_just_pressed("pickup"):
		HeldItemManager.hold(pickable_position)

func debris_drop() -> void:
	if Input.is_action_just_pressed("drop") and HeldItemManager.is_held:
		HeldItemManager.drop(facing_direction)

func debris_throw() -> void:
	if Input.is_action_just_pressed("shoot") and HeldItemManager.is_held:
		HeldItemManager.throw(facing_direction)

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		HeldItemManager.show_label(body)


func _on_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		HeldItemManager.hide_label(body)

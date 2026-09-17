extends Node2D
class_name GrabObject

@export var throw_force: float = 800

var marker: Marker2D = null
var facing_direction: float = 1.0
var object: RigidBody2D
var held_item_layer: int = 0
var held_item_mask: int = 0

func _ready() -> void:
	object = get_parent()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("left", "right")

	if direction != 0:
		facing_direction = sign(direction)

	pick_up()
	drop()
	throw()

func _on_proximity_highlight_body_entered(body: Node2D) -> void:
	marker = body.get_node_or_null("Pickable-Position") as Marker2D

func _on_proximity_highlight_body_exited(body: Node2D) -> void:
	marker = null

func pick_up() -> void:
	if Input.is_action_just_pressed("pickup") and marker and not HeldItemManager.is_held:
		var target_marker := marker  # cache it before remove_child() can null the member var

		object.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		object.freeze = true
		var prev_parent = object.get_parent()
		prev_parent.remove_child(object)
		target_marker.add_child(object)

		object.position = Vector2.ZERO
		object.rotation = 0.0

		held_item_layer = object.collision_layer
		held_item_mask = object.collision_mask
		object.collision_layer = 0
		object.collision_mask = 0

		HeldItemManager.held_item = object
		HeldItemManager.is_held = true

func drop() -> void:
	if Input.is_action_just_pressed("drop") and HeldItemManager.held_item == object:
		var world = object.get_tree().current_scene
		var drop_pos = object.global_position

		object.get_parent().remove_child(object)
		world.add_child(object)
		object.global_position = drop_pos

		object.collision_layer = held_item_layer
		object.collision_mask = held_item_mask

		object.freeze = false
		object.sleeping = false
		object.linear_velocity = Vector2(200.0 * facing_direction, -150.0)

		HeldItemManager.held_item = null
		HeldItemManager.is_held = false

func throw() -> void:
	if Input.is_action_just_pressed("shoot") and HeldItemManager.held_item == object:
		var world = object.get_tree().current_scene
		var drop_pos = object.global_position

		object.get_parent().remove_child(object)
		world.add_child(object)
		object.global_position = drop_pos

		object.freeze = false
		object.sleeping = false

		object.collision_layer = held_item_layer
		object.collision_mask = held_item_mask

		var mouse_pos = object.get_global_mouse_position()
		var throw_direction = (mouse_pos - drop_pos).normalized()
		object.linear_velocity = throw_direction * throw_force

		HeldItemManager.held_item = null
		HeldItemManager.is_held = false

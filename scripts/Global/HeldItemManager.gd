# HeldItemManager.gd (autoload singleton)
extends Node

signal item_picked_up(item)
signal item_thrown(item)

var is_held: bool = false
var held_item: RigidBody2D = null
var near_item: RigidBody2D = null
var throw_force: float = 800

var held_item_layer: int = 0
var held_item_mask: int = 0

func show_label(item: RigidBody2D) -> void:
	held_item = item
	near_item = item
	item_picked_up.emit(item) 
	
func hide_label(item: RigidBody2D) -> void:
	held_item = null
	near_item = null
	item_thrown.emit(item)
	
func hold(item: RigidBody2D, pickable_position:Marker2D) -> void:
	held_item = item
	is_held = true
	
	item.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC   # HOW it behaves while frozen
	item.freeze = true                                      # actually freeze it
	
	var prev_parent = item.get_parent()
	prev_parent.remove_child(item)
	pickable_position.add_child(item)
	
	item.position = Vector2.ZERO
	item.rotation = 0.0
	
	held_item_layer = item.collision_layer
	held_item_mask = item.collision_mask
	item.collision_layer = 0
	item.collision_mask = 0
	
	item_picked_up.emit(item)

func drop(item: RigidBody2D, facing_direction:float) -> void:
	held_item = null
	is_held = false
	
	var world = item.get_tree().current_scene
	var drop_pos = item.global_position
	
	item.get_parent().remove_child(item)
	world.add_child(item)
	item.global_position = drop_pos
	
	item.collision_layer = held_item_layer
	item.collision_mask = held_item_mask
	
	item.freeze = false         # resume physics simulation
	item.sleeping = false       # force it awake in case it fell asleep
	item.linear_velocity = Vector2(200.0 * facing_direction, -150.0)   # optional: clear any leftover velocity
	item_thrown.emit(item)

func throw(item: RigidBody2D, facing_direction:float) -> void:
	held_item = null
	is_held = false

	var world = item.get_tree().current_scene
	var drop_pos = item.global_position
	
	item.get_parent().remove_child(item)
	world.add_child(item)
	item.global_position = drop_pos
	
	item.freeze = false         # resume physics simulation
	item.sleeping = false       # force it awake in case it fell asleep
	
	item.collision_layer = held_item_layer
	item.collision_mask = held_item_mask
	
	var mouse_pos = item.get_global_mouse_position()
	var throw_direction = (mouse_pos - drop_pos).normalized()
	item.linear_velocity = throw_direction * throw_force
	
	item_thrown.emit(item)

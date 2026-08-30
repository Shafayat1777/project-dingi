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
	if item.input_pickable and held_item == null:
		near_item = item
		item_picked_up.emit(item) 
	
func hide_label(item: RigidBody2D) -> void:
	near_item = null
	item_thrown.emit(item)
	
func hold(pickable_position:Marker2D) -> void:
	if near_item:
		held_item = near_item
		is_held = true
	
		held_item.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC   
		held_item.freeze = true                                 
		var prev_parent = held_item.get_parent()
		prev_parent.remove_child(held_item)
		pickable_position.add_child(held_item)
		
		held_item.position = Vector2.ZERO
		held_item.rotation = 0.0
		
		held_item_layer = held_item.collision_layer
		held_item_mask = held_item.collision_mask
		held_item.collision_layer = 0
		held_item.collision_mask = 0
		
		item_picked_up.emit(held_item)

func drop(facing_direction:float) -> void:
	var world = held_item.get_tree().current_scene
	var drop_pos = held_item.global_position
	
	held_item.get_parent().remove_child(held_item)
	world.add_child(held_item)
	held_item.global_position = drop_pos
	
	held_item.collision_layer = held_item_layer
	held_item.collision_mask = held_item_mask
	
	held_item.freeze = false         # resume physics simulation
	held_item.sleeping = false       # force it awake in case it fell asleep
	held_item.linear_velocity = Vector2(200.0 * facing_direction, -150.0)   # optional: clear any leftover velocity
	item_thrown.emit(held_item)
	
	held_item = null
	is_held = false

func throw(facing_direction:float) -> void:
	var world = held_item.get_tree().current_scene
	var drop_pos = held_item.global_position
	
	held_item.get_parent().remove_child(held_item)
	world.add_child(held_item)
	held_item.global_position = drop_pos
	
	held_item.freeze = false         # resume physics simulation
	held_item.sleeping = false       # force it awake in case it fell asleep
	
	held_item.collision_layer = held_item_layer
	held_item.collision_mask = held_item_mask
	
	var mouse_pos = held_item.get_global_mouse_position()
	var throw_direction = (mouse_pos - drop_pos).normalized()
	held_item.linear_velocity = throw_direction * throw_force
	
	item_thrown.emit(held_item)
	held_item = null
	is_held = false

# HeldItemManager.gd (autoload singleton)
extends Node

signal item_picked_up(item)
signal item_thrown(item)

var held_item: RigidBody2D = null

func show_label(item: RigidBody2D) -> void:
	held_item = item
	item_picked_up.emit(item) 
	
func hide_label(item: RigidBody2D) -> void:
	held_item = null
	item_thrown.emit(item)
	
func hold(item: RigidBody2D, pickable_position:Marker2D) -> void:
	held_item = item
	item.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC   # HOW it behaves while frozen
	item.freeze = true                                      # actually freeze it
	
	var prev_parent = item.get_parent()
	prev_parent.remove_child(item)
	pickable_position.add_child(item)
	item.position = Vector2.ZERO
	
	item_picked_up.emit(item)

func drop(item: RigidBody2D, facing_direction:float) -> void:
	held_item = null
	
	var world = item.get_tree().current_scene
	var drop_pos = item.global_position
	
	item.get_parent().remove_child(item)
	world.add_child(item)
	item.global_position = drop_pos
	
	item.freeze = false         # resume physics simulation
	item.sleeping = false       # force it awake in case it fell asleep
	item.linear_velocity = Vector2(200.0 * facing_direction, -150.0)   # optional: clear any leftover velocity
	item_thrown.emit(item)

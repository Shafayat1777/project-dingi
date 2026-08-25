extends Node
# HeldItemManager.gd (autoload singleton)
signal item_picked_up(item)
signal item_thrown(item)

var held_item: RigidBody2D = null

func pick_up(item: RigidBody2D) -> void:
	held_item = item
	item_picked_up.emit(item)   # <-- fires the signal, sends "item" along with it

func drop(item: RigidBody2D) -> void:
	held_item = null
	item_thrown.emit(item)

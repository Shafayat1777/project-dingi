# HeldItemUI.gd (attached to a Label node in your UI scene)
extends Label

func _ready():
	# "Whenever HeldItemManager emits item_picked_up, call my function"
	HeldItemManager.item_picked_up.connect(_on_item_picked_up)
	HeldItemManager.item_thrown.connect(_on_item_thrown)

func _on_item_picked_up(item):
	if item.input_pickable:
		text = "Pick up " + item.name
		show()

func _on_item_thrown(_item):
	hide()

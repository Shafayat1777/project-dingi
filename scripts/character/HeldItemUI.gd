extends Label

# HeldItemUI.gd (attached to a Label node in your UI scene)

func _ready():
	# "Whenever HeldItemManager emits item_picked_up, call my function"
	HeldItemManager.item_picked_up.connect(_on_item_picked_up)
	HeldItemManager.item_thrown.connect(_on_item_thrown)

func _on_item_picked_up(item):
	text = "Holding: " + item.name
	show()

func _on_item_thrown(item):
	hide()

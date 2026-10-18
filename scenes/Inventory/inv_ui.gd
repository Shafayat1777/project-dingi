extends Control

var is_open :bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close()


func _unhandled_input(event):
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		else:
			open()

func open():
	visible = true
	is_open = true
	
func close():
	visible = false
	is_open = false

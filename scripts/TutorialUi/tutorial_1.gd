extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps running while the game is paused
	hide()
	await get_tree().create_timer(1.5).timeout
	if PauseMenue.skip_tutorials:
		return
	show()
	get_tree().paused = true

func _on_button_pressed() -> void:
	pass # Replace with function body.

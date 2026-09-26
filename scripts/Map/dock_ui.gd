extends CanvasLayer


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		hide()
		get_tree().paused = false
		get_viewport().set_input_as_handled()


func _on_button_4_pressed() -> void:
	if visible:
		hide()
		get_tree().paused = false
		get_viewport().set_input_as_handled()

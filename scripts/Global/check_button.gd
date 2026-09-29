extends CheckButton

func _ready() -> void:
	button_pressed = PauseMenue.full_screen

func _on_toggled(toggled_on: bool) -> void:
	PauseMenue.full_screen = toggled_on
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

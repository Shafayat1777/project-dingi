extends CheckButton

func _ready() -> void:
	button_pressed = PauseMenue.skip_tutorials

func _on_toggled(toggled_on: bool) -> void:
	PauseMenue.skip_tutorials = toggled_on

extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"

var click_count: int = 0

func _ready() -> void:
	text = "Next"
	intro_text.text = "[center]While the hook is attached to a ceiling, press/hold [img=64x64]res://assets/ui/keyboard_w.png[/img]\nto [color=yellow]climb up[/color] and enter a hanging state[/center]"

func _on_pressed() -> void:
	if click_count == 0:
		intro_text.text = "[center]While hanging, press/hold [img=64x64]res://assets/ui/keyboard_a.png[/img] / [img=64x64]res://assets/ui/keyboard_d.png[/img]\nto [color=yellow]swing[/color][/center]"
	elif click_count == 1:
		intro_text.text = "[center]While swinging, press [img=64x64]res://assets/ui/keyboard_space.png[/img]\nto [color=yellow]detach[/color][/center]"
		text = "Ok"
	else:
		root.hide()
		root.get_node('CanvasLayer').hide()
		get_tree().paused = false
	click_count += 1

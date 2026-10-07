extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"

var click_count: int = 0

func _ready() -> void:
	text = "Next"
	intro_text.text = "[center]Press [img=64x64]res://assets/ui/mouse_left.png[/img]\nto throw your [color=yellow]Hook[/color] while not holding an object[/center]"

func _on_pressed() -> void:
	if click_count == 0:
		intro_text.text = "[center]Hold [img=64x64]res://assets/ui/mouse_right.png[/img]\nto [color=yellow]aim[/color] before throwing[/center]"
	elif click_count == 1:
		intro_text.text = "[center]While the hook is attached to a wall or ceiling, press [img=64x64]res://assets/ui/keyboard_w.png[/img] / [img=64x64]res://assets/ui/keyboard_s.png[/img]\nto [color=yellow]climb up / down[/color][/center]"
	elif click_count == 2:
		intro_text.text = "[center]While hanging from the rope, press [img=64x64]res://assets/ui/keyboard_space.png[/img]\nto [color=yellow]jump[/color][/center]"
	elif click_count == 3:
		intro_text.text = "[center]Press [img=64x64]res://assets/ui/mouse_left.png[/img] again\nto [color=yellow]recall[/color] the hook[/center]"
	elif click_count == 4:
		intro_text.text = "[center]Use the [color=yellow]hook[/color] to reach new areas and progress[/center]"
		text = "Ok"
	else:
		root.hide()
		root.get_node('CanvasLayer').hide()
		get_tree().paused = false
	click_count += 1

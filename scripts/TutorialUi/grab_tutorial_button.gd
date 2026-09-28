extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"

var click_count: int = 0

func _ready() -> void:
	text = "Next"

func _on_pressed() -> void:
	if click_count == 0:
		intro_text.text = "[center]Press [img=64x64]res://assets/ui/keyboard_g.png[/img]\nto [color=yellow]drop[/color] the object you're holding[/center]"
	elif click_count == 1:
		intro_text.text = "[center]Press [img=64x64]res://assets/ui/mouse_left.png[/img]\nto [color=yellow]throw[/color] the object you're holding\n[i]It will fly towards your cursor[/i][/center]"
	elif click_count == 2:
		intro_text.text = "[center]Hold [img=64x64]res://assets/ui/mouse_right.png[/img]\nto [color=yellow]aim[/color] before throwing[/center]"
	elif click_count == 3:
		intro_text.text = "[center]Objects can be [color=yellow]stacked[/color] on top of each other.\nBuild a stack to reach new areas and progress[/center]"
		text = "Ok"
	else:
		root.hide()
		root.get_node('CanvasLayer').hide()
		get_tree().paused = false
	click_count += 1

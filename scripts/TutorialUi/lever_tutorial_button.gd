extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"

var click_count: int = 0

func _ready() -> void:
	text = "Next"
	intro_text.text = "[center]Acitave the [color=yellow]Lever[/color] to increase the water level[/center]"

func _on_pressed() -> void:
	if click_count == 0:
		intro_text.text = "[center]Use the [color=yellow]Hook[/color] to pull the boat towards you[/center]"
	else:
		root.hide()
		root.get_node('CanvasLayer').hide()
		get_tree().paused = false
	click_count += 1

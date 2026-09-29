extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	intro_text.text = "[center]Press [img=64x64]res://assets/ui/keyboard_space.png[/img]\nto [color=yellow]jump[/color] across the pit[/center]"


func _on_pressed() -> void:
	root.hide()
	root.get_node('CanvasLayer').hide()
	get_tree().paused = false

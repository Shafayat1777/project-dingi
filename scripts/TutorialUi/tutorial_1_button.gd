extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"

var clicked: int = 0

func _on_pressed() -> void:
	if clicked == 0:
		intro_text.text = "Press [img=32x32]res://assets/ui/keyboard_d.png[/img] / [img=32x32]res://assets/ui/keyboard_a.png[/img] to move Left / Right"
		text = "Ok"
		clicked += 1
	elif clicked == 1:
		root.hide()
		get_tree().paused = false
		clicked += 1

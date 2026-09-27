extends Button

@onready var root = owner
@onready var intro_text: RichTextLabel = $"../IntroText"
@onready var walk_tutorial: RichTextLabel = $"../WalkTutorial"

var clicked: int = 0

func _ready() -> void:
	walk_tutorial.hide()


func _on_pressed() -> void:
	if clicked == 0:
		intro_text.hide()
		walk_tutorial.show()
		text = "Ok"
		clicked += 1
	elif clicked == 1:
		intro_text.hide()
		walk_tutorial.hide()
		root.hide()
		get_tree().paused = false
		clicked += 1

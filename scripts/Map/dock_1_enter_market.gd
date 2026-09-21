extends Area2D

@onready var label: Label = $Label

func _ready() -> void:
	label.hide()

func _on_body_entered(body: Node2D) -> void:
	if body and body is CharacterBody2D:
		label.show()


func _on_body_exited(body: Node2D) -> void:
	if body and body is CharacterBody2D:
		label.hide()

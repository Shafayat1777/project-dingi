extends Node2D

@onready var sprite: Sprite2D = get_parent().get_node("Sprite2D")
@onready var label: Label = $Label

func _ready() -> void:
	label.hide()

func set_highlighted(state: bool) -> void:
	sprite.material.set_shader_parameter("outline_enabled", state)

func show_prompt() -> void:
	label.show()

func hide_prompt() -> void:
	label.hide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	show_prompt()
	set_highlighted(true)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	hide_prompt()
	set_highlighted(false)

extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_on := false

func _ready() -> void:
	sprite.play("off")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		toggle()

func toggle() -> void:
	is_on = not is_on
	sprite.play("on" if is_on else "off")

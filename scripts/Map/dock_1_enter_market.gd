extends Area2D

@onready var label: Label = $Label
@export var ui: CanvasLayer  # drag your PanelContainer here in the Inspector

var player_inside := false

func _ready() -> void:
	label.hide()
	ui.hide()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_inside = true
		label.show()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_inside = false
		label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player_inside and event.is_action_pressed("interact"):
		ui.show()
		get_tree().paused = true

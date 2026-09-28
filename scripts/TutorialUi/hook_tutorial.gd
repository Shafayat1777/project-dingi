extends Node2D

@onready var canvas_layer: CanvasLayer = $CanvasLayer
var body_passed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # keeps running while the game is paused
	canvas_layer.hide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body_passed == false:
		canvas_layer.show()
		get_tree().paused = true
		body_passed = true

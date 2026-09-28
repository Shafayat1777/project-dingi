extends Area2D

@onready var timer: Timer = $Timer
@export var spawn: Marker2D = null
var character: CharacterBody2D = null

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		character = body
		timer.start()


func _on_timer_timeout() -> void:
	if character != null and spawn != null:
		character.position = spawn.position
		character.velocity = Vector2.ZERO

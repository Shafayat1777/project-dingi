extends Area2D

@onready var timer: Timer = $Timer
@export var spawn: Marker2D = null
@export var boatspawn: Marker2D = null
@export var boat: RigidBody2D = null

var character: CharacterBody2D = null

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		character = body
		timer.start()


func _on_timer_timeout() -> void:
	if character != null and spawn != null:
		character.position = spawn.position
		character.velocity = Vector2.ZERO
		
		if boat != null and boatspawn != null:
			boat.set_deferred("global_position", boatspawn.global_position)
			boat.set_deferred("linear_velocity", Vector2.ZERO)
			boat.set_deferred("angular_velocity", 0.0)

extends Area2D

@export var spawn: Marker2D = null

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and spawn:
		body.set_deferred("global_position", spawn.global_position)
		body.set_deferred("linear_velocity", Vector2.ZERO)
		body.set_deferred("angular_velocity", 0.0)

extends RigidBody2D

func launch(direction_rotation: float, velocity: Vector2) -> void:
	linear_velocity = velocity.rotated(direction_rotation)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

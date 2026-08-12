extends Area2D

const SPEED: int = 200
const IMPACT_FORCE: float = 200.0

func _process(delta: float) -> void:
	position += transform.x * SPEED * delta


#func _on_body_entered(body: Node2D) -> void:
	#if body is RigidBody2D:
		#var impulse_dir = transform.x  # bullet's forward direction
		#body.apply_impulse(impulse_dir * IMPACT_FORCE, Vector2.ZERO)
	#set_process(false)
	##queue_free()

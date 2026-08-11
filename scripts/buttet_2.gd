extends Area2D

const SPEED: int = 4000
const IMPACT_FORCE: float = 200.0

func _process(delta: float) -> void:
	position += transform.x * SPEED * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		var impulse_dir = transform.x
		body.apply_impulse(impulse_dir * IMPACT_FORCE, Vector2.ZERO)
	set_process(false)
	$AnimatedSprite2D.play("impact")
	await $AnimatedSprite2D.animation_finished
	queue_free()

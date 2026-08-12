extends Area2D

const SPEED: int = 4000
const IMPACT_FORCE: float = 200.0

var hit: bool = false

func _physics_process(delta: float) -> void:
	if hit:
		return

	var motion: Vector2 = transform.x * SPEED * delta
	var space_state := get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + motion
	)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := space_state.intersect_ray(query)

	if result:
		global_position = result.position
		_on_hit(result.collider)
	else:
		global_position += motion

func _on_hit(body: Node2D) -> void:
	hit = true
	if body is RigidBody2D:
		var impulse_dir = transform.x
		body.apply_impulse(impulse_dir * IMPACT_FORCE, Vector2.ZERO)

	$AnimatedSprite2D.play("impact")
	await $AnimatedSprite2D.animation_finished
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

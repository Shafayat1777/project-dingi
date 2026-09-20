class_name HookAttachment
extends Node

@onready var hook: Hook = get_parent()

func _on_body_entered(body: Node) -> void:
	if hook.state == Hook.State.STUCK or hook.state == Hook.State.RECALLING:
		return

	hook.state = Hook.State.STUCK
	hook.set_deferred("freeze", true)
	hook.linear_velocity = Vector2.ZERO

	# rope starts at whatever length it was when it stuck, capped at max_range
	hook.current_rope_length = min(
		hook.global_position.distance_to(hook.player.global_position),
		hook.max_range
	)

	if body is RigidBody2D:
		hook.attach_stuck_body(body, hook.global_position - body.global_position)

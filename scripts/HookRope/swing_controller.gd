class_name SwingController
extends Node

@onready var hook: Hook = get_parent()

func constrain_rope(delta):
	# if stuck to a movable object, the hook follows it
	if hook.stuck_body:
		hook.global_position = hook.stuck_body.global_position

	var to_player = hook.player.global_position - hook.global_position
	var dist = to_player.length()

	if dist <= hook.current_rope_length:
		hook.player.is_swinging = false
		return

	hook.player.is_swinging = true

	var dir = to_player.normalized()

	# clamp player onto the current rope-length circle
	hook.player.global_position = hook.global_position + dir * hook.current_rope_length

	# swing physics: cancel only the outward velocity component,
	# keep the tangential (sideways) component so gravity swings the player in an arc
	var outward_speed = hook.player.velocity.dot(dir)
	if outward_speed > 0:
		hook.player.velocity -= dir * outward_speed

	# apply_central_force respects the body's mass automatically —
	# heavier objects accelerate slower under the same force, lighter ones faster
	if hook.stuck_body:
		hook.stuck_body.apply_central_force(dir * hook.drag_force)

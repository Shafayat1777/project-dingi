class_name HookThrower
extends Node

@onready var hook: Hook = get_parent()

func throw():
	hook.show()
	hook.state = Hook.State.FLYING
	hook.stuck_body = null
	hook.freeze = false
	hook.set_deferred("collision_layer", 8)  # Layer 4 = Hook
	hook.set_deferred("collision_mask", hook.stick_to_layers)
	hook.global_position = hook.player.global_position

	var dir = (hook.get_global_mouse_position() - hook.global_position).normalized()
	hook.linear_velocity = dir * hook.throw_speed
	hook.rotation = dir.angle()  # optional: point sprite toward mouse

func check_range():
	if hook.global_position.distance_to(hook.player.global_position) >= hook.max_range:
		hook.state = Hook.State.RECALLING

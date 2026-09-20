class_name HookRecaller
extends Node

@onready var hook: Hook = get_parent()

func recall():
	hook.state = Hook.State.RECALLING
	hook.detach_stuck_body()
	hook.player.is_swinging = false
	hook.freeze = false
	hook.set_deferred("collision_layer", 0)
	hook.set_deferred("collision_mask", 0)

func recall_hook():
	var dir = (hook.player.global_position - hook.global_position).normalized()
	hook.linear_velocity = dir * hook.recall_speed
	hook.rotation = dir.angle()

	if hook.global_position.distance_to(hook.player.global_position) < 20:
		hook.state = Hook.State.IDLE
		hook.detach_stuck_body()
		hook.player.is_swinging = false
		hook.freeze = true
		hook.linear_velocity = Vector2.ZERO
		hook.hide()

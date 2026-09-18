class_name RopeReel
extends Node

@onready var hook: Hook = get_parent()

func handle_reel(delta):
	if Input.is_action_pressed("climb_up"):
		hook.current_rope_length -= hook.reel_speed * delta
	if Input.is_action_pressed("climb_down"):
		hook.current_rope_length += hook.reel_speed * delta

	hook.current_rope_length = clamp(hook.current_rope_length, hook.min_range, hook.max_range)

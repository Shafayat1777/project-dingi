class_name RopeReel
extends Node

@onready var hook: Hook = get_parent()

func handle_reel(delta):
	if Input.is_action_pressed("climb_up"):
		hook.current_rope_length -= hook.reel_speed * delta
		_winch_stuck_body(1.0)
	if Input.is_action_pressed("climb_down"):
		hook.current_rope_length += hook.reel_speed * delta
		_winch_stuck_body(-1.0)

	hook.current_rope_length = clamp(hook.current_rope_length, hook.min_range, hook.max_range)

# When attached to a movable object (not static geometry like a TileMap),
# climbing also winches the object itself toward (climb_up) or away from
# (climb_down) the player - on top of whatever passive drag SwingController
# already applies once the rope is taut. sign > 0 pulls in, sign < 0 lets out.
func _winch_stuck_body(sign: float) -> void:
	if not hook.stuck_body:
		return
	var dir = (hook.player.global_position - hook.stuck_body.global_position).normalized()
	hook.stuck_body.apply_central_force(dir * sign * hook.stuck_body.mass * hook.reel_pull_strength)

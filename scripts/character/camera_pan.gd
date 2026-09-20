extends Camera2D

@export var max_look_ahead: float = 150.0
@export var pan_speed: float = 5.0

func _process(delta):
	var target_offset = Vector2.ZERO

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_pos = get_global_mouse_position()
		var player_pos = get_parent().global_position
		var direction = mouse_pos - player_pos
		target_offset = direction.limit_length(max_look_ahead)

	offset = offset.lerp(target_offset, delta * pan_speed)
	offset = clamp_offset_to_limits(offset)

func clamp_offset_to_limits(desired_offset: Vector2) -> Vector2:
	var player_pos = get_parent().global_position
	var half_view = (get_viewport_rect().size / zoom) / 2.0

	# If player is out of bounds on either axis, freeze BOTH axes
	# at the clamped position instead of letting the in-bounds axis keep tracking
	var out_of_bounds = (
		player_pos.x < limit_left or player_pos.x > limit_right or
		player_pos.y < limit_top or player_pos.y > limit_bottom
	)

	var effective_pos = player_pos
	if out_of_bounds:
		effective_pos = Vector2(
			clamp(player_pos.x, limit_left, limit_right),
			clamp(player_pos.y, limit_top, limit_bottom)
		)

	var min_offset = Vector2(
		limit_left + half_view.x - effective_pos.x,
		limit_top + half_view.y - effective_pos.y
	)
	var max_offset = Vector2(
		limit_right - half_view.x - effective_pos.x,
		limit_bottom - half_view.y - effective_pos.y
	)

	desired_offset.x = clamp(desired_offset.x, min_offset.x, max_offset.x)
	desired_offset.y = clamp(desired_offset.y, min_offset.y, max_offset.y)
	return desired_offset

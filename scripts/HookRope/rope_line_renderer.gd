class_name RopeLineRenderer
extends Node

@onready var hook: Hook = get_parent()

func update_line():
	# Point 0 = player side, Point 1 = hook side
	hook.line.set_point_position(0, hook.to_local(hook.player.global_position))
	hook.line.set_point_position(1, Vector2(0, 14))  # hook's own origin

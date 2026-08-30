extends RigidBody2D

@export var throw_speed := 800.0
@export var player: Node2D  # assign the character node in inspector

@onready var line: Line2D = $Line2D

var is_thrown := false

func _ready():
	top_level = true
	line.clear_points()
	line.add_point(Vector2.ZERO)  # point 0 - player side
	line.add_point(Vector2.ZERO)  # point 1 - hook side
	hide()
	freeze = true  # hook stays still until thrown

func _process(_delta):
	if is_thrown:
		update_line()

func _input(event):
	if event.is_action_pressed("shoot") and not is_thrown:
		if HeldItemManager.is_held == false:
			throw()

func throw():
	show()
	is_thrown = true
	freeze = false
	global_position = player.global_position

	var dir = (get_global_mouse_position() - global_position).normalized()
	linear_velocity = dir * throw_speed
	rotation = dir.angle()  # optional: point sprite toward mouse

func update_line():
	# Point 0 = player side, Point 1 = hook side
	line.set_point_position(0, to_local(player.global_position))
	line.set_point_position(1, Vector2(0, 14))  # hook's own origin

extends RigidBody2D

@export var throw_speed := 800.0
@export var recall_speed := 1000.0
@export var max_range := 500.0
@export_flags_2d_physics var stick_to_layers := 1 + 4  # tick World/Objects etc. in inspector
@export var player: Node2D  # assign the character node in inspector

@onready var line: Line2D = $Line2D

var is_thrown := false
var is_recalling := false
var is_stuck := false

func _ready():
	top_level = true
	line.clear_points()
	line.add_point(Vector2.ZERO)  # point 0 - player side
	line.add_point(Vector2.ZERO)  # point 1 - hook side
	hide()
	freeze = true  # hook stays still until thrown

	collision_mask = stick_to_layers
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _process(_delta):
	if is_thrown:
		update_line()

func _physics_process(_delta):
	if is_recalling:
		recall_hook()
	elif is_thrown and not is_stuck:
		check_range()

func _input(event):
	if event.is_action_pressed("shoot"):
		if not is_thrown and HeldItemManager.is_held == false:
			throw()
		elif is_thrown and not is_recalling:
			is_recalling = true
			is_stuck = false
			freeze = false

func throw():
	show()
	is_thrown = true
	is_recalling = false
	is_stuck = false
	freeze = false
	global_position = player.global_position

	var dir = (get_global_mouse_position() - global_position).normalized()
	linear_velocity = dir * throw_speed
	rotation = dir.angle()  # optional: point sprite toward mouse

func check_range():
	if global_position.distance_to(player.global_position) >= max_range:
		is_recalling = true

func _on_body_entered(_body: Node) -> void:
	if is_stuck or is_recalling:
		return

	is_stuck = true
	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO

func recall_hook():
	var dir = (player.global_position - global_position).normalized()
	linear_velocity = dir * recall_speed
	rotation = dir.angle()

	if global_position.distance_to(player.global_position) < 20:
		is_thrown = false
		is_recalling = false
		is_stuck = false
		freeze = true
		linear_velocity = Vector2.ZERO
		hide()

func update_line():
	# Point 0 = player side, Point 1 = hook side
	line.set_point_position(0, to_local(player.global_position))
	line.set_point_position(1, Vector2(0, 14))  # hook's own origin

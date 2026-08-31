extends RigidBody2D

enum State { IDLE, FLYING, STUCK, RECALLING }

@export var throw_speed := 800.0
@export var recall_speed := 1000.0
@export var max_range := 500.0
@export var drag_speed := 400.0
@export var drag_acceleration := 1000.0
@export_flags_2d_physics var stick_to_layers := 1 + 4
@export var player: Node2D

@onready var line: Line2D = $Line2D

var state := State.IDLE
var stuck_body: RigidBody2D = null

func _ready():
	top_level = true
	line.clear_points()
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	hide()
	freeze = true

	collision_mask = stick_to_layers
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _process(_delta):
	if state != State.IDLE:
		update_line()

func _physics_process(delta):
	match state:
		State.RECALLING:
			recall_hook()
		State.FLYING:
			check_range()
		State.STUCK:
			constrain_rope(delta)

func _input(event):
	if event.is_action_pressed("shoot"):
		if state == State.IDLE and HeldItemManager.is_held == false:
			throw()
		elif state == State.FLYING or state == State.STUCK:
			state = State.RECALLING
			stuck_body = null
			freeze = false
			set_deferred("collision_layer", 0)
			set_deferred("collision_mask", 0)

func throw():
	show()
	state = State.FLYING
	stuck_body = null
	freeze = false
	set_deferred("collision_layer", 8)  # Layer 4 = Hook
	set_deferred("collision_mask", stick_to_layers)
	global_position = player.global_position

	var dir = (get_global_mouse_position() - global_position).normalized()
	linear_velocity = dir * throw_speed
	rotation = dir.angle()

func check_range():
	if global_position.distance_to(player.global_position) >= max_range:
		state = State.RECALLING

func _on_body_entered(body: Node) -> void:
	if state == State.STUCK or state == State.RECALLING:
		return

	state = State.STUCK
	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO

	if body is RigidBody2D:
		stuck_body = body

func constrain_rope(delta):
	# if stuck to a movable object, the hook follows it
	if stuck_body:
		global_position = stuck_body.global_position

	var dist = player.global_position.distance_to(global_position)
	if dist <= max_range:
		return

	var dir = (player.global_position - global_position).normalized()

	# always clamp the player so they can't walk past rope length
	player.global_position = global_position + dir * max_range

	# if the anchor is a movable RigidBody2D, drag it toward the player too
	if stuck_body:
		stuck_body.linear_velocity = stuck_body.linear_velocity.move_toward(
			dir * drag_speed, drag_acceleration * delta
		)

func recall_hook():
	var dir = (player.global_position - global_position).normalized()
	linear_velocity = dir * recall_speed
	rotation = dir.angle()

	if global_position.distance_to(player.global_position) < 20:
		state = State.IDLE
		stuck_body = null
		freeze = true
		linear_velocity = Vector2.ZERO
		hide()

func update_line():
	line.set_point_position(0, to_local(player.global_position))
	line.set_point_position(1, Vector2(0, 14))

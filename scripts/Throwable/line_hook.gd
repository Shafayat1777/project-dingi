extends RigidBody2D

enum State { IDLE, FLYING, STUCK, RECALLING }

@export var throw_speed := 800.0
@export var recall_speed := 1000.0
@export var max_range := 500.0
@export var min_range := 40.0
@export var reel_speed := 200.0  # how fast climb_up/climb_down changes rope length
@export var drag_force := 20000.0
@export_flags_2d_physics var stick_to_layers := 1 + 4  # tick World/Objects etc. in inspector
@export var player: CharacterBody2D  # assign the character node in inspector

@onready var line: Line2D = $Line2D

var state := State.IDLE
var stuck_body: RigidBody2D = null
var current_rope_length := 0.0

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
	if state != State.IDLE:
		update_line()

func _physics_process(delta):
	match state:
		State.RECALLING:
			recall_hook()
		State.FLYING:
			check_range()
		State.STUCK:
			handle_reel(delta)
			constrain_rope(delta)

func _input(event):
	if event.is_action_pressed("shoot"):
		if state == State.IDLE and HeldItemManager.is_held == false:
			throw()
		elif state == State.FLYING or state == State.STUCK:
			state = State.RECALLING
			stuck_body = null
			player.is_swinging = false
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
	rotation = dir.angle()  # optional: point sprite toward mouse

func check_range():
	if global_position.distance_to(player.global_position) >= max_range:
		state = State.RECALLING

func _on_body_entered(body: Node) -> void:
	if state == State.STUCK or state == State.RECALLING:
		return

	state = State.STUCK
	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO

	# rope starts at whatever length it was when it stuck, capped at max_range
	current_rope_length = min(global_position.distance_to(player.global_position), max_range)

	if body is RigidBody2D:
		stuck_body = body

func handle_reel(delta):
	if Input.is_action_pressed("climb_up"):
		current_rope_length -= reel_speed * delta
	if Input.is_action_pressed("climb_down"):
		current_rope_length += reel_speed * delta

	current_rope_length = clamp(current_rope_length, min_range, max_range)

func constrain_rope(delta):
	# if stuck to a movable object, the hook follows it
	if stuck_body:
		global_position = stuck_body.global_position

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if dist <= current_rope_length:
		player.is_swinging = false
		return

	player.is_swinging = true

	var dir = to_player.normalized()

	# clamp player onto the current rope-length circle
	player.global_position = global_position + dir * current_rope_length

	# swing physics: cancel only the outward velocity component,
	# keep the tangential (sideways) component so gravity swings the player in an arc
	var outward_speed = player.velocity.dot(dir)
	if outward_speed > 0:
		player.velocity -= dir * outward_speed

	# apply_central_force respects the body's mass automatically —
	# heavier objects accelerate slower under the same force, lighter ones faster
	if stuck_body:
		stuck_body.apply_central_force(dir * drag_force)

func recall_hook():
	var dir = (player.global_position - global_position).normalized()
	linear_velocity = dir * recall_speed
	rotation = dir.angle()

	if global_position.distance_to(player.global_position) < 20:
		state = State.IDLE
		stuck_body = null
		player.is_swinging = false
		freeze = true
		linear_velocity = Vector2.ZERO
		hide()

func update_line():
	# Point 0 = player side, Point 1 = hook side
	line.set_point_position(0, to_local(player.global_position))
	line.set_point_position(1, Vector2(0, 14))  # hook's own origin

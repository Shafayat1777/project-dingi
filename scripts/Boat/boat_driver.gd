extends Node

@onready var boat: RigidBody2D = get_parent()

@export var row_force: float = 600.0      # continuous push while held down
@export var max_speed: float = 250.0

var active: bool = false

func set_active(state: bool) -> void:
	active = state

func _physics_process(_delta: float) -> void:
	if not active:
		return

	if Input.is_action_pressed("left"):
		boat.apply_central_force(Vector2(-row_force, 0))
	elif Input.is_action_pressed("right"):
		boat.apply_central_force(Vector2(row_force, 0))
	
	if boat.linear_velocity.length() > max_speed:
		boat.linear_velocity = boat.linear_velocity.limit_length(max_speed)

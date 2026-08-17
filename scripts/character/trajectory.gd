extends Node2D

const HOOKROPE = preload("res://scenes/Throwable/hook_rope_2.tscn")

@onready var marker_2d: Marker2D = $Marker2D
@onready var line_2d: Line2D = $Line2D

@export var initial_velocity: Vector2 = Vector2(800, 0) # y = -600
@export var gravity: float = 980.0


const MAX_POINTS = 60
const TIME_STEP = 0.05  # how far apart in time each point is

#func _ready() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())

	if Input.is_action_pressed("aim"):
		line_2d.show()
		update_trajectory(delta)
		if Input.is_action_just_pressed("shoot"):
			throw_grenade()
	if Input.is_action_just_released("aim"):
		line_2d.hide()

func update_trajectory(delta: float) -> void:
	line_2d.clear_points()
	
	var start_pos = global_position
	var velocity = initial_velocity.rotated(rotation)  # aim it with the node

	for i in MAX_POINTS:
		var t = i * TIME_STEP
		var point = start_pos + velocity * t + 0.5 * Vector2(0, gravity) * t * t
		line_2d.add_point(to_local(point))
		
	#var pos = to_local(global_position)

	#for i in MAX_POINTS:
		#line_2d.add_point(pos)
		#pos.x += 10


func throw_grenade() -> void:
	var hook_rope_instance = HOOKROPE.instantiate()
	get_tree().root.add_child(hook_rope_instance)
	hook_rope_instance.global_position = global_position
	#hook_rope_instance.launch(rotation, initial_velocity)
	var hook = hook_rope_instance.get_node("Hook")
	hook.launch(rotation, initial_velocity)

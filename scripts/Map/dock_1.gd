extends Node2D

@onready var label: Label = $Label
@onready var climb_point: Marker2D = $Marker2D

const DOCK_LAYER := 7
#const DOCK_Z_INDEX := 10

var touching_dock: bool = false
var player: CharacterBody2D = null

func _ready() -> void:
	label.hide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		label.show()
		touching_dock = true
		player = body
	elif body is RigidBody2D and "is_occupied" in body and body.is_occupied:
		label.show()

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		label.hide()
		touching_dock = false
		player = null
	elif body is RigidBody2D and "is_occupied" in body and body.is_occupied:
		label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if touching_dock and event.is_action_pressed("climb_up"):
		player.global_position = climb_point.global_position
		player.set_collision_mask_value(DOCK_LAYER, true)
		#player.z_index = DOCK_Z_INDEX

extends Node2D

@onready var label: Label = $Label
@onready var climb_point: Marker2D = $Marker2D
@onready var area: Area2D = $Area2D

const DOCK_LAYER := 7
#const DOCK_Z_INDEX := 10

var touching_dock: bool = false
var player: CharacterBody2D = null

func _ready() -> void:
	label.hide()

# Polled instead of driven by body_entered/exited: while driving, the player's
# own collider is disabled (boat_mount.gd), so the area never sees the player, and
# the boat's hull collider sits well below where the player stands so it can miss
# the area. So a driver counts as "in" when their position is inside the area's shape.
func _physics_process(_delta: float) -> void:
	player = null
	for body in area.get_overlapping_bodies():
		if body is CharacterBody2D:
			player = body
			break
	if player == null:
		for boat in get_tree().get_nodes_in_group("boat"):
			if "driver" in boat and boat.driver != null and _area_contains(boat.driver.global_position):
				player = boat.driver
				break
	touching_dock = player != null
	label.visible = touching_dock

func _area_contains(point: Vector2) -> bool:
	var shape_node: CollisionShape2D = area.get_node("CollisionShape2D")
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		return false
	var local := shape_node.global_transform.affine_inverse() * point
	var half := rect.size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y

# still wired in dock_1.tscn; state is handled in _physics_process above
func _on_area_2d_body_entered(_body: Node2D) -> void:
	pass

func _on_area_2d_body_exited(_body: Node2D) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if touching_dock and event.is_action_pressed("climb_up"):
		# driving: leave the boat first, otherwise the player is still a child of it
		var boat := player.get_parent() as RigidBody2D
		if boat != null and boat.get("driver") == player:
			boat.get_node("BoatMount").dismount()
		player.global_position = climb_point.global_position
		player.set_collision_mask_value(DOCK_LAYER, true)
		#player.z_index = DOCK_Z_INDEX

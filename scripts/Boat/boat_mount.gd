# BoatMount.gd — attached to the BoatMount (Node) component
extends Node2D

@onready var boat: RigidBody2D = get_parent()
@onready var exit_marker: Marker2D = $ExitMarker
@onready var boat_driver: Node = get_parent().get_node("BoatDriver")

const DOCK_LAYER := 7

var original_parent: Node = null

func mount(player: CharacterBody2D) -> void:
	if boat.is_occupied:
		return  # already have someone aboard, ignore

	original_parent = player.get_parent()
	# Freeze the player's own movement/animation logic
	player.set_physics_process(false)

	# Disable the player's own collider while riding, so it doesn't
	# independently collide with the world/cargo area while mounted
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	player_shape.set_deferred("disabled", true)

	# Reparent onto the boat, then restore world position
	# (reparenting resets local position relative to the new parent)
	original_parent.remove_child(player)
	boat.add_child(player)
	player.global_position = boat.global_position
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").reset_smoothing()

	# dock collision is only enabled by climbing the dock (dock_1.gd); drop it
	# when driving so it has to be re-earned by interacting with the dock again
	player.set_collision_mask_value(DOCK_LAYER, false)

	boat.is_occupied = true
	boat.driver = player
	boat_driver.set_active(true)

func dismount() -> void:
	var player: CharacterBody2D = boat.driver
	if player == null:
		return

	boat.remove_child(player)
	original_parent.add_child(player)
	player.global_position = exit_marker.global_position
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").reset_smoothing()

	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	player_shape.set_deferred("disabled", false)

	player.set_physics_process(true)

	boat.is_occupied = false
	boat.driver = null
	boat_driver.set_active(false)

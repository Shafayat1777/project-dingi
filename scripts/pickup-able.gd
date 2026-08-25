extends RigidBody2D
class_name PickupAble

var is_held: bool = false
var holder: Node2D = null

func pickup(holder_node: Node2D) -> void:
	is_held = true
	holder = holder_node
	freeze = true
	add_collision_exception_with(holder)

func drop() -> void:
	_release()

func throw(direction_rotation: float, velocity: Vector2) -> void:
	_release()
	linear_velocity = velocity.rotated(direction_rotation)

func _release() -> void:
	is_held = false
	freeze = false
	if holder:
		remove_collision_exception_with(holder)
	holder = null

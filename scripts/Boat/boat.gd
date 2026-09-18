extends RigidBody2D

@export var is_on_water: bool = true:
	set(value):
		is_on_water = value
		_apply_surface_settings()

var is_occupied: bool = false
var driver: CharacterBody2D = null

# opted out of water_spring.gd's per-frame velocity drag — the boat already
# gets its own surface friction/linear_damp via _apply_surface_settings(),
# and the extra drag fought rowing (boat_driver.gd) and buoyancy2.gd's forces
var receives_water_drag: bool = false

func _ready() -> void:
	_apply_surface_settings()

func _apply_surface_settings() -> void:
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()

	if is_on_water:
		linear_damp = 0.5
		physics_material_override.friction = 0.0
	else:
		linear_damp = 0.2
		physics_material_override.friction = 1.0

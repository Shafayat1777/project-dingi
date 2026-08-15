extends RigidBody2D

@onready var sprite: Sprite2D = $Sprite2D

const SPRITE_ROTATION_OFFSET = PI / 2
const VELOCITY_THRESHOLD = 20.0  # ignore tiny/resting movement

func launch(direction_rotation: float, velocity: Vector2) -> void:
	linear_velocity = velocity.rotated(direction_rotation)
	update_sprite_rotation(direction_rotation)

func _physics_process(delta: float) -> void:
	if linear_velocity.length() > VELOCITY_THRESHOLD:
		update_sprite_rotation(linear_velocity.angle())

func update_sprite_rotation(angle: float) -> void:
	var degrees = wrapf(rad_to_deg(angle), 0, 360)
	
	if degrees > 90 and degrees < 270:
		sprite.scale.x = -1
	else:
		sprite.scale.x = 1
	
	sprite.rotation = angle + SPRITE_ROTATION_OFFSET

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

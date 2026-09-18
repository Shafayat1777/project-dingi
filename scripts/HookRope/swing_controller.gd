class_name SwingController
extends Node

@export var spring_stiffness := 40.0   # how hard the rope pulls back once it's stretched taut
@export var spring_damping := 6.0      # how quickly the bounce/oscillation settles
@export var max_stretch := 30.0        # hard safety cap so a weak spring can't stretch forever

@onready var hook: Hook = get_parent()

func constrain_rope(delta):
	# if stuck to a movable object, the hook follows it
	if hook.stuck_body:
		hook.global_position = hook.stuck_body.global_position

	var to_hook = hook.global_position - hook.player.global_position
	var dist = to_hook.length()
	var stretch = dist - hook.current_rope_length

	if stretch <= 0.0:
		# rope has slack - no pull, player moves/falls freely
		hook.player.is_swinging = false
		return

	hook.player.is_swinging = true

	# follow the rope's actual curve near the player when we have one,
	# otherwise fall back to a straight line to the hook
	var dir = hook.rope_renderer.get_pull_direction()
	if dir == Vector2.ZERO:
		dir = to_hook / dist

	# spring-damper: pulls back proportional to how stretched the rope is,
	# damped against the velocity component running along the rope, so it
	# settles into a swing instead of oscillating forever
	var velocity_along_rope = hook.player.velocity.dot(dir)
	var spring_force = dir * stretch * spring_stiffness
	var damping_force = -dir * velocity_along_rope * spring_damping

	hook.player.velocity += (spring_force + damping_force) * delta

	# safety net: only kicks in past max_stretch, otherwise it's pure spring
	if stretch > max_stretch:
		hook.player.global_position += dir * (stretch - max_stretch)

	# apply_central_force respects the body's mass automatically —
	# heavier objects accelerate slower under the same force, lighter ones faster
	if hook.stuck_body:
		hook.stuck_body.apply_central_force(-dir * hook.drag_force)

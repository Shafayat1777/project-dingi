class_name SwingController
extends Node

@export var spring_stiffness := 40.0   # how hard the rope pulls back once it's stretched taut
@export var spring_damping := 6.0      # how quickly the bounce/oscillation settles
@export var max_stretch := 30.0        # hard safety cap so a weak spring can't stretch forever

@onready var hook: Hook = get_parent()

func constrain_rope(delta):
	# if stuck to a movable object, the hook follows its actual stick point
	# (not the object's origin, which could be a noticeably different spot)
	if hook.stuck_body:
		hook.global_position = hook.stuck_body.global_position + hook.attach_offset

	var to_hook = hook.global_position - hook.player.global_position
	var dist = to_hook.length()
	var stretch = dist - hook.current_rope_length

	if stretch <= 0.0:
		# rope has slack - no pull, player moves/falls freely
		hook.player.is_swinging = false
		return

	var dir = to_hook / dist

	# spring-damper: pulls back proportional to how stretched the rope is,
	# damped against the velocity component running along the rope, so it
	# settles into a swing instead of oscillating forever
	var velocity_along_rope = hook.player.velocity.dot(dir)
	var spring_force = dir * stretch * spring_stiffness
	var damping_force = -dir * velocity_along_rope * spring_damping
	var tension = spring_force + damping_force

	# While RopeReel is actively winching an attached RigidBody2D, it shrinks/
	# lengthens current_rope_length on purpose to drive the tow (see
	# rope_reel.gd) - that "stretch" is the object being reeled, not the
	# player straining against the rope. Feeding it into the player's own
	# velocity was what caused the player to get yanked toward the object for
	# a frame. So: skip applying tension to the player while that's happening,
	# but keep applying the full tension/drag to the object below - the tow
	# itself is unaffected, only the leak into the player is cut.
	var reeling_object = hook.stuck_body != null and (
		Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down")
	)

	if reeling_object:
		hook.player.is_swinging = false
	else:
		hook.player.is_swinging = true
		hook.player.velocity += tension * delta

		# safety net: only kicks in past max_stretch, otherwise it's pure spring
		if stretch > max_stretch:
			hook.player.global_position += dir * (stretch - max_stretch)

	# Newton's third law: the rope pulls the attached object back with the
	# same tension it exerts on the player, just reversed. apply_central_force
	# still divides by the body's own mass, so light objects (e.g. pickupable
	# items) get dragged noticeably but bounded by the spring's own limits —
	# unlike a fixed constant force, which can fling a low-mass body violently.
	if hook.stuck_body:
		hook.stuck_body.apply_central_force(-tension)

		# on top of that, a dedicated drag pull toward the player once taut.
		# multiplying by the body's own mass cancels out apply_central_force's
		# division by mass, so this behaves as a plain acceleration
		# (drag_strength px/sec^2) regardless of how heavy the object is —
		# consistent towing feel for light or heavy attached objects alike.
		hook.stuck_body.apply_central_force(-dir * hook.stuck_body.mass * hook.drag_strength)

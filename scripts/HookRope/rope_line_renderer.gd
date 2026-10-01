class_name RopeLineRenderer
extends Node

@export var segment_count := 12         # number of points in the rope chain
@export var gravity := 900.0            # sag strength, px/sec^2
@export var damping := 0.98             # velocity retention per step (verlet "friction")
@export var stiffness_iterations := 8   # constraint relaxation passes per step (higher = stiffer/less stretchy)

# Terrain collision for the rope's visual chain only (the swing force in
# swing_controller.gd still uses a straight line to the hook, not this chain -
# see get_pull_direction()'s doc comment). World + object (layer 2 = player is
# deliberately excluded so the rope never snags on the player it's attached to).
@export_flags_2d_physics var collision_mask := 1 + 4
@export var collision_radius := 3.0

@onready var hook: Hook = get_parent()

var points: PackedVector2Array = []
var old_points: PackedVector2Array = []
var initialized := false
var _query_shape := CircleShape2D.new()

# Called from Hook._physics_process every physics step while state != IDLE.
func simulate(delta: float) -> void:
	if hook.state == Hook.State.IDLE:
		initialized = false
		hook.line.clear_points()
		return

	var start = hook.player.global_position
	var end = hook.global_position

	if not initialized:
		_init_points(start, end)
		initialized = true

	_integrate(delta)
	_resolve_collisions()
	_apply_constraints(start, end)
	_draw()

func _init_points(start: Vector2, end: Vector2) -> void:
	points.resize(segment_count)
	old_points.resize(segment_count)
	for i in segment_count:
		var t = float(i) / float(segment_count - 1)
		var p = start.lerp(end, t)
		points[i] = p
		old_points[i] = p

func _integrate(delta: float) -> void:
	# skip the two anchor points (index 0 = player side, last = hook side)
	for i in range(1, points.size() - 1):
		var current = points[i]
		var velocity = (current - old_points[i]) * damping
		var next = current + velocity + Vector2.DOWN * gravity * delta * delta
		old_points[i] = current
		points[i] = next

# Pushes each free chain point out of any world/object geometry it ended up
# inside this step, so the line drapes/bends over edges and corners instead of
# cutting straight through them. Runs before the distance constraints so the
# length pass can re-tension the chain around the pushed-out point afterward.
func _resolve_collisions() -> void:
	_query_shape.radius = collision_radius
	var space_state := hook.get_world_2d().direct_space_state

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _query_shape
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# skip the two anchor points (index 0 = player side, last = hook side)
	for i in range(1, points.size() - 1):
		query.transform = Transform2D(0.0, points[i])
		var contacts := space_state.collide_shape(query, 8)
		if contacts.is_empty():
			continue

		# world tiles are a grid of individual square shapes, so a point sitting
		# right on a 90-degree tile corner can get a degenerate (zero-length)
		# push vector from collide_shape - the closest point on both the query
		# circle and the tile corner is the same vertex, so there's no normal to
		# push along. Fall back to ejecting the point back along the direction
		# it arrived from, so it doesn't stay clipped into the corner forever.
		var incoming := points[i] - old_points[i]
		var fallback_dir := -incoming.normalized() if incoming.length() > 0.0001 else Vector2.UP

		# collide_shape returns pairs of points: [point_on_query_shape, point_on_other_shape, ...]
		for c in range(0, contacts.size(), 2):
			var point_on_self: Vector2 = contacts[c]
			var point_on_other: Vector2 = contacts[c + 1]
			var push = point_on_self - point_on_other
			var depth = push.length()
			if depth > 0.0001:
				points[i] += push.normalized() * (collision_radius - depth)
			else:
				points[i] += fallback_dir * collision_radius

		# only kill velocity into the surface when we actually pushed out this
		# step - resetting old_points unconditionally would zero the rope's
		# sag/swing momentum every frame, even with nothing to collide against
		old_points[i] = points[i]

func _apply_constraints(start: Vector2, end: Vector2) -> void:
	# rope "length" the constraints try to hold: current_rope_length while STUCK
	# (so reeling and slack are visible), otherwise just the live hook-player distance
	var rope_length: float
	if hook.state == Hook.State.STUCK:
		rope_length = hook.current_rope_length
	else:
		rope_length = start.distance_to(end)
		if rope_length < 1.0:
			rope_length = 1.0

	var segment_length = rope_length / float(points.size() - 1)

	for _iter in stiffness_iterations:
		points[0] = start
		points[points.size() - 1] = end

		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i + 1]
			var diff = p2 - p1
			var dist = diff.length()
			if dist == 0.0:
				continue
			var error = (dist - segment_length) / dist
			var correction = diff * 0.5 * error

			if i != 0:
				points[i] += correction
			if i + 1 != points.size() - 1:
				points[i + 1] -= correction

	points[0] = start
	points[points.size() - 1] = end

func _draw() -> void:
	hook.line.clear_points()
	for i in points.size():
		hook.line.add_point(hook.to_local(points[i]))

# Total length of the simulated chain right now (can be > current_rope_length
# when the rope is being stretched taut). Not used for the swing force (see
# note in the Verlet Rope + Elastic Swing section above) — kept for potential
# future use (e.g. visually tinting the rope when overstretched).
func get_chain_length() -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

# Direction from the player anchor (points[0]) toward the next chain point —
# i.e. the direction the rope is actually pulling the player, following the
# rope's curve rather than a straight line to the hook.
func get_pull_direction() -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var to_next = points[1] - points[0]
	if to_next.length() < 0.001:
		return Vector2.ZERO
	return to_next.normalized()

class_name RopeLineRenderer
extends Node

@export var segment_count := 12         # number of points in the rope chain
@export var gravity := 900.0            # sag strength, px/sec^2
@export var damping := 0.98             # velocity retention per step (verlet "friction")
@export var stiffness_iterations := 8   # constraint relaxation passes per step (higher = stiffer/less stretchy)

@onready var hook: Hook = get_parent()

var points: PackedVector2Array = []
var old_points: PackedVector2Array = []
var initialized := false

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

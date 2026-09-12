extends Node2D

## Small floating leaf/moss decoration for water surfaces.
## Position is driven externally by water_body.gd (which samples the spring
## height at this node's x each physics frame) - this script only owns the
## procedural shape/color, drawn via _draw() the same way smooth_path_modified.gd
## draws the border line, since no leaf/moss art assets exist in the project.

enum DebrisType { LEAF, MOSS, LILY_PAD, BRANCH, PETAL }

@export var debris_type: DebrisType = DebrisType.LEAF
#used for LEAF/MOSS (their original shared color); LILY_PAD/BRANCH/PETAL use
#their own fixed tones instead, since one exported color doesn't suit all types
@export var base_color: Color = Color(0.35, 0.45, 0.15, 0.9)
const LILY_PAD_COLOR = Color(0.25, 0.55, 0.2, 0.95)
const BRANCH_COLOR = Color(0.32, 0.22, 0.14, 0.95)
#a small palette so petals sprinkle in varied pastel tones rather than all
#being identical
const PETAL_COLORS = [
	Color(0.95, 0.55, 0.65, 0.95),
	Color(0.98, 0.85, 0.9, 0.95),
	Color(0.9, 0.4, 0.5, 0.95),
	Color(0.98, 0.75, 0.55, 0.95),
]

#set by water_body.gd before spawning; drift_speed stays 0 for moss (static)
var drift_speed: float = 0.0
var bob_amplitude: float = 2.0
var bob_speed: float = 1.0
var bob_phase: float = 0.0

#water_body.gd owns base_x (drift/wrap) and reads push_offset each frame to
#compose the final position; this node only owns and smooths push_offset
#itself, so the two update loops never fight over .position directly
var base_x: float = 0.0
var push_offset: Vector2 = Vector2.ZERO

#fixed downward offset assigned once at spawn (water_body.gd), so some debris
#sits visibly within the reflective water fill rather than all of it lining up
#exactly on the surface line
var depth_offset: float = 0.0
@export var push_strength = 6.0
@export var push_radius = 20.0
@export var push_smoothing = 6.0
@onready var push_area: Area2D = $PushArea if has_node("PushArea") else null

var shape_points: PackedVector2Array = PackedVector2Array()
var shape_color: Color
var vein_length: float = 0.0
#optional per-vertex colors (same size as shape_points) for a subtle gradient
#fill instead of one flat color - used by LILY_PAD; empty for the other types
var shape_vertex_colors: PackedColorArray = PackedColorArray()
#tick mark positions for BRANCH knots, and lily-pad veins; local-space line
#segments drawn on top of the fill in _draw()
var detail_lines: Array = []

func _ready():
	randomize_shape()

func _process(delta):
	#continuously eases push_offset toward a target based on current overlap,
	#instead of one-off kicks on body_entered - smooth in both directions
	#(approach and recovery) and self-correcting if the character lingers
	var target_offset = Vector2.ZERO

	if debris_type == DebrisType.LEAF and push_area:
		for body in push_area.get_overlapping_bodies():
			var away = global_position - body.global_position
			var dist = away.length()
			if dist < 0.01:
				continue
			var proximity = clamp(1.0 - dist / push_radius, 0.0, 1.0)
			target_offset += (away / dist) * push_strength * proximity

	push_offset = push_offset.lerp(target_offset, clamp(push_smoothing * delta, 0.0, 1.0))

func randomize_shape():
	var scale_factor = randf_range(0.8, 1.3)
	rotation = randf_range(0.0, TAU)
	vein_length = 0.0
	detail_lines = []
	shape_vertex_colors = PackedColorArray()

	match debris_type:
		DebrisType.LEAF:
			shape_color = Color.from_hsv(
				base_color.h + randf_range(-0.03, 0.03),
				base_color.s,
				clamp(base_color.v * randf_range(0.85, 1.15), 0.0, 1.0),
				base_color.a
			)
			vein_length = 5.0 * scale_factor
			shape_points = PackedVector2Array([
				Vector2(0, -5), Vector2(2.5, -2), Vector2(3, 0), Vector2(2.5, 2),
				Vector2(0, 5), Vector2(-2.5, 2), Vector2(-3, 0), Vector2(-2.5, -2)
			])

		DebrisType.MOSS:
			shape_color = Color.from_hsv(
				base_color.h + randf_range(-0.03, 0.03),
				base_color.s,
				clamp(base_color.v * randf_range(0.85, 1.15), 0.0, 1.0),
				base_color.a
			)
			var point_count = 8
			var points = PackedVector2Array()
			for i in range(point_count):
				var angle = (TAU / point_count) * i
				var r = randf_range(3.0, 6.0)
				points.append(Vector2(cos(angle), sin(angle)) * r)
			shape_points = points

		DebrisType.LILY_PAD:
			shape_color = Color.from_hsv(
				LILY_PAD_COLOR.h + randf_range(-0.02, 0.02),
				LILY_PAD_COLOR.s,
				clamp(LILY_PAD_COLOR.v * randf_range(0.9, 1.1), 0.0, 1.0),
				LILY_PAD_COLOR.a
			)
			#a ring of points sweeping most of the way around, then back to
			#center - the missing wedge is the classic lily-pad notch
			var radius = 7.0
			var arc_points = 10
			var notch_half_angle = deg_to_rad(20.0)
			var points = PackedVector2Array()
			for i in range(arc_points + 1):
				var t = float(i) / float(arc_points)
				var angle = notch_half_angle + t * (TAU - notch_half_angle * 2.0)
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			points.append(Vector2.ZERO)
			shape_points = points

			#warm highlight at the center fading to the rim color, instead of
			#one flat green fill
			var highlight_color = Color.from_hsv(
				clamp(shape_color.h + 0.08, 0.0, 1.0),
				shape_color.s * 0.6,
				clamp(shape_color.v * 1.3, 0.0, 1.0),
				shape_color.a
			)
			var colors = PackedColorArray()
			for i in range(points.size() - 1):
				colors.append(shape_color)
			colors.append(highlight_color)
			shape_vertex_colors = colors

			detail_lines = [
				[Vector2.ZERO, Vector2(cos(1.2), sin(1.2)) * radius],
				[Vector2.ZERO, Vector2(cos(2.6), sin(2.6)) * radius],
				[Vector2.ZERO, Vector2(cos(4.4), sin(4.4)) * radius],
			]

		DebrisType.BRANCH:
			shape_color = Color.from_hsv(
				BRANCH_COLOR.h + randf_range(-0.02, 0.02),
				BRANCH_COLOR.s,
				clamp(BRANCH_COLOR.v * randf_range(0.85, 1.15), 0.0, 1.0),
				BRANCH_COLOR.a
			)
			#a thin, pointed-end stick
			shape_points = PackedVector2Array([
				Vector2(-14, 0), Vector2(-10, -1.5), Vector2(10, -1.5),
				Vector2(14, 0), Vector2(10, 1.5), Vector2(-10, 1.5)
			])
			detail_lines = [
				[Vector2(-5, -1.5), Vector2(-6, -3.0)],
				[Vector2(1, 1.5), Vector2(2, 3.0)],
				[Vector2(6, -1.5), Vector2(7, -3.0)],
			]

		DebrisType.PETAL:
			var petal_base = PETAL_COLORS[randi() % PETAL_COLORS.size()]
			shape_color = Color.from_hsv(
				petal_base.h + randf_range(-0.015, 0.015),
				petal_base.s,
				clamp(petal_base.v * randf_range(0.9, 1.1), 0.0, 1.0),
				petal_base.a
			)
			#a small rounded teardrop - narrow point at one end, wide rounded
			#curve at the other
			shape_points = PackedVector2Array([
				Vector2(0, -4), Vector2(2, -2), Vector2(2.5, 0.5),
				Vector2(1, 2.5), Vector2(0, 3), Vector2(-1, 2.5),
				Vector2(-2.5, 0.5), Vector2(-2, -2)
			])

	for i in range(shape_points.size()):
		shape_points[i] *= scale_factor
	for line in detail_lines:
		line[0] *= scale_factor
		line[1] *= scale_factor

	queue_redraw()

func _draw():
	if shape_points.size() == 0:
		return
	if shape_vertex_colors.size() == shape_points.size():
		draw_polygon(shape_points, shape_vertex_colors)
	else:
		draw_colored_polygon(shape_points, shape_color)
	if debris_type == DebrisType.LEAF and vein_length > 0.0:
		draw_line(Vector2(0, -vein_length), Vector2(0, vein_length), shape_color.darkened(0.3), 0.5)
	for line in detail_lines:
		draw_line(line[0], line[1], shape_color.darkened(0.3), 0.5)

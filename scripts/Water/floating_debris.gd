extends Node2D

## Small floating leaf/moss decoration for water surfaces.
## Position is driven externally by water_body.gd (which samples the spring
## height at this node's x each physics frame) - this script only owns the
## procedural shape/color, drawn via _draw() the same way smooth_path_modified.gd
## draws the border line, since no leaf/moss art assets exist in the project.

enum DebrisType { LEAF, MOSS }

@export var debris_type: DebrisType = DebrisType.LEAF
@export var base_color: Color = Color(0.35, 0.45, 0.15, 0.9)

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
@export var push_strength = 6.0
@export var push_radius = 20.0
@export var push_smoothing = 6.0
@onready var push_area: Area2D = $PushArea if has_node("PushArea") else null

var shape_points: PackedVector2Array = PackedVector2Array()
var shape_color: Color
var vein_length: float = 0.0

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

	shape_color = Color.from_hsv(
		base_color.h + randf_range(-0.03, 0.03),
		base_color.s,
		clamp(base_color.v * randf_range(0.85, 1.15), 0.0, 1.0),
		base_color.a
	)

	if debris_type == DebrisType.LEAF:
		vein_length = 5.0 * scale_factor
		shape_points = PackedVector2Array([
			Vector2(0, -5), Vector2(2.5, -2), Vector2(3, 0), Vector2(2.5, 2),
			Vector2(0, 5), Vector2(-2.5, 2), Vector2(-3, 0), Vector2(-2.5, -2)
		])
	else:
		vein_length = 0.0
		var point_count = 8
		var points = PackedVector2Array()
		for i in range(point_count):
			var angle = (TAU / point_count) * i
			var r = randf_range(3.0, 6.0)
			points.append(Vector2(cos(angle), sin(angle)) * r)
		shape_points = points

	for i in range(shape_points.size()):
		shape_points[i] *= scale_factor

	queue_redraw()

func _draw():
	if shape_points.size() == 0:
		return
	draw_colored_polygon(shape_points, shape_color)
	if debris_type == DebrisType.LEAF and vein_length > 0.0:
		draw_line(Vector2(0, -vein_length), Vector2(0, vein_length), shape_color.darkened(0.3), 0.5)

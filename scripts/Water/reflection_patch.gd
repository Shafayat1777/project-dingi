extends Polygon2D

## Small, freely-placeable, purely decorative mirror-reflection patch.
## Reuses shaders/Water/water_body.gdshader unmodified (its optional foam
## block no-ops when spring_count stays at its default 0) - only the mirror
## line differs per instance, computed here each frame from this polygon's
## own current top or bottom edge, so reshaping/moving it in the editor just
## works without any script changes.

enum MirrorEdge { BOTTOM, TOP }

#BOTTOM (default) mirrors content above this patch, appearing below it - the
#same look as the existing water. TOP mirrors content below this patch,
#appearing mirrored upward within it - for a patch placed near the top of the
#screen/behind a platform to suggest water continuing on the far side.
@export var mirror_edge: MirrorEdge = MirrorEdge.BOTTOM

#purely decorative debris scattered within this patch - reuses
#scripts/Water/floating_debris.gd's shapes, but with its PushArea (the
#character-push collision) freed before ever entering the tree, so none of
#this patch's debris has any physics/collision presence at all
@export var leaf_count = 4
@export var moss_count = 2
@export var lily_pad_count = 2
@export var branch_count = 1
@export var petal_count = 3
@export var debris_drift_speed_range = Vector2(4.0, 10.0)
@export var debris_bob_amplitude_range = Vector2(1.0, 2.0)
@export var debris_bob_speed_range = Vector2(0.8, 1.6)

var floating_debris_scene = preload("res://scenes/water/floating_debris.tscn")
var patch_debris: Array = []

func _ready():
	# draw order is left entirely to this node's own z_index/scene-tree
	# position (normal Polygon2D behavior) - do NOT force it here. Since
	# hint_screen_texture reflects whatever was actually drawn before this
	# node in render order, placing the patch behind the tilemap (lower
	# z_index or earlier in the tree) makes it naturally reflect only what's
	# behind/before the tilemap, with the tilemap then occluding it on top.
	# duplicate the material - otherwise every instance of this scene would
	# share one ShaderMaterial resource and fight over the same water_level
	if material:
		material = material.duplicate()

	# instantiate one throwaway node first just to read its DebrisType enum
	# constants (matches how water_body.gd references d.DebrisType.LEAF after
	# instancing, rather than hardcoding the enum's underlying int values here)
	var probe = floating_debris_scene.instantiate()
	_spawn_debris(probe.DebrisType.LEAF, leaf_count)
	_spawn_debris(probe.DebrisType.MOSS, moss_count)
	_spawn_debris(probe.DebrisType.LILY_PAD, lily_pad_count)
	_spawn_debris(probe.DebrisType.BRANCH, branch_count)
	_spawn_debris(probe.DebrisType.PETAL, petal_count)
	probe.free()

func _spawn_debris(debris_type, count: int):
	var bounds = _get_local_bounds()
	if bounds.size == Vector2.ZERO:
		return

	for i in range(count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = debris_type
		# strip all physics before this node ever enters the tree - no
		# PushArea means no collision shape, no character interaction
		if d.has_node("PushArea"):
			d.get_node("PushArea").queue_free()

		# always positive, matching water_body.gd's leaf_drift_speed_range
		# convention - the main water's debris only ever drifts one direction,
		# so the patch's debris should flow the same way, not a random mix
		d.set_meta("drift_speed", randf_range(debris_drift_speed_range.x, debris_drift_speed_range.y))
		d.bob_amplitude = randf_range(debris_bob_amplitude_range.x, debris_bob_amplitude_range.y)
		d.bob_speed = randf_range(debris_bob_speed_range.x, debris_bob_speed_range.y)
		d.bob_phase = randf_range(0.0, TAU)
		d.set_meta("baseline_y", randf_range(bounds.position.y, bounds.position.y + bounds.size.y))

		# counteract this patch's own node scale so debris stays the same
		# absolute size as the main water's debris, regardless of how big/small
		# this particular patch has been resized to
		if scale.x != 0 and scale.y != 0:
			d.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)

		d.position = Vector2(randf_range(bounds.position.x, bounds.position.x + bounds.size.x), d.get_meta("baseline_y"))
		add_child(d)
		patch_debris.append(d)

func _get_local_bounds() -> Rect2:
	if polygon.size() == 0:
		return Rect2()
	var min_p = polygon[0]
	var max_p = polygon[0]
	for p in polygon:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return Rect2(min_p, max_p - min_p)

func _process(delta):
	if polygon.size() == 0 or not material:
		return

	var min_y = polygon[0].y
	var max_y = polygon[0].y
	for p in polygon:
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var edge_local_y = min_y if mirror_edge == MirrorEdge.BOTTOM else max_y
	var edge_world_y = (global_transform * Vector2(0, edge_local_y)).y

	var vp = get_viewport()
	var screen_point = vp.get_canvas_transform() * Vector2(global_position.x, edge_world_y)
	var viewport_height = vp.get_visible_rect().size.y
	if viewport_height > 0:
		material.set_shader_parameter("water_level", screen_point.y / viewport_height)

	_update_debris(delta)

func _update_debris(delta):
	if patch_debris.is_empty():
		return
	var bounds = _get_local_bounds()
	var t = Time.get_ticks_msec() * 0.001

	for d in patch_debris:
		var drift_speed = d.get_meta("drift_speed")
		var x = d.position.x + drift_speed * delta
		if x > bounds.position.x + bounds.size.x:
			x = bounds.position.x
		elif x < bounds.position.x:
			x = bounds.position.x + bounds.size.x

		var bob = sin(t * d.bob_speed + d.bob_phase) * d.bob_amplitude
		d.position = Vector2(x, d.get_meta("baseline_y") + bob)

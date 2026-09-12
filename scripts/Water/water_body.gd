##This is the script that controls the water body
##it contains all the spring of our water
extends Node2D

#spring factor, dampening factor and spread factor
#spread factor dictates how much the waves will spread to their neighbors
@export var k = 0.015
@export var d = 0.04
@export var spread = 0.019


#the spring array
var springs = []
@export var passes = 20

#distance in pixel between each spring
@export var distance_between_springs = 32
#number of springs in the scene
@export var spring_number = 30

#total water body length
var water_length = distance_between_springs * spring_number

#spring scene reference
@onready var water_spring = preload("res://scenes/water/water_spring.tscn")

#water splash scene reference
@onready var splash_particles = preload("res://scenes/water/water_splash.tscn")

#the body of water depth
@export var depth = 1000
var target_height = global_position.y
var bottom = target_height + depth

#referene to our polygon2D
@onready var water_polygon = $Water_Polygon

#reference to our water border
@onready var water_border = $Water_Border
@export var border_thickness = 1.1
#intializes the spring array and all the springs

@export var particle_splash_threshold = 1.0
#minimum speed to trigger particle splash

#draw order relative to entities (player, boat, etc); water must draw after
#(on top of) anything it should reflect, so hint_screen_texture captures it
@export var foreground_z = 1

#fixed-size buffer pushed to the shader as foam data; must be >= spring_number
const MAX_SPRING_UNIFORMS = 128

#per-spring foam energy, bumped only by actual splashes (never by idle wave
#motion - that caused the whole body to pulse white in a previous attempt) and
#decayed each frame, so foam reads as "just impacted" rather than ambient noise
var foam_energy = []
@export var foam_energy_scale = 0.2
@export var foam_decay = 0.9

enum WaterState { STILL , NORMAL , STORMY }
enum WaveDirection { LEFT, RIGHT}

@export var water_state: WaterState = WaterState.NORMAL :
	set(value):
		water_state = value
		apply_water_state()

@export var wave_direction:  WaveDirection = WaveDirection.RIGHT

var idle_wave_amplitude = 0.3
var idle_wave_speed = 1.5
var idle_wave_length = 0.05

@export var spread_damping = 0.085

#restricts wave motion (idle wave, spread, splashes) to the spring index range
#[ravine_start_index, ravine_end_index] - e.g. a narrow gap in the terrain where
#the water is actually visible from above. Springs outside this range are held
#perfectly flat at rest, so the border reads as a straight line everywhere else.
#Leave ravine_start_index at -1 to apply wave motion across the whole body.
@export var ravine_start_index = -1
@export var ravine_end_index = -1

func is_in_ravine(index: int) -> bool:
	if ravine_start_index < 0:
		return true
	return index >= ravine_start_index and index <= ravine_end_index

#border line opacity: crisp inside the ravine, near-invisible everywhere else
#(the border still exists there so buoyancy/physics are unaffected, it's purely
#a visual fade), with a short blend zone so the fade isn't an abrupt seam
@export var ravine_border_alpha = 0.7
@export var flat_border_alpha = 0.05
@export var border_edge_fade = 48.0

func get_ravine_world_x_range() -> Vector2:
	return Vector2(springs[ravine_start_index].position.x, springs[ravine_end_index].position.x)

func get_debris_world_x_range() -> Vector2:
	#the water's visual fill (Water_Polygon) already spans the whole body, even
	#though wave motion/border opacity are ravine-restricted - debris follows
	#the visual span, not the narrower wave-only range
	return Vector2(springs[0].position.x, springs[springs.size() - 1].position.x)

#small drifting leaves + static moss patches floating on the surface, purely
#decorative (no art assets exist, so shapes are drawn procedurally - see
#scripts/Water/floating_debris.gd). Position is driven here each physics frame
#by sampling the spring height at each debris's x, reusing the same bracketing-
#spring interpolation buoyant_object.gd already uses for the same purpose.
@onready var floating_debris_scene = preload("res://scenes/water/floating_debris.tscn")
@export var leaf_count = 30
@export var moss_count = 18
@export var lily_pad_count = 10
@export var branch_count = 8
#"sprinkles" - kept sparse compared to the other debris types
@export var petal_count = 14
@export var leaf_drift_speed_range = Vector2(4.0, 10.0)
@export var lily_pad_drift_speed_range = Vector2(1.0, 3.0)
@export var debris_bob_amplitude_range = Vector2(1.0, 2.5)
@export var debris_bob_speed_range = Vector2(0.8, 1.6)
#most debris stays near the surface (small values), but a random few are
#assigned a deeper offset so they sit visibly within the reflective fill
#instead of every piece lining up exactly on the wavy border
@export var debris_depth_range = Vector2(0.0, 140.0)
var floating_debris = []

func spawn_floating_debris():
	var x_range = get_debris_world_x_range()

	for i in range(leaf_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.LEAF
		d.drift_speed = randf_range(leaf_drift_speed_range.x, leaf_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(moss_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.MOSS
		d.drift_speed = 0.0
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(lily_pad_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.LILY_PAD
		d.drift_speed = randf_range(lily_pad_drift_speed_range.x, lily_pad_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(branch_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.BRANCH
		d.drift_speed = randf_range(leaf_drift_speed_range.x, leaf_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

	for i in range(petal_count):
		var d = floating_debris_scene.instantiate()
		d.debris_type = d.DebrisType.PETAL
		d.drift_speed = randf_range(leaf_drift_speed_range.x, leaf_drift_speed_range.y)
		add_debris(d, randf_range(x_range.x, x_range.y))

func add_debris(d, x_local: float):
	d.z_index = foreground_z + 1
	d.bob_amplitude = randf_range(debris_bob_amplitude_range.x, debris_bob_amplitude_range.y)
	d.bob_speed = randf_range(debris_bob_speed_range.x, debris_bob_speed_range.y)
	d.bob_phase = randf_range(0.0, TAU)
	#uniform across the full range, so debris spreads evenly through the water's
	#depth instead of clustering near the surface
	d.depth_offset = randf_range(debris_depth_range.x, debris_depth_range.y)
	d.base_x = x_local
	d.position.x = x_local
	add_child(d)
	floating_debris.append(d)

func update_floating_debris(delta):
	if springs.size() < 2:
		return
	var x_range = get_debris_world_x_range()
	var t = Time.get_ticks_msec() * 0.001

	for d in floating_debris:
		if d.drift_speed > 0.0:
			d.base_x += d.drift_speed * delta
			if d.base_x > x_range.y:
				d.base_x = x_range.x

		var bob = sin(t * d.bob_speed + d.bob_phase) * d.bob_amplitude
		d.position = Vector2(
			d.base_x + d.push_offset.x,
			get_water_height_at_local_x(d.base_x) + bob + d.push_offset.y + d.depth_offset
		)

func get_water_height_at_local_x(x_local: float) -> float:
	#same bracketing-spring linear interpolation buoyant_object.gd uses, kept
	#local here since debris positions are in this node's local space already
	for i in range(springs.size() - 1):
		var a = springs[i]
		var b = springs[i + 1]
		if x_local >= a.position.x and x_local <= b.position.x:
			var lerp_t = (x_local - a.position.x) / (b.position.x - a.position.x)
			return lerp(a.position.y, b.position.y, lerp_t)

	if x_local < springs[0].position.x:
		return springs[0].position.y
	return springs[springs.size() - 1].position.y



func _ready():

	water_polygon.z_index = foreground_z
	water_border.z_index = foreground_z

	water_border.width = border_thickness
	water_border.spline_length = distance_between_springs/2
	
	spread = spread / 100
	
	apply_water_state()
	
	#loops through all the springs
	#makes an array with all the springs
	#initializes each spring
	for i in range(spring_number):
		#the spring x position
		#they are generated from left to right -----> 0,32,64 etc
		var x_position = distance_between_springs * i
		var w = water_spring.instantiate()
		
		add_child(w)
		springs.append(w)
		w.initialize(x_position,i)
		w.set_collision_width(distance_between_springs)
		w.splash.connect(self.splash)
		foam_energy.append(0.0)

	splash(2,5)
	spawn_floating_debris()

func _physics_process(delta):

	#moves all the springs accordingly; springs outside the ravine are pinned
	#flat instead of simulated, so the border stays a straight line there
	for i in range(springs.size()):
		if is_in_ravine(i):
			springs[i].water_update(k,d)
		else:
			springs[i].height = springs[i].target_height
			springs[i].position.y = springs[i].target_height
			springs[i].velocity = 0

	
	apply_idle_wave()
	
	#represents the movement of the left and right neighbor of the springs
	var left_deltas = []
	var right_deltas = []
	
	#initialize the values with an array of zeros
	for i in range (springs.size()):
		left_deltas.append(0)
		right_deltas.append(0)
		pass
	
	for j in range(passes):
		#loops through each spring of our array
		for i in range(springs.size()):
			#adds velocity to the spring to the LEFT of the current spring
			if i > 0:
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height) * spread_damping
				springs[i-1].velocity += left_deltas[i]
			#adds velocity to the spring to the RIGHT of the current spring
			if i < springs.size()-1:
				right_deltas[i] = spread * (springs[i].height - springs [i+1].height) * spread_damping
				springs[i+1].velocity += right_deltas[i]
	new_border()
	draw_water_body()
	push_foam_to_shader()
	update_floating_debris(delta)

func _process(delta):
	#pushed every rendered frame (not just every physics tick) so the mirror's
	#flip line always matches the camera transform that frame is actually
	#rendered with - otherwise, on frames between physics ticks, water_level
	#lags the moving camera and the reflection visibly jitters
	push_water_level_to_shader()

func push_foam_to_shader():
	#packs each spring's foam energy into a fixed-size buffer for the shader
	#to sample; energy only rises from real splash() events (see splash())
	var displacement := PackedFloat32Array()
	displacement.resize(MAX_SPRING_UNIFORMS)

	for i in range(MAX_SPRING_UNIFORMS):
		if i < foam_energy.size():
			displacement[i] = foam_energy[i]
			foam_energy[i] *= foam_decay
		else:
			displacement[i] = 0.0

	water_polygon.material.set_shader_parameter("spring_displacement", displacement)
	water_polygon.material.set_shader_parameter("spring_count", springs.size())

func get_average_surface_world_y() -> float:
	var total_height = 0.0
	for s in springs:
		total_height += s.global_position.y
	return total_height / springs.size()

func push_water_level_to_shader():
	#converts the spring surface's average world height into normalized
	#screen-space Y, so the mirror shader's flip line tracks the camera
	var average_surface_y = get_average_surface_world_y()

	var vp = get_viewport()
	var screen_point = vp.get_canvas_transform() * Vector2(global_position.x, average_surface_y)
	var viewport_height = vp.get_visible_rect().size.y
	if viewport_height <= 0:
		return

	water_polygon.material.set_shader_parameter("water_level", screen_point.y / viewport_height)

func draw_water_body():
	
	#gets the curve of the border
	var curve = water_border.curve
	
	#makes an array of the points in the curve
	var points = Array(curve.get_baked_points())
	
	var water_polygon_points = points
	
	#gets the first and last index of our surface array
	var first_index = 0
	var last_index = water_polygon_points.size()-1


	
	#add other two points at the bottom of the polygon, to close the water body
	water_polygon_points.append(Vector2(water_polygon_points[last_index].x, bottom))
	water_polygon_points.append(Vector2(water_polygon_points[first_index].x, bottom))
	
	#transfroms our normal array into a packedvector2array
	#the polygon draw function uses packedvector2array to draw the polygon, so we convert it
	water_polygon_points = PackedVector2Array(water_polygon_points)

	water_polygon.polygon = water_polygon_points
	water_polygon.uv = build_polygon_uvs(water_polygon_points)

func build_polygon_uvs(points: PackedVector2Array) -> PackedVector2Array:
	#Polygon2D only auto-generates bounding-box-normalized UVs when it has a
	#texture assigned; ours has none, so its shader's UV would otherwise be
	#degenerate (effectively (0,0) everywhere). Build proper UVs manually so
	#UV.x/UV.y in water_body.gdshader actually vary across the shape (used for
	#foam indexing and the rim-foam edge mask).
	var min_x = points[0].x
	var max_x = points[0].x
	var min_y = points[0].y
	var max_y = points[0].y
	for p in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var width = max(max_x - min_x, 0.001)
	var height = max(max_y - min_y, 0.001)

	var uvs = PackedVector2Array()
	uvs.resize(points.size())
	for i in range(points.size()):
		uvs[i] = Vector2((points[i].x - min_x) / width, (points[i].y - min_y) / height)

	return uvs

func new_border():
	#Draw a new border to the water
	
	#creates a new curve 2D
	var curve = Curve2D.new().duplicate()
	
	#creates a new array, that holds the positions of the surface points
	#we'll use those points to draw our border
	var surface_points = []
	for i in range(springs.size()):
		surface_points.append(springs[i].position)
	
	#adds the points to the curve
	for i in range(surface_points.size()):
		curve.add_point(surface_points[i])
	
	water_border.curve = curve
	water_border.smooth(true)
	update_border_fade()
	water_border.queue_redraw()

func update_border_fade():
	#fades the border line's alpha down to flat_border_alpha away from the
	#ravine, so it reads as a subtle hint of the waterline rather than a hard
	#line cutting across dry ground; full alpha inside the ravine itself
	if ravine_start_index < 0:
		water_border.point_colors = PackedColorArray()
		return

	var baked_points = water_border.curve.get_baked_points()
	var ravine_x = get_ravine_world_x_range()
	var colors := PackedColorArray()
	colors.resize(baked_points.size())

	for i in range(baked_points.size()):
		var x = baked_points[i].x
		var dist_outside = 0.0
		if x < ravine_x.x:
			dist_outside = ravine_x.x - x
		elif x > ravine_x.y:
			dist_outside = x - ravine_x.y
		var t = clamp(dist_outside / border_edge_fade, 0.0, 1.0)
		var alpha = lerp(ravine_border_alpha, flat_border_alpha, t)
		colors[i] = Color(water_border.color.r, water_border.color.g, water_border.color.b, alpha)

	water_border.point_colors = colors
#this function adds a speed to a spring with this index
func splash(index,speed):
	if index >= 0 and index < springs.size() and is_in_ravine(index):
		springs[index].velocity += speed
		if abs(speed) >= particle_splash_threshold:
			spawn_splash_particles(index, speed)
			foam_energy[index] = clamp(foam_energy[index] + abs(speed) * foam_energy_scale, 0.0, 1.0)
	pass


func spawn_splash_particles(index, speed):
	var p = splash_particles.instantiate()
	add_child(p)
	p.global_position = springs[index].global_position
	
	# scale particle intensity with impact speed
	p.amount = clamp(int(abs(speed) * 2), 2, 5)
	
	var mat = p.process_material.duplicate()
	
	var colors = [Color(0.6, 0.8, 1.0, 0.9), Color(1.0, 1.0, 1.0, 0.9)]
	mat.color = colors[randi() % colors.size()]
	
	p.process_material = mat
	p.emitting = true
	
	# auto-remove after particles finish
	await get_tree().create_timer(p.lifetime + 0.1).timeout
	p.queue_free()


func apply_water_state():
	match water_state:
		WaterState.STILL:
			k = 0.018
			d = 0.06
			spread = 0.0010
			passes = 12
			idle_wave_amplitude = 0.05
			idle_wave_speed = 0.5
		WaterState.NORMAL:
			k = 0.015
			d = 0.25
			spread = 0.10
			passes = 8
			idle_wave_amplitude = 0.6
			idle_wave_speed = 6
			idle_wave_length = 0.25
		WaterState.STORMY:
			k = 0.0015
			d = 0.25
			spread = 0.10      
			passes = 8
			idle_wave_amplitude = 0.2
			idle_wave_speed = 3.5
			idle_wave_length = 0.02

func apply_idle_wave():
	var t = Time.get_ticks_msec() * 0.001
	var dir = 1.0 if wave_direction == WaveDirection.RIGHT else -1.0

	for i in range(springs.size()):
		if not is_in_ravine(i):
			continue
		var s = springs[i]
		var wave = sin(s.position.x * idle_wave_length - t * idle_wave_speed * dir) * idle_wave_amplitude
		s.velocity += wave

	if water_state == WaterState.STORMY and randf() < 0.02:
		var random_index = randi() % springs.size()
		splash(random_index, randf_range(-3.0, 3.0))

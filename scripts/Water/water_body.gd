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



func _ready():
	
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

	splash(2,5)
	
func _physics_process(delta):
	
	#moves all the springs accordingly
	for i in springs:
		i.water_update(k,d)
	
	
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
	water_border.queue_redraw()
#this function adds a speed to a spring with this index
func splash(index,speed):
	if index >= 0 and index < springs.size():
		springs[index].velocity += speed
		if abs(speed) >= particle_splash_threshold:
			spawn_splash_particles(index, speed)
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
	
	for s in springs:
		var wave = sin(s.position.x * idle_wave_length - t * idle_wave_speed * dir) * idle_wave_amplitude
		s.velocity += wave 
	
	if water_state == WaterState.STORMY and randf() < 0.02:
		var random_index = randi() % springs.size()
		splash(random_index, randf_range(-3.0, 3.0))

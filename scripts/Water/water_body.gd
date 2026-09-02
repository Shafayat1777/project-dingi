##This is the script that controls the water body
##it contains all the spring of our water
extends Node2D

#spring factor, dampening factor and spread factor
#spread factor dictates how much the waves will spread to their neighbors
@export var k = 0.010
@export var d = 0.09
@export var spread = 0.9


#the spring array
var springs = []
@export var passes = 16

#distance in pixel between each spring
@export var distance_between_springs = 32
#number of springs in the scene
@export var spring_number = 12

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

func _ready():
	
	water_border.width = border_thickness
	water_border.spline_length = distance_between_springs/2
	
	spread = spread / 1000
	
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
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height)
				springs[i-1].velocity += left_deltas[i]
			#adds velocity to the spring to the RIGHT of the current spring
			if i < springs.size()-1:
				right_deltas[i] = spread * (springs[i].height - springs [i+1].height)
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
		spawn_splash_particles(index, speed)
	pass


func spawn_splash_particles(index, speed):
	var p = splash_particles.instantiate()
	add_child(p)
	p.global_position = springs[index].global_position
	
	# scale particle intensity with impact speed
	p.amount = clamp(int(abs(speed) * 2), 2, 5)
	
	p.emitting = true
	
	# auto-remove after particles finish
	await get_tree().create_timer(p.lifetime + 0.1).timeout
	p.queue_free()

## Spring Modeling


extends Node2D

#the spring's current velocity
var velocity = 0

#the force being applied to the spring
var force = 0

#the current height of the spring
var height = 0

#the natural position of the spring
var target_height = 0

@onready var collision = $Area2D/CollisionShape2D

#the index of this spring
#we will set it on initialize
var index = 0

#variable for objects colliding in water
var bodies_in_water = []

#how much an external object will affect this spring
@export var motion_factor = 0.03
#how much an external object will affect this spring horizontally
@export var side_factor = 0.3
#how much and external object will affect its speed in water; lower = more resistance
@export var water_drag = 0.97
#ripple effect while idle
@export var idle_ripple_factor = 0.6
#seconds between idle pulses
@export var idle_ripple_interval = 0.5
var idle_ripple_timer = 0.0
@export var idle_velocity_threshold = 5.0



func _physics_process(delta):
	for body in bodies_in_water:
		if is_instance_valid(body):
			if body is RigidBody2D:
				body.linear_velocity *= water_drag
			elif body is CharacterBody2D:
				body.velocity *= water_drag
	
	if bodies_in_water.size() > 0:
		var should_idle_ripple = true
		for body in bodies_in_water:
			if not is_instance_valid(body):
				continue
			var vel = body.linear_velocity if body is RigidBody2D else body.velocity
			if vel.length() > idle_velocity_threshold:
				should_idle_ripple = false
		
		if should_idle_ripple:
			idle_ripple_timer += delta
			if idle_ripple_timer >= idle_ripple_interval:
				idle_ripple_timer = 0.0
				var pulse = sin(Time.get_ticks_msec() * 0.005) * idle_ripple_factor
				emit_signal("splash", index, pulse)

var collided_with = null

# new custom signal
signal splash

func water_update(spring_constant, dampening):
	## This function applies the hooke's law force to the spring
	## This fuction will be called in each frame
	## hooke's law -----> F = -K * x
	
	#update the height value based on our current position
	height = position.y
	
	#the spring current extention
	var x = height - target_height
	
	var loss = -dampening * velocity
	
	
	#hooke's law: 
	force = - spring_constant * x + loss
	
	#apply the force to the velocity
	#equivalent to velocity = velocity + force
	velocity += force
	
	velocity = clamp(velocity, -30.0, 30.0) #velocity clamp for safety
	
	#make the spring move
	position.y += velocity
	pass

func initialize(x_position,id):
	height = position.y
	target_height = position.y
	velocity = 0
	position.x = x_position
	index = id

func set_collision_width(value):
	#this function will set the collison shape size of our springs
	
	var size = collision.shape.size
	
	#the new size will maintain the value on the y width
	#the "value" variable is the space between springs, which we already have
	var new_size = Vector2(value, size.y)
	collision.shape.size = new_size
	
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	#called when a body collides with a spring
	
	#if the body already collided with the spring, then do not collide
	if body in bodies_in_water:
		return
	
	bodies_in_water.append(body)
	
	
	# we multiply the velocity of the body by the motion factor
	#if we didn't the speed would be huge, depending on the use case
	if body is RigidBody2D:
		var speed = clamp((abs(body.linear_velocity.y) + abs(body.linear_velocity.x) *side_factor) * motion_factor,-5.0,2.0)
		emit_signal("splash", index, speed)
	if body is CharacterBody2D:
		var speed = clamp((abs(body.velocity.y) + abs(body.velocity.x) * side_factor) * motion_factor,-5.0,2.0)
		emit_signal("splash", index, speed)
	#pass # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
		bodies_in_water.erase(body)
	#pass # Replace with function body.

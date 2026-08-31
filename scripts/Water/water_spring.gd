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

#how much an external object will affect this spring
var motion_factor = 0.009

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
	if body == collided_with:
		return
	
	collided_with = body
	
	
	# we multiply the velocity of the body by the motion factor
	#if we didn't the speed would be huge, depending on the use case
	if body is RigidBody2D:
		var speed = body.linear_velocity.y * motion_factor
		emit_signal("splash", index, speed)
	if body is CharacterBody2D:
		var speed = body.velocity.y * motion_factor
		emit_signal("splash", index, speed)
	#pass # Replace with function body.

extends Node2D

const ROPE_PIECES = preload("res://scenes/Items/rope_piece.tscn")

@onready var STATIC_BODY: StaticBody2D = $StaticBody2D

@export var rope_length: int = 2

var segments: Array[RigidBody2D] = []
var segment_spacing: float
var head_height: float

func _ready() -> void:
	var sample = ROPE_PIECES.instantiate()
	var shape = sample.get_node("CollisionShape2D").shape as CapsuleShape2D
	var head_shape = STATIC_BODY.get_node("CollisionShape2D").shape as RectangleShape2D
	segment_spacing = shape.height
	head_height = head_shape.size.y
	sample.queue_free()
	
	for i in rope_length:
		var piece = ROPE_PIECES.instantiate()
		piece.position = STATIC_BODY.position + Vector2(0, segment_spacing * (i  + 1) + 2 )
		add_child(piece)
		segments.append(piece)
	
	for i in rope_length:
		var joint = PinJoint2D.new()
		joint.disable_collision = true
		add_child(joint)

		if i == 0:
			joint.position = STATIC_BODY.position + Vector2(20, segment_spacing/2 + 1)
			joint.node_a = STATIC_BODY.get_path()
			joint.node_b = segments[0].get_path()
			print(joint.position)
			
			
		else:
			joint.node_a = segments[i - 1].get_path()
			joint.node_b = segments[i].get_path()
			joint.position = segments[i - 1].position + Vector2(0, segment_spacing / 2)

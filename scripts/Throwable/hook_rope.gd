extends Node2D

const ROPE_PIECES = preload("res://scenes/Items/rope_piece.tscn")

@onready var HOOK: RigidBody2D = $Hook

@export var rope_length: int = 10
@export var base_mass: float = 1.0
@export var mass_decrement: float = 0.1

var segment_spacing: float
var segments: Array[RigidBody2D] = []

func _ready() -> void:
	# Get spacing dynamically from the piece's own collision shape
	var sample = ROPE_PIECES.instantiate()
	var shape = sample.get_node("CollisionShape2D").shape as CapsuleShape2D
	segment_spacing = shape.height
	sample.queue_free()

	# Instantiate all the rope pieces
	for i in rope_length:
		var piece = ROPE_PIECES.instantiate()
		piece.position = HOOK.position + Vector2(0, segment_spacing * (i + 1))
		piece.mass = max(base_mass - mass_decrement * i, 0.01)  # avoid mass hitting 0 or negative
		add_child(piece)
		segments.append(piece)

	# Create joints connecting each piece to the previous one
	for i in rope_length:
		var joint = PinJoint2D.new()
		joint.softness = 0.0
		joint.bias = 0.0
		add_child(joint)

		if i == 0:
			joint.position = HOOK.position + Vector2(0, segment_spacing / 2)
			joint.node_a = HOOK.get_path()
			joint.node_b = segments[0].get_path()
		else:
			joint.position = segments[i - 1].position + Vector2(0, segment_spacing / 2)
			joint.node_a = segments[i - 1].get_path()
			joint.node_b = segments[i].get_path()

func _process(delta: float) -> void:
	pass

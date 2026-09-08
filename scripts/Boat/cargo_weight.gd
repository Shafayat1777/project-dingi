# CargoWeight.gd
extends Node

@export var base_mass: float = 5.0
var cargo_weight: float = 0.0
var aboard: Dictionary = {}

@onready var boat: RigidBody2D = get_parent()

func _ready() -> void:
	boat.mass = base_mass

func _on_cargo_area_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D):
		return
	if aboard.has(body):
		return

	aboard[body] = body.mass
	_recalculate()

func _on_cargo_area_body_exited(body: Node2D) -> void:
	if not aboard.has(body):
		return
	aboard.erase(body)
	_recalculate()

func _recalculate() -> void:
	cargo_weight = 0.0
	for w in aboard.values():
		cargo_weight += w
	boat.mass = base_mass + cargo_weight
	print(boat.mass)

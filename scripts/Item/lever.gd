extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var tilemap: TileMapLayer
@export var waterbody: Node2D
@export var water_killzone :Area2D= null
@export var move_offset := Vector2(0, 600)
@export var water_move_offset := Vector2(0, -357)
@export var water_killzone_offset := Vector2(0, -250)
@export var speed := 60.0
@export var water_speed := 81.0
@export var water_killzone_speed := 60.0


var is_on := false
var call_toggle := false
var start_pos: Vector2
var water_start_pos: Vector2
var water_killzone_start_pos: Vector2

func _ready() -> void:
	sprite.play("off")
	if tilemap == null or waterbody == null:
		push_warning("Lever: tilemap or waterbody is not assigned")
		set_physics_process(false)
		return
	start_pos = tilemap.position
	water_start_pos = waterbody.position
	water_killzone_start_pos = water_killzone.position

func _physics_process(delta: float) -> void:
	var target := start_pos + move_offset if is_on else start_pos
	var water_target := water_start_pos + water_move_offset if is_on else water_start_pos
	var water_killzone_target := water_killzone_start_pos + water_killzone_offset if is_on else water_killzone_start_pos
	tilemap.position = tilemap.position.move_toward(target, speed * delta)
	waterbody.position = waterbody.position.move_toward(water_target, water_speed * delta)
	water_killzone.position =  water_killzone.position.move_toward(water_killzone_target, water_killzone_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and call_toggle:
		toggle()

func toggle() -> void:
	is_on = not is_on
	sprite.play("on" if is_on else "off")


func _on_proximity_highlight_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		call_toggle = true


func _on_proximity_highlight_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		call_toggle = false

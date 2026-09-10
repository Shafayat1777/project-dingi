extends Node2D

@onready var boat: RigidBody2D = get_parent()
@onready var boat_mount: Node = get_parent().get_node("BoatMount")
@onready var sprite: Sprite2D = get_parent().get_node("Sprite2D")
@onready var label: Label = $Label

var nearby_player: CharacterBody2D = null

func _ready() -> void:
	label.hide()

func set_highlighted(state: bool) -> void:
	sprite.material.set_shader_parameter("outline_enabled", state)

func show_prompt() -> void:
	label.show()

func hide_prompt() -> void:
	label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if boat.is_occupied:
		boat_mount.dismount()
		if nearby_player != null:
			show_prompt()  # player likely still standing right next to it after dismount
	elif nearby_player != null:
		boat_mount.mount(nearby_player)
		hide_prompt()      # already aboard, no need to keep prompting "enter"
		set_highlighted(false)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	
	nearby_player = body
	
	if not boat.is_occupied:
		show_prompt()
		set_highlighted(true)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return

	if body == nearby_player:
		nearby_player = null

	hide_prompt()
	set_highlighted(false)

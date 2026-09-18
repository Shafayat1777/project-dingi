extends Area2D
class_name InteractionPrompt

@export var popup_text: String = "Press E to interact"
@export var gap_above: float = 10.0
@export var detection_size: Vector2 = Vector2(64, 64)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var character_body: CharacterBody2D = null
var target_sprite: Sprite2D = null
var offset_from_target: Vector2 = Vector2.ZERO  # cached local offset (relative to object), computed once

func _ready() -> void:
	# Set the detection zone size (this Area2D's own collision shape,
	# used to know when the player is close enough to interact).
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = detection_size

	label.text = popup_text
	label.hide()  # hidden until the player enters range

	# Find the Sprite2D on the object this component is attached to,
	# so we can apply the outline shader to it.
	target_sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if target_sprite and target_sprite.material == null:
		target_sprite.material = ShaderMaterial.new()
		target_sprite.material.shader = load("res://shaders/Objects/outline.gdshader")

	# top_level = true makes this node ignore the parent's transform
	# completely (no inherited position, rotation, or scale/flip).
	# From now on, label.global_position and label.rotation are the
	# ONLY things that control where it appears — nothing is inherited.
	label.top_level = true

	# Wait one frame so the Label's size is fully calculated based on its
	# text/font before we read label.size — right after setting .text,
	# the size can still be stale/zero for a frame, which throws off
	# horizontal centering.
	await get_tree().process_frame
	label.reset_size()

	_calculate_offset()

func _process(_delta: float) -> void:
	# Every frame, manually place the label at the object's current
	# global position plus our fixed offset. Since the label no longer
	# inherits the object's transform (top_level), this offset is never
	# rotated or mirrored by the object flipping or spinning — it always
	# stays "above" in true world-space terms.
	var target := get_parent() as Node2D
	label.global_position = target.global_position + offset_from_target
	label.rotation = 0.0  # keep it always upright, never rotated

func _on_body_entered(body: Node2D) -> void:
	# Only react to the player (CharacterBody2D), and only if the player
	# isn't currently holding something.
	if body is CharacterBody2D and not HeldItemManager.is_held:
		label.show()
		character_body = body
		_set_outline(true)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		label.hide()
		character_body = null
		_set_outline(false)

func _set_outline(value: bool) -> void:
	# Toggle the shader's "enabled" uniform on/off to turn the outline
	# effect on the sprite on or off.
	if target_sprite and target_sprite.material is ShaderMaterial:
		target_sprite.material.set_shader_parameter("enabled", value)

func _calculate_offset() -> void:
	var target := get_parent()
	var height := 0.0

	# Try to determine the object's height from its own CollisionShape2D.
	var col_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape and col_shape.shape:
		var shape := col_shape.shape
		if shape is RectangleShape2D:
			height = shape.size.y
		elif shape is CircleShape2D:
			height = shape.radius * 2
		elif shape is CapsuleShape2D:
			height = shape.height

	# Fallback: estimate height from the Sprite2D's texture size instead.
	if height == 0.0:
		var sprite := target.get_node_or_null("Sprite2D") as Sprite2D
		if sprite and sprite.texture:
			height = sprite.texture.get_height() * sprite.scale.y

	# Store this as a fixed world-space offset (not attached to any
	# rotating/flipping transform) — used every frame in _process().
	# X: shift left by half the label's width to center it horizontally.
	# Y: move up to the top edge, add gap, then move up by the label's
	#    own height so its bottom (not top) sits at that point.
	offset_from_target = Vector2(-label.size.x / 2, -(height / 2) - gap_above - label.size.y)

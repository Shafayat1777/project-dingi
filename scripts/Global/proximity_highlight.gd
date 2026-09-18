extends Area2D
class_name InteractionPrompt

@export var popup_text: String = "Press E to interact"
@export var gap_above: float = 10.0
@export var detection_size: Vector2 = Vector2(64, 64)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var character_body: CharacterBody2D = null

# CanvasItem is the common base class for BOTH Sprite2D and AnimatedSprite2D.
# Typing this as CanvasItem (instead of just Sprite2D) lets this one variable
# hold either type, so the outline shader works no matter which the object uses.
var target_sprite: CanvasItem = null

var offset_from_target: Vector2 = Vector2.ZERO  # cached local offset (relative to object), computed once

func _ready() -> void:
	# Set the detection zone size (this Area2D's own collision shape,
	# used to know when the player is close enough to interact).
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = detection_size

	label.text = popup_text
	label.hide()  # hidden until the player enters range

	# Look for a Sprite2D on the parent object first.
	target_sprite = get_parent().get_node_or_null("Sprite2D") as CanvasItem

	# If no Sprite2D was found, fall back to checking for an AnimatedSprite2D
	# instead (this is what your object uses).
	if target_sprite == null:
		target_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as CanvasItem

	# Apply the outline shader material to whichever sprite type was found.
	if target_sprite and target_sprite.material == null:
		target_sprite.material = ShaderMaterial.new()
		target_sprite.material.shader = load("res://shaders/Objects/outline.gdshader")

	# top_level = true makes this node ignore the parent's transform
	# completely (no inherited position, rotation, or scale/flip).
	label.top_level = true

	# Wait one frame so the Label's size is fully calculated based on its
	# text/font before we read label.size for centering.
	await get_tree().process_frame
	label.reset_size()

	_calculate_offset()

func _process(_delta: float) -> void:
	# Every frame, manually place the label at the object's current
	# global position plus our fixed offset, so it stays "above" the
	# object regardless of the object's rotation or flip.
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
	# effect on the sprite on or off. Works the same whether target_sprite
	# is a Sprite2D or AnimatedSprite2D, since both use "material" the same way.
	if target_sprite and target_sprite.material is ShaderMaterial:
		target_sprite.material.set_shader_parameter("enabled", value)

func _calculate_offset() -> void:
	var target := get_parent()
	var height := 0.0

	var col_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape and col_shape.shape:
		var shape := col_shape.shape
		if shape is RectangleShape2D:
			height = shape.size.y
		elif shape is CircleShape2D:
			height = shape.radius * 2
		elif shape is CapsuleShape2D:
			height = shape.height

	if height == 0.0:
		if target_sprite is Sprite2D and target_sprite.texture:
			height = target_sprite.texture.get_height() * target_sprite.scale.y

		elif target_sprite is AnimatedSprite2D:
			# Cast explicitly so the editor recognizes AnimatedSprite2D-specific
			# properties like sprite_frames and animation.
			var anim_sprite := target_sprite as AnimatedSprite2D

			var frames: SpriteFrames = anim_sprite.sprite_frames
			var anim: String = anim_sprite.animation
			if frames and frames.get_frame_count(anim) > 0:
				var tex: Texture2D = frames.get_frame_texture(anim, 0)
				if tex:
					height = tex.get_height() * anim_sprite.scale.y

	offset_from_target = Vector2(-label.size.x / 2, -(height / 2) - gap_above - label.size.y)

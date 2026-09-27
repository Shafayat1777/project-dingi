extends NinePatchRect

@onready var margin: MarginContainer = $MarginContainer

func _ready() -> void:
	margin.resized.connect(_fit_to_content)
	_fit_to_content()

func _fit_to_content() -> void:
	size = margin.size
	_center()

func _center() -> void:
	var vp_size = get_viewport_rect().size
	position = (vp_size - size) / 2

extends Node2D

@onready var new_game_button = %"New Game"
@onready var resume_button = %Resume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_game_button.visible = not PauseMenue.pause_menu
	resume_button.visible = PauseMenue.pause_menu




func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Map/level_1.tscn")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Map/level_1.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
	

func _on_resume_pressed() -> void:
	PauseMenue.close_menu()

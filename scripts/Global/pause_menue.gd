extends Node

const MAIN_MENU = preload("res://scenes/Global/main_menue.tscn")

var menu_instance: Node = null
var pause_menu: bool = false
var full_screen: bool = false
var skip_tutorials: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while paused

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if menu_instance:
			close_menu()
		else:
			open_menu()

func open_menu():
	pause_menu = true
	menu_instance = MAIN_MENU.instantiate()
	menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(menu_instance)
	get_tree().paused = true


func close_menu():
	pause_menu = false
	menu_instance.queue_free()
	menu_instance = null
	get_tree().paused = false

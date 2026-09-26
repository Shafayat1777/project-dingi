extends CanvasLayer

@onready var dock_menu: PanelContainer = $DockMenu
@onready var shop: PanelContainer = $Shop
@onready var quests: PanelContainer = $Quests
@onready var workshop: PanelContainer = $Workshop
@onready var back_button: Button = $BackButton

func _ready() -> void:
	dock_menu.hide()
	shop.hide()
	quests.hide()
	workshop.hide()
	back_button.hide()

func _on_button_pressed() -> void:
	dock_menu.hide()
	shop.show()
	quests.hide()
	workshop.hide()
	back_button.show()

func _on_button_2_pressed() -> void:
	dock_menu.hide()
	shop.hide()
	quests.show()
	workshop.hide()
	back_button.show()

func _on_button_3_pressed() -> void:
	dock_menu.hide()
	shop.hide()
	quests.hide()
	workshop.show()
	back_button.show()

func _on_button_4_pressed() -> void:
	if visible:
		dock_menu.hide()
		shop.hide()
		quests.hide()
		workshop.hide()
		back_button.hide()
		hide()
		get_tree().paused = false
		get_viewport().set_input_as_handled()


func _on_back_button_pressed() -> void:
	dock_menu.show()
	shop.hide()
	quests.hide()
	workshop.hide()

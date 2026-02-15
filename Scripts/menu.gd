extends Control

@onready var game_list: ItemList = $MarginContainer/VBoxContainer/GameList

func _ready() -> void:
	game_list.clear()
	game_list.add_item("Pong")
	game_list.select(0)
	game_list.item_activated.connect(_on_game_activated)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_selected_game()

func _on_play_button_pressed() -> void:
	_start_selected_game()

func _on_game_activated(_index: int) -> void:
	_start_selected_game()

func _start_selected_game() -> void:
	var selected := game_list.get_selected_items()
	if selected.is_empty():
		return

	if game_list.get_item_text(selected[0]) == "Pong":
		get_tree().change_scene_to_file("res://Scenes/Main.tscn")

extends Control

@onready var game_list: ItemList = $MarginContainer/VBoxContainer/GameList

const GAMES := [
	{"name": "Pong", "scene": "res://Scenes/Main.tscn"},
	{"name": "Snake", "scene": "res://Scenes/Snake.tscn"},
	{"name": "Labirinto", "scene": "res://Scenes/Maze.tscn"},
	{"name": "Rogue Like Arena", "scene": "res://Scenes/RogueLike.tscn"},
	{"name": "Desvio", "scene": "res://Scenes/Dodger.tscn"},
	{"name": "Crônicas do Quadrado", "scene": "res://Scenes/Story.tscn"}
]

func _ready() -> void:
	game_list.clear()
	for game in GAMES:
		game_list.add_item(game["name"])
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

	var selected_name := game_list.get_item_text(selected[0])
	for game in GAMES:
		if game["name"] == selected_name:
			get_tree().change_scene_to_file(game["scene"])
			return

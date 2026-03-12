extends Control

@onready var background: ColorRect = $Background
@onready var blob_left: ColorRect = $BlobLeft
@onready var blob_right: ColorRect = $BlobRight
@onready var menu_panel: PanelContainer = $MarginContainer/MenuPanel
@onready var title_label: Label = $MarginContainer/MenuPanel/VBoxContainer/Title
@onready var subtitle_label: Label = $MarginContainer/MenuPanel/VBoxContainer/Subtitle
@onready var game_list: ItemList = $MarginContainer/MenuPanel/VBoxContainer/GameList
@onready var play_button: Button = $MarginContainer/MenuPanel/VBoxContainer/PlayButton
@onready var hint_label: Label = $MarginContainer/MenuPanel/VBoxContainer/Hint

var _time := 0.0

const GAMES := [
	{"name": "Pong", "scene": "res://Scenes/Main.tscn"},
	{"name": "Snake", "scene": "res://Scenes/Snake.tscn"},
	{"name": "Snake Multiplayer", "scene": "res://Scenes/SnakeMultiplayer.tscn"},
	{"name": "Labirinto", "scene": "res://Scenes/Maze.tscn"},
	{"name": "Rogue Like Arena", "scene": "res://Scenes/RogueLike.tscn"},
	{"name": "Desvio", "scene": "res://Scenes/Dodger.tscn"},
	{"name": "Crônicas do Quadrado", "scene": "res://Scenes/Story.tscn"},
	{"name": "Lendas de Avelorn (RPG)", "scene": "res://Scenes/RPGDecision.tscn"},
	{"name": "Terraria Lite", "scene": "res://Scenes/BlockWorld.tscn"},
	{"name": "Ecos Quânticos", "scene": "res://Scenes/QuantumEcho.tscn"},
	{"name": "Beat Grid (Guitar Hero)", "scene": "res://Scenes/GuitarHero.tscn"},
	{"name": "Sky Raid 3D", "scene": "res://Scenes/AirStrike3D.tscn"},
	{"name": "Ficha D&D 5e", "scene": "res://Scenes/DndSheetManager.tscn"},
	{"name": "Correio Orbital", "scene": "res://Scenes/OrbitalCourier.tscn"}
]

func _ready() -> void:
	_apply_visual_style()
	_populate_game_list()
	_animate_entrance()
	game_list.item_activated.connect(_on_game_activated)

func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 1.8)
	background.color = Color.from_hsv(0.6 + 0.06 * sin(_time * 0.25), 0.48, 0.14 + pulse * 0.08)

	blob_left.position = Vector2(-120 + sin(_time * 1.1) * 30.0, 80 + cos(_time * 0.8) * 26.0)
	blob_right.position = Vector2(size.x - 240 + cos(_time * 0.9) * 34.0, size.y - 260 + sin(_time * 1.2) * 24.0)

	title_label.modulate = Color.from_hsv(0.52 + 0.04 * sin(_time * 0.7), 0.3, 1.0)
	title_label.scale = Vector2.ONE * (1.0 + 0.025 * sin(_time * 2.8))
	play_button.modulate = Color(1.0, 1.0, 1.0, 0.88 + 0.12 * sin(_time * 3.8))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_selected_game()

func _on_play_button_pressed() -> void:
	_start_selected_game()

func _on_game_activated(_index: int) -> void:
	_start_selected_game()

func _populate_game_list() -> void:
	game_list.clear()
	for game in GAMES:
		game_list.add_item("🎮  %s" % game["name"])
	game_list.select(0)

func _apply_visual_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.18, 0.84)
	panel_style.corner_radius_top_left = 22
	panel_style.corner_radius_top_right = 22
	panel_style.corner_radius_bottom_right = 22
	panel_style.corner_radius_bottom_left = 22
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.41, 0.77, 1.0, 0.75)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 12
	menu_panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.71, 0.86, 1.0))
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.9))

	game_list.add_theme_font_size_override("font_size", 20)
	game_list.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	game_list.add_theme_color_override("font_selected_color", Color(0.08, 0.15, 0.24))
	game_list.add_theme_color_override("selection_color", Color(0.41, 0.92, 1.0, 0.95))
	game_list.add_theme_color_override("guide_color", Color(0.41, 0.92, 1.0, 0.2))

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.29, 0.76, 1.0)
	button_normal.corner_radius_top_left = 12
	button_normal.corner_radius_top_right = 12
	button_normal.corner_radius_bottom_right = 12
	button_normal.corner_radius_bottom_left = 12
	button_normal.shadow_color = Color(0.05, 0.2, 0.32, 0.45)
	button_normal.shadow_size = 6
	button_normal.content_margin_left = 16
	button_normal.content_margin_right = 16
	button_normal.content_margin_top = 8
	button_normal.content_margin_bottom = 8

	var button_hover := button_normal.duplicate()
	button_hover.bg_color = Color(0.46, 0.86, 1.0)

	var button_pressed := button_normal.duplicate()
	button_pressed.bg_color = Color(0.2, 0.62, 0.88)

	play_button.add_theme_stylebox_override("normal", button_normal)
	play_button.add_theme_stylebox_override("hover", button_hover)
	play_button.add_theme_stylebox_override("pressed", button_pressed)
	play_button.add_theme_color_override("font_color", Color(0.04, 0.11, 0.2))
	play_button.add_theme_font_size_override("font_size", 22)
	play_button.text = "✨ Jogar Agora"

func _animate_entrance() -> void:
	menu_panel.modulate = Color(1, 1, 1, 0)
	menu_panel.position.y += 22
	var tween := create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "position:y", menu_panel.position.y - 22, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _start_selected_game() -> void:
	var selected := game_list.get_selected_items()
	if selected.is_empty():
		return

	var selected_name := game_list.get_item_text(selected[0]).replace("🎮  ", "")
	for game in GAMES:
		if game["name"] == selected_name:
			var change_error := get_tree().change_scene_to_file(game["scene"])
			if change_error != OK:
				push_error("Falha ao abrir cena %s (erro %d)" % [game["scene"], change_error])
			return

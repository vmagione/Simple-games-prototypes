extends Node2D

@onready var background: ColorRect = $CanvasLayer/Background
@onready var title_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/Title
@onready var story_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/StoryText
@onready var choice_a_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Choices/ChoiceA
@onready var choice_b_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Choices/ChoiceB
@onready var hint_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/Hint
@onready var hero_sprite: Sprite2D = $Hero

var _chapter_id := "intro"

const CHAPTERS := {
	"intro": {
		"title": "Crônicas do Quadrado",
		"text": "Numa vila de pixels, um pequeno quadrado encontra um mapa antigo.\n\nDiz a lenda que a Luz da Aurora salva a vila da escuridão.",
		"choices": [
			{"text": "Seguir para a floresta", "next": "forest"},
			{"text": "Descer para as cavernas", "next": "cave"}
		],
		"color": Color(0.08, 0.12, 0.2, 1.0)
	},
	"forest": {
		"title": "A Floresta Sussurrante",
		"text": "As árvores brilham em tons verdes. Um círculo viajante oferece ajuda para atravessar um rio perigoso.",
		"choices": [
			{"text": "Aceitar ajuda do círculo", "next": "good_ending"},
			{"text": "Ir sozinho pela ponte velha", "next": "bad_ending"}
		],
		"color": Color(0.06, 0.19, 0.12, 1.0)
	},
	"cave": {
		"title": "As Cavernas Ecoantes",
		"text": "No escuro, o quadrado encontra cristais azuis. Eles podem iluminar o caminho, mas também atrair sombras.",
		"choices": [
			{"text": "Levar os cristais", "next": "bad_ending"},
			{"text": "Deixar os cristais e seguir em silêncio", "next": "good_ending"}
		],
		"color": Color(0.07, 0.08, 0.16, 1.0)
	},
	"good_ending": {
		"title": "Final: A Aurora",
		"text": "Ao amanhecer, o quadrado entrega a Luz da Aurora na vila.\n\nAs ruas voltam a brilhar, e a coragem vira história para novas gerações.",
		"choices": [],
		"color": Color(0.22, 0.2, 0.08, 1.0)
	},
	"bad_ending": {
		"title": "Final: A Névoa",
		"text": "A névoa cobre os caminhos e o quadrado se perde por um tempo.\n\nMas toda queda ensina: talvez amanhã seja dia de tentar de novo.",
		"choices": [],
		"color": Color(0.14, 0.08, 0.08, 1.0)
	}
}

func _ready() -> void:
	hero_sprite.texture = preload("res://Assets/Sprites/Square.png")
	hero_sprite.scale = Vector2(3.2, 3.2)
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)
	_show_chapter(_chapter_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if event.is_action_pressed("ui_accept") and _is_current_chapter_final():
		_chapter_id = "intro"
		_show_chapter(_chapter_id)

func _on_choice_a_pressed() -> void:
	_goto_choice(0)

func _on_choice_b_pressed() -> void:
	_goto_choice(1)

func _goto_choice(index: int) -> void:
	var chapter: Dictionary = CHAPTERS[_chapter_id]
	var choices: Array = chapter["choices"]
	if index >= choices.size():
		return

	_chapter_id = choices[index]["next"]
	_show_chapter(_chapter_id)

func _show_chapter(chapter_id: String) -> void:
	var chapter: Dictionary = CHAPTERS[chapter_id]
	var choices: Array = chapter["choices"]

	title_label.text = chapter["title"]
	story_label.text = chapter["text"]
	background.color = chapter["color"]

	choice_a_button.visible = choices.size() > 0
	choice_b_button.visible = choices.size() > 1

	if choices.size() > 0:
		choice_a_button.text = "1) %s" % choices[0]["text"]
		choice_b_button.text = "2) %s" % choices[1]["text"]
		hint_label.text = "Escolha um caminho | ESC volta ao menu"
	else:
		hint_label.text = "Pressione Enter para recomeçar | ESC volta ao menu"

func _is_current_chapter_final() -> bool:
	var chapter: Dictionary = CHAPTERS[_chapter_id]
	var choices: Array = chapter["choices"]
	return choices.is_empty()

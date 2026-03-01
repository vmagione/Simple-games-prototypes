extends Control

const SAVE_PATH := "user://dnd_character_sheets.json"

const RACES := [
	"Humano",
	"Anão",
	"Elfo",
	"Halfling",
	"Draconato",
	"Gnomo",
	"Meio-Elfo",
	"Meio-Orc",
	"Tiefling"
]

const CLASSES := [
	"Bárbaro",
	"Bardo",
	"Bruxo",
	"Clérigo",
	"Druida",
	"Feiticeiro",
	"Guerreiro",
	"Ladino",
	"Mago",
	"Monge",
	"Paladino",
	"Patrulheiro"
]

const BACKGROUNDS := [
	"Acólito",
	"Artesão de Guilda",
	"Charlatão",
	"Criminoso",
	"Eremita",
	"Forasteiro",
	"Herói do Povo",
	"Nobre",
	"Sábio",
	"Soldado"
]

const ALIGNMENTS := [
	"Leal e Bom",
	"Neutro e Bom",
	"Caótico e Bom",
	"Leal e Neutro",
	"Neutro",
	"Caótico e Neutro",
	"Leal e Mau",
	"Neutro e Mau",
	"Caótico e Mau"
]

@onready var list_panel: VBoxContainer = $MarginContainer/ListPanel
@onready var sheet_list: ItemList = $MarginContainer/ListPanel/SheetList
@onready var empty_label: Label = $MarginContainer/ListPanel/EmptyLabel

@onready var editor_panel: VBoxContainer = $MarginContainer/EditorPanel
@onready var panel_title: Label = $MarginContainer/EditorPanel/Header/PanelTitle
@onready var id_label: Label = $MarginContainer/EditorPanel/Header/IdLabel

@onready var character_name_edit: LineEdit = $MarginContainer/EditorPanel/FormGrid/CharacterNameEdit
@onready var player_name_edit: LineEdit = $MarginContainer/EditorPanel/FormGrid/PlayerNameEdit
@onready var level_spin: SpinBox = $MarginContainer/EditorPanel/FormGrid/LevelSpin
@onready var race_option: OptionButton = $MarginContainer/EditorPanel/FormGrid/RaceOption
@onready var class_option: OptionButton = $MarginContainer/EditorPanel/FormGrid/ClassOption
@onready var background_option: OptionButton = $MarginContainer/EditorPanel/FormGrid/BackgroundOption
@onready var alignment_option: OptionButton = $MarginContainer/EditorPanel/FormGrid/AlignmentOption

@onready var strength_edit: LineEdit = $MarginContainer/EditorPanel/AbilitiesGrid/StrengthEdit
@onready var dexterity_edit: LineEdit = $MarginContainer/EditorPanel/AbilitiesGrid/DexterityEdit
@onready var constitution_edit: LineEdit = $MarginContainer/EditorPanel/AbilitiesGrid/ConstitutionEdit
@onready var intelligence_edit: LineEdit = $MarginContainer/EditorPanel/AbilitiesGrid/IntelligenceEdit
@onready var wisdom_edit: LineEdit = $MarginContainer/EditorPanel/AbilitiesGrid/WisdomEdit
@onready var charisma_edit: LineEdit = $MarginContainer/EditorPanel/AbilitiesGrid/CharismaEdit

@onready var notes_edit: TextEdit = $MarginContainer/EditorPanel/NotesEdit
@onready var save_button: Button = $MarginContainer/EditorPanel/ButtonsRow/SaveButton
@onready var delete_button: Button = $MarginContainer/EditorPanel/ButtonsRow/DeleteButton
@onready var cancel_button: Button = $MarginContainer/EditorPanel/ButtonsRow/CancelButton

var _sheets: Array[Dictionary] = []
var _selected_sheet_index := -1

func _ready() -> void:
	_setup_option_buttons()
	_load_sheets()
	_refresh_sheet_list()
	_show_list_panel()

	sheet_list.item_activated.connect(_on_sheet_selected)
	save_button.pressed.connect(_on_save_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _setup_option_buttons() -> void:
	_fill_option_button(race_option, RACES)
	_fill_option_button(class_option, CLASSES)
	_fill_option_button(background_option, BACKGROUNDS)
	_fill_option_button(alignment_option, ALIGNMENTS)

func _fill_option_button(option_button: OptionButton, values: Array) -> void:
	option_button.clear()
	for value in values:
		option_button.add_item(value)
	option_button.select(0)

func _on_new_sheet_button_pressed() -> void:
	_selected_sheet_index = -1
	_clear_editor()
	_show_editor_panel("Nova Ficha")

func _on_edit_button_pressed() -> void:
	_open_selected_sheet()

func _on_sheet_selected(index: int) -> void:
	_open_sheet(index)

func _on_save_button_pressed() -> void:
	var sheet := _collect_sheet_data()
	if _selected_sheet_index >= 0:
		_sheets[_selected_sheet_index] = sheet
	else:
		_sheets.append(sheet)
		_selected_sheet_index = _sheets.size() - 1

	_save_sheets()
	_refresh_sheet_list()
	_show_list_panel()

func _on_delete_button_pressed() -> void:
	if _selected_sheet_index < 0:
		return

	_sheets.remove_at(_selected_sheet_index)
	_save_sheets()
	_refresh_sheet_list()
	_show_list_panel()

func _on_cancel_button_pressed() -> void:
	_show_list_panel()

func _open_selected_sheet() -> void:
	var selected := sheet_list.get_selected_items()
	if selected.is_empty():
		return
	_open_sheet(selected[0])

func _open_sheet(index: int) -> void:
	if index < 0 or index >= _sheets.size():
		return

	_selected_sheet_index = index
	_populate_editor(_sheets[index])
	_show_editor_panel("Editar Ficha")

func _show_list_panel() -> void:
	list_panel.visible = true
	editor_panel.visible = false

func _show_editor_panel(title: String) -> void:
	list_panel.visible = false
	editor_panel.visible = true
	panel_title.text = title
	if _selected_sheet_index >= 0:
		id_label.text = "Ficha #%d" % (_selected_sheet_index + 1)
		delete_button.disabled = false
	else:
		id_label.text = "Ficha nova"
		delete_button.disabled = true

func _refresh_sheet_list() -> void:
	sheet_list.clear()
	for i in _sheets.size():
		var sheet := _sheets[i]
		var character_name := String(sheet.get("character_name", "")).strip_edges()
		if character_name.is_empty():
			character_name = "Ficha sem nome"
		var class_name := String(sheet.get("class", ""))
		sheet_list.add_item("%d) %s - %s" % [i + 1, character_name, class_name])

	empty_label.visible = _sheets.is_empty()

func _clear_editor() -> void:
	character_name_edit.text = ""
	player_name_edit.text = ""
	level_spin.value = 1
	race_option.select(0)
	class_option.select(0)
	background_option.select(0)
	alignment_option.select(0)
	strength_edit.text = ""
	dexterity_edit.text = ""
	constitution_edit.text = ""
	intelligence_edit.text = ""
	wisdom_edit.text = ""
	charisma_edit.text = ""
	notes_edit.text = ""

func _populate_editor(sheet: Dictionary) -> void:
	character_name_edit.text = String(sheet.get("character_name", ""))
	player_name_edit.text = String(sheet.get("player_name", ""))
	level_spin.value = int(sheet.get("level", 1))
	_select_option_by_text(race_option, String(sheet.get("race", RACES[0])))
	_select_option_by_text(class_option, String(sheet.get("class", CLASSES[0])))
	_select_option_by_text(background_option, String(sheet.get("background", BACKGROUNDS[0])))
	_select_option_by_text(alignment_option, String(sheet.get("alignment", ALIGNMENTS[0])))
	strength_edit.text = String(sheet.get("strength", ""))
	dexterity_edit.text = String(sheet.get("dexterity", ""))
	constitution_edit.text = String(sheet.get("constitution", ""))
	intelligence_edit.text = String(sheet.get("intelligence", ""))
	wisdom_edit.text = String(sheet.get("wisdom", ""))
	charisma_edit.text = String(sheet.get("charisma", ""))
	notes_edit.text = String(sheet.get("notes", ""))

func _select_option_by_text(option_button: OptionButton, value: String) -> void:
	for i in option_button.item_count:
		if option_button.get_item_text(i) == value:
			option_button.select(i)
			return
	option_button.select(0)

func _collect_sheet_data() -> Dictionary:
	return {
		"character_name": character_name_edit.text,
		"player_name": player_name_edit.text,
		"level": int(level_spin.value),
		"race": race_option.get_item_text(race_option.selected),
		"class": class_option.get_item_text(class_option.selected),
		"background": background_option.get_item_text(background_option.selected),
		"alignment": alignment_option.get_item_text(alignment_option.selected),
		"strength": strength_edit.text,
		"dexterity": dexterity_edit.text,
		"constitution": constitution_edit.text,
		"intelligence": intelligence_edit.text,
		"wisdom": wisdom_edit.text,
		"charisma": charisma_edit.text,
		"notes": notes_edit.text
	}

func _load_sheets() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_sheets = []
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Não foi possível abrir o arquivo de fichas.")
		_sheets = []
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_sheets.clear()
		for entry in parsed:
			if entry is Dictionary:
				_sheets.append(entry)
	else:
		_sheets = []

func _save_sheets() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar as fichas.")
		return
	file.store_string(JSON.stringify(_sheets, "\t"))

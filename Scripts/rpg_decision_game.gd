extends Node2D

@onready var background: ColorRect = $CanvasLayer/Background
@onready var title_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/Title
@onready var story_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/StoryText
@onready var status_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/Status
@onready var choices_container: VBoxContainer = $CanvasLayer/MarginContainer/VBoxContainer/Choices
@onready var hint_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/Hint

const MENU_SCENE := "res://Scenes/Menu.tscn"

const RACES := {
	"Humano": {"bonuses": {"STR": 1, "DEX": 1, "CON": 1, "INT": 1, "WIS": 1, "CHA": 1}, "feature": "Versátil"},
	"Elfo": {"bonuses": {"DEX": 2, "WIS": 1}, "feature": "Sentidos Aguçados"},
	"Anão": {"bonuses": {"CON": 2, "STR": 1}, "feature": "Resiliência Anã"},
	"Halfling": {"bonuses": {"DEX": 2, "CHA": 1}, "feature": "Sorte"}
}

const CLASSES := {
	"Guerreiro": {"main": "STR", "hp": 12, "skills": ["Atletismo", "Intimidação"]},
	"Ladino": {"main": "DEX", "hp": 9, "skills": ["Furtividade", "Enganação"]},
	"Mago": {"main": "INT", "hp": 7, "skills": ["Arcanismo", "História"]},
	"Clérigo": {"main": "WIS", "hp": 10, "skills": ["Religião", "Intuição"]}
}

const BASE_STATS := {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10}

const NODES := {
	"intro": {
		"title": "Crônicas de Avelorn",
		"text": "Você chega à fronteira de Avelorn, onde goblins e magia antiga ameaçam a estrada real. Primeiro, defina sua raça.",
		"type": "race",
		"color": Color(0.10, 0.08, 0.14, 1.0)
	},
	"class_select": {
		"title": "Escolha de Classe",
		"text": "Agora escolha sua classe, como nas regras base de D&D 5e.",
		"type": "class",
		"color": Color(0.10, 0.12, 0.18, 1.0)
	},
	"gate": {
		"title": "Cena 1: Portão de Ferro",
		"text": "Bandidos controlam o portão da cidade. Você precisa entrar antes do pôr do sol.",
		"type": "challenge",
		"color": Color(0.12, 0.09, 0.07, 1.0),
		"options": [
			{"text": "Arrombar o portão na força", "stat": "STR", "dc": 13, "success": "archives", "fail": "ambush"},
			{"text": "Escalar o muro em silêncio", "stat": "DEX", "dc": 13, "success": "archives", "fail": "ambush"},
			{"text": "Invocar distração arcana", "stat": "INT", "dc": 12, "success": "archives", "fail": "ambush", "class": "Mago"},
			{"text": "Pedir passagem em nome do templo", "stat": "CHA", "dc": 12, "success": "archives", "fail": "ambush", "class": "Clérigo"}
		]
	},
	"archives": {
		"title": "Cena 2: Arquivos Esquecidos",
		"text": "Dentro da cidade, um mapa antigo revela um selo demoníaco sob a torre do sino. Você precisa encontrar a chave ritual.",
		"type": "challenge",
		"color": Color(0.06, 0.13, 0.15, 1.0),
		"options": [
			{"text": "Investigar runas e padrões", "stat": "INT", "dc": 14, "success": "ritual", "fail": "tower_fall"},
			{"text": "Farejar armadilhas escondidas", "stat": "WIS", "dc": 13, "success": "ritual", "fail": "tower_fall", "race": "Elfo"},
			{"text": "Forçar passagens bloqueadas", "stat": "STR", "dc": 14, "success": "ritual", "fail": "tower_fall", "class": "Guerreiro"},
			{"text": "Desarmar fechadura com ferramentas", "stat": "DEX", "dc": 13, "success": "ritual", "fail": "tower_fall", "class": "Ladino"}
		]
	},
	"ambush": {
		"title": "Cena 2: Emboscada na Viela",
		"text": "Seu plano falha e guardas corruptos cercam você. Ainda há chance de virar o jogo.",
		"type": "challenge",
		"color": Color(0.17, 0.08, 0.08, 1.0),
		"options": [
			{"text": "Resistir firme sob pressão", "stat": "CON", "dc": 13, "success": "ritual", "fail": "bad_end"},
			{"text": "Blefar que trabalha para a coroa", "stat": "CHA", "dc": 14, "success": "ritual", "fail": "bad_end"},
			{"text": "Desaparecer nas sombras", "stat": "DEX", "dc": 14, "success": "ritual", "fail": "bad_end", "class": "Ladino"},
			{"text": "Convocar bênção de proteção", "stat": "WIS", "dc": 13, "success": "ritual", "fail": "bad_end", "class": "Clérigo"}
		]
	},
	"ritual": {
		"title": "Cena 3: Torre do Sino",
		"text": "No topo da torre, o selo começa a se romper. Uma decisão final definirá o destino de Avelorn.",
		"type": "challenge",
		"color": Color(0.12, 0.11, 0.03, 1.0),
		"options": [
			{"text": "Selar magia com precisão arcana", "stat": "INT", "dc": 15, "success": "hero_end", "fail": "mixed_end", "class": "Mago"},
			{"text": "Canalizar fé e coragem", "stat": "WIS", "dc": 15, "success": "hero_end", "fail": "mixed_end", "class": "Clérigo"},
			{"text": "Destruir o foco com um golpe", "stat": "STR", "dc": 15, "success": "hero_end", "fail": "mixed_end", "class": "Guerreiro"},
			{"text": "Sabotar o círculo em silêncio", "stat": "DEX", "dc": 15, "success": "hero_end", "fail": "mixed_end", "class": "Ladino"}
		]
	},
	"tower_fall": {
		"title": "Final: Queda da Torre",
		"text": "Sem a chave ritual, a torre desaba. Muitos sobrevivem, mas o selo permanece instável. Você ganha respeito por salvar civis no caos.",
		"type": "ending",
		"color": Color(0.18, 0.12, 0.06, 1.0)
	},
	"mixed_end": {
		"title": "Final: Vitória com Cicatrizes",
		"text": "O selo é parcialmente contido. A cidade vive, mas parte da torre vira ruína. Sua jornada continua em busca de uma solução definitiva.",
		"type": "ending",
		"color": Color(0.16, 0.16, 0.07, 1.0)
	},
	"hero_end": {
		"title": "Final: Guardião de Avelorn",
		"text": "Com estratégia e coragem, você sela a fenda demoníaca. Seu nome entra para as lendas do reino.",
		"type": "ending",
		"color": Color(0.13, 0.18, 0.10, 1.0)
	},
	"bad_end": {
		"title": "Final: Fuga na Noite",
		"text": "Sem recursos, você recua para lutar outro dia. Avelorn cai em mãos sombrias, mas sua história ainda não termina.",
		"type": "ending",
		"color": Color(0.14, 0.05, 0.05, 1.0)
	}
}

var _current_node := "intro"
var _race := ""
var _class := ""
var _stats := {}
var _last_roll_text := ""

func _ready() -> void:
	_reset_campaign()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)
		return

	if event.is_action_pressed("ui_accept") and _is_ending():
		_reset_campaign()

func _reset_campaign() -> void:
	_race = ""
	_class = ""
	_stats = BASE_STATS.duplicate(true)
	_last_roll_text = ""
	_current_node = "intro"
	_refresh_ui()

func _refresh_ui() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	var node: Dictionary = NODES[_current_node]
	title_label.text = node["title"]
	story_label.text = node["text"]
	background.color = node["color"]

	match node["type"]:
		"race":
			_add_race_buttons()
			hint_label.text = "Escolha sua raça | ESC volta ao menu"
		"class":
			_add_class_buttons()
			hint_label.text = "Escolha sua classe | ESC volta ao menu"
		"challenge":
			_add_challenge_buttons(node["options"])
			hint_label.text = "Escolha uma ação e role o d20 | ESC volta ao menu"
		"ending":
			_add_restart_button()
			hint_label.text = "Enter ou botão para reiniciar | ESC volta ao menu"

	status_label.text = _build_status_text()

func _add_race_buttons() -> void:
	for race_name in RACES.keys():
		var race_data: Dictionary = RACES[race_name]
		var bonus_text := _format_bonus_text(race_data["bonuses"])
		var button := _create_button("%s (%s)" % [race_name, bonus_text])
		button.pressed.connect(func() -> void:
			_select_race(race_name)
		)

func _add_class_buttons() -> void:
	for class_name_aux in CLASSES.keys():
		var _class_name: Dictionary = CLASSES[class_name_aux]
		var button := _create_button("%s (Atributo principal: %s)" % [_class_name, class_name_aux["main"]])
		button.pressed.connect(func() -> void:
			_select_class(class_name_aux)
		)

func _add_challenge_buttons(options: Array) -> void:
	var available := 0
	for option in options:
		if not _is_option_available(option):
			continue
		available += 1
		var mod := _get_modifier(option["stat"])
		var chance := _success_chance_percent(option["dc"], mod)
		var text := "%s [%s %+d vs DC %d | %d%%]" % [option["text"], option["stat"], mod, option["dc"], chance]
		var button := _create_button(text)
		button.pressed.connect(func() -> void:
			_resolve_option(option)
		)

	if available == 0:
		var fallback := _create_button("Sem ações disponíveis (reiniciar)")
		fallback.pressed.connect(_reset_campaign)

func _add_restart_button() -> void:
	var button := _create_button("Recomeçar campanha")
	button.pressed.connect(_reset_campaign)

func _create_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices_container.add_child(button)
	return button

func _select_race(race_name: String) -> void:
	_race = race_name
	_stats = BASE_STATS.duplicate(true)
	var bonuses: Dictionary = RACES[race_name]["bonuses"]
	for key in bonuses.keys():
		_stats[key] += bonuses[key]
	_current_node = "class_select"
	_refresh_ui()

func _select_class(_class_name: String) -> void:
	_class = _class_name
	_stats[CLASSES[_class_name]["main"]] += 1
	_stats["CON"] += 1
	_current_node = "gate"
	_refresh_ui()

func _resolve_option(option: Dictionary) -> void:
	var stat: String = option["stat"]
	var dc: int = option["dc"]
	var roll := randi_range(1, 20)
	var mod := _get_modifier(stat)
	var total := roll + mod
	if total >= dc:
		_current_node = option["success"]
		_last_roll_text = "Sucesso: d20(%d) %+d = %d contra DC %d." % [roll, mod, total, dc]
	else:
		_current_node = option["fail"]
		_last_roll_text = "Falha: d20(%d) %+d = %d contra DC %d." % [roll, mod, total, dc]
	_refresh_ui()

func _is_option_available(option: Dictionary) -> bool:
	if option.has("class") and option["class"] != _class:
		return false
	if option.has("race") and option["race"] != _race:
		return false
	return true

func _build_status_text() -> String:
	var race_text := _race if _race != "" else "-"
	var class_text := _class if _class != "" else "-"
	var hp := 0
	if _class != "":
		hp = CLASSES[_class]["hp"] + _get_modifier("CON")
	var header := "Raça: %s | Classe: %s | HP: %d" % [race_text, class_text, hp]
	var attr_text := ""
	for key in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		attr_text += "%s %d (%+d)  " % [key, _stats[key], _get_modifier(key)]

	if _last_roll_text == "":
		return "%s\n%s" % [header, attr_text.strip_edges()]
	return "%s\n%s\n%s" % [header, attr_text.strip_edges(), _last_roll_text]

func _format_bonus_text(bonuses: Dictionary) -> String:
	var parts: Array[String] = []
	for key in bonuses.keys():
		parts.append("%s %+d" % [key, bonuses[key]])
	return ", ".join(parts)

func _get_modifier(stat: String) -> int:
	return int(floor((float(_stats[stat]) - 10.0) / 2.0))

func _success_chance_percent(dc: int, mod: int) -> int:
	var success_count := 0
	for roll in range(1, 21):
		if roll + mod >= dc:
			success_count += 1
	return int(round((float(success_count) / 20.0) * 100.0))

func _is_ending() -> bool:
	return NODES[_current_node]["type"] == "ending"

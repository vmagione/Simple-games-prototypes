extends Node2D

const ARENA_MIN := Vector2(64, 96)
const ARENA_MAX := Vector2(1088, 656)
const PLAYER_SPEED := 320.0
const ECHO_DELAY := 0.35
const PAIR_LIFETIME := 6.0

@onready var player: Sprite2D = $Player
@onready var echo: Sprite2D = $Echo
@onready var notes_container: Node2D = $Notes
@onready var hud_label: Label = $CanvasLayer/HUD

var _circle_texture: Texture2D
var _square_texture: Texture2D
var _history: Array = []
var _pair_id := 0
var _score := 0
var _stability := 5
var _spawn_interval := 2.2
var _spawn_elapsed := 0.0
var _is_game_over := false

func _ready() -> void:
	_circle_texture = preload("res://Assets/Sprites/Circle.png")
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_randomize_seed()
	_reset_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _is_game_over and event.is_action_pressed("ui_accept"):
		_reset_game()

func _process(delta: float) -> void:
	if _is_game_over:
		return

	_move_player(delta)
	_update_echo(delta)
	_spawn_elapsed += delta
	if _spawn_elapsed >= _spawn_interval:
		_spawn_elapsed = 0.0
		_spawn_note_pair()

	_update_note_pairs(delta)
	_check_collections()
	_update_hud()

func _move_player(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.position += direction * PLAYER_SPEED * delta
	player.position.x = clamp(player.position.x, ARENA_MIN.x, ARENA_MAX.x)
	player.position.y = clamp(player.position.y, ARENA_MIN.y, ARENA_MAX.y)

	_history.append({"time": Time.get_ticks_msec() / 1000.0, "pos": player.position})

func _update_echo(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var target_time := now - ECHO_DELAY
	while _history.size() > 2 and _history[1]["time"] <= target_time:
		_history.pop_front()

	if _history.is_empty():
		return

	var delayed_position: Vector2 = _history[0]["pos"]
	echo.position = Vector2(1152.0 - delayed_position.x, delayed_position.y)
	echo.position.x = clamp(echo.position.x, ARENA_MIN.x, ARENA_MAX.x)
	echo.position.y = clamp(echo.position.y, ARENA_MIN.y, ARENA_MAX.y)

func _spawn_note_pair() -> void:
	_pair_id += 1
	var y := randf_range(ARENA_MIN.y + 20.0, ARENA_MAX.y - 20.0)
	var left_x := randf_range(ARENA_MIN.x + 20.0, 512.0)
	var right_x := 1152.0 - left_x

	var left_note := _create_note(Vector2(left_x, y), Color(0.35, 0.95, 1.0), "player", _pair_id)
	var right_note := _create_note(Vector2(right_x, y), Color(1.0, 0.55, 0.95), "echo", _pair_id)
	notes_container.add_child(left_note)
	notes_container.add_child(right_note)

func _create_note(position: Vector2, color: Color, owner: String, pair_id: int) -> Sprite2D:
	var note := Sprite2D.new()
	note.texture = _circle_texture
	note.scale = Vector2(0.18, 0.18)
	note.modulate = color
	note.position = position
	note.set_meta("owner", owner)
	note.set_meta("pair_id", pair_id)
	note.set_meta("remaining", PAIR_LIFETIME)
	note.set_meta("collected", false)
	return note

func _update_note_pairs(delta: float) -> void:
	var timed_out_pairs: Array[int] = []
	for note in notes_container.get_children():
		if note.get_meta("collected"):
			continue

		var remaining: float = note.get_meta("remaining")
		remaining -= delta
		note.set_meta("remaining", remaining)
		var pulse := 0.65 + (sin(remaining * 8.0) + 1.0) * 0.15
		note.scale = Vector2(0.18, 0.18) * pulse
		if remaining <= 0.0:
			timed_out_pairs.append(note.get_meta("pair_id"))

	for pair in timed_out_pairs:
		_fail_pair(pair)

func _check_collections() -> void:
	for note in notes_container.get_children():
		if note.get_meta("collected"):
			continue

		var owner: String = note.get_meta("owner")
		var collector := player if owner == "player" else echo
		if collector.position.distance_to(note.position) <= 28.0:
			note.set_meta("collected", true)
			note.visible = false
			_resolve_pair_if_completed(note.get_meta("pair_id"))

func _resolve_pair_if_completed(pair: int) -> void:
	var has_player := false
	var has_echo := false
	for note in notes_container.get_children():
		if note.get_meta("pair_id") != pair:
			continue
		if not note.get_meta("collected"):
			return
		if note.get_meta("owner") == "player":
			has_player = true
		else:
			has_echo = true

	if has_player and has_echo:
		_score += 3
		_spawn_interval = max(0.95, _spawn_interval - 0.04)
		_clear_pair(pair)

func _fail_pair(pair: int) -> void:
	var found := false
	for note in notes_container.get_children():
		if note.get_meta("pair_id") == pair:
			found = true
			break

	if not found:
		return

	_stability -= 1
	_clear_pair(pair)
	if _stability <= 0:
		_is_game_over = true

func _clear_pair(pair: int) -> void:
	for note in notes_container.get_children():
		if note.get_meta("pair_id") == pair:
			note.queue_free()

func _reset_game() -> void:
	for note in notes_container.get_children():
		note.queue_free()

	_history.clear()
	_pair_id = 0
	_score = 0
	_stability = 5
	_spawn_interval = 2.2
	_spawn_elapsed = 0.0
	_is_game_over = false

	player.texture = _square_texture
	player.modulate = Color(0.4, 1.0, 0.5)
	player.scale = Vector2(0.75, 0.75)
	player.position = Vector2(320, 360)

	echo.texture = _square_texture
	echo.modulate = Color(1.0, 0.45, 0.85)
	echo.scale = Vector2(0.75, 0.75)
	echo.position = Vector2(832, 360)

	_spawn_note_pair()
	_update_hud()

func _update_hud() -> void:
	if _is_game_over:
		hud_label.text = "Ecos Quânticos | Pontos: %d | Fim! Enter reinicia | ESC menu" % _score
		return

	hud_label.text = "Ecos Quânticos | Pontos: %d | Estabilidade: %d | Colete pares em sincronia" % [_score, _stability]

func _draw() -> void:
	draw_rect(Rect2(ARENA_MIN, ARENA_MAX - ARENA_MIN), Color(0.05, 0.05, 0.11, 1.0), true)
	draw_line(Vector2(576, ARENA_MIN.y), Vector2(576, ARENA_MAX.y), Color(0.3, 0.3, 0.55, 1.0), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(452, 74), "LADO DO JOGADOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 1.0, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(650, 74), "ECO TEMPORAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.65, 0.9))

func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

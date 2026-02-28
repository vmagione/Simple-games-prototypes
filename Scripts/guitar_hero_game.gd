extends Node2D

const LANE_ACTIONS := [&"guitar_lane_a", &"guitar_lane_s", &"guitar_lane_d", &"guitar_lane_f"]
const LANE_COLORS := [
	Color(0.3, 0.8, 1.0, 1.0),
	Color(0.45, 1.0, 0.45, 1.0),
	Color(1.0, 0.95, 0.4, 1.0),
	Color(1.0, 0.45, 0.55, 1.0)
]
const NOTE_SPEED_BASE := 300.0
const NOTE_SPEED_STEP := 20.0
const NOTE_HIT_WINDOW := 32.0
const NOTE_MISS_MARGIN := 48.0

@onready var lanes_container: Node2D = $Lanes
@onready var notes_container: Node2D = $Notes
@onready var hit_line: Node2D = $HitLine
@onready var spawn_timer: Timer = $SpawnTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _square_texture: Texture2D
var _lane_x_positions: Array[float] = []
var _score := 0
var _combo := 0
var _hits := 0
var _misses := 0
var _note_speed := NOTE_SPEED_BASE

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_randomize_seed()
	_setup_lanes()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_reset_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	for lane_index in LANE_ACTIONS.size():
		if event.is_action_pressed(LANE_ACTIONS[lane_index]):
			_try_hit_lane(lane_index)
			return

func _process(delta: float) -> void:
	_move_notes(delta)
	_check_missed_notes()
	_update_label()

func _setup_lanes() -> void:
	for child in lanes_container.get_children():
		child.queue_free()

	_lane_x_positions.clear()
	var first_x := 432.0
	var lane_spacing := 96.0
	for lane_index in LANE_ACTIONS.size():
		var lane_x := first_x + lane_index * lane_spacing
		_lane_x_positions.append(lane_x)

		var lane_sprite := Sprite2D.new()
		lane_sprite.texture = _square_texture
		lane_sprite.modulate = LANE_COLORS[lane_index].darkened(0.55)
		lane_sprite.scale = Vector2(1.2, 18.0)
		lane_sprite.position = Vector2(lane_x, 336.0)
		lanes_container.add_child(lane_sprite)

func _reset_game() -> void:
	_score = 0
	_combo = 0
	_hits = 0
	_misses = 0
	_note_speed = NOTE_SPEED_BASE

	for child in notes_container.get_children():
		child.queue_free()

	spawn_timer.wait_time = 0.55
	spawn_timer.start()
	_update_label()

func _on_spawn_timer_timeout() -> void:
	_spawn_note(randi_range(0, LANE_ACTIONS.size() - 1))
	_note_speed = min(_note_speed + NOTE_SPEED_STEP, 520.0)
	spawn_timer.wait_time = max(0.24, spawn_timer.wait_time - 0.008)

func _spawn_note(lane_index: int) -> void:
	var note := Sprite2D.new()
	note.texture = _square_texture
	note.modulate = LANE_COLORS[lane_index]
	note.scale = Vector2(1.05, 1.05)
	note.position = Vector2(_lane_x_positions[lane_index], 72.0)
	note.set_meta("lane", lane_index)
	notes_container.add_child(note)

func _move_notes(delta: float) -> void:
	for note in notes_container.get_children():
		note.position.y += _note_speed * delta

func _check_missed_notes() -> void:
	var hit_line_y := hit_line.position.y
	for note in notes_container.get_children():
		if note.position.y > hit_line_y + NOTE_MISS_MARGIN:
			_miss_note(note)

func _try_hit_lane(lane_index: int) -> void:
	var hit_line_y := hit_line.position.y
	var best_note: Sprite2D = null
	var best_distance := INF

	for note in notes_container.get_children():
		if note.get_meta("lane") != lane_index:
			continue

		var distance = abs(note.position.y - hit_line_y)
		if distance < best_distance:
			best_distance = distance
			best_note = note

	if best_note != null and best_distance <= NOTE_HIT_WINDOW:
		var points = 100 + min(_combo, 20) * 10
		_score += points
		_hits += 1
		_combo += 1
		best_note.queue_free()
	else:
		_combo = 0
		_misses += 1

func _miss_note(note: Sprite2D) -> void:
	if not is_instance_valid(note):
		return
	_combo = 0
	_misses += 1
	note.queue_free()

func _update_label() -> void:
	info_label.text = "Beat Grid | Pontos: %d | Combo: %d | Acertos: %d | Erros: %d\nTeclas = A S D F | ESC menu" % [_score, _combo, _hits, _misses]

func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

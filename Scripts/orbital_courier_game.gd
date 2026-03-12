extends Node2D

const CENTER := Vector2(576, 360)
const MIN_RADIUS := 90.0
const MAX_RADIUS := 300.0
const ANGULAR_SPEED := 2.6
const RADIAL_SPEED := 170.0
const PLAYER_SIZE := Vector2(0.6, 0.6)
const PACKAGE_SIZE := Vector2(0.42, 0.42)

@onready var player: Sprite2D = $Player
@onready var package: Sprite2D = $Package
@onready var hud: Label = $CanvasLayer/HUD

var _square_texture: Texture2D
var _circle_texture: Texture2D

var _angle := 0.0
var _radius := 170.0
var _package_angle := 1.2
var _package_radius := 220.0
var _score := 0
var _shield := 3
var _time_left := 60.0
var _game_over := false

var _pulse_radius := 0.0
var _pulse_speed := 240.0
var _pulse_cooldown := 2.2
var _pulse_timer := 2.2

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_circle_texture = preload("res://Assets/Sprites/Circle.png")
	_randomize_seed()
	_reset_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _game_over and event.is_action_pressed("ui_accept"):
		_reset_game()

func _process(delta: float) -> void:
	if _game_over:
		_update_hud()
		queue_redraw()
		return

	_time_left = max(0.0, _time_left - delta)
	if _time_left <= 0.0:
		_game_over = true

	_move_player(delta)
	_update_pulse(delta)
	_check_collection()
	_update_hud()
	queue_redraw()

func _move_player(delta: float) -> void:
	var turn := Input.get_axis("ui_left", "ui_right")
	var radial := Input.get_axis("ui_up", "ui_down")

	_angle += turn * ANGULAR_SPEED * delta
	_radius += radial * RADIAL_SPEED * delta
	_radius = clamp(_radius, MIN_RADIUS, MAX_RADIUS)

	player.position = CENTER + Vector2(cos(_angle), sin(_angle)) * _radius
	player.rotation = _angle + PI * 0.5

func _update_pulse(delta: float) -> void:
	if _pulse_radius > 0.0:
		_pulse_radius += _pulse_speed * delta
		if absf(_pulse_radius - _radius) <= 8.0:
			_shield -= 1
			_pulse_radius = -1.0
			if _shield <= 0:
				_game_over = true
		elif _pulse_radius > MAX_RADIUS + 40.0:
			_pulse_radius = -1.0
		return

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = _pulse_cooldown
		_pulse_cooldown = max(0.9, _pulse_cooldown - 0.06)
		_pulse_radius = MIN_RADIUS - 26.0

func _check_collection() -> void:
	if player.position.distance_to(package.position) <= 30.0:
		_score += 1
		_time_left = min(75.0, _time_left + 3.5)
		_spawn_package()

func _spawn_package() -> void:
	_package_angle = randf_range(0.0, TAU)
	_package_radius = randf_range(MIN_RADIUS + 16.0, MAX_RADIUS - 12.0)
	package.position = CENTER + Vector2(cos(_package_angle), sin(_package_angle)) * _package_radius

func _reset_game() -> void:
	_angle = randf_range(0.0, TAU)
	_radius = 170.0
	_score = 0
	_shield = 3
	_time_left = 60.0
	_game_over = false
	_pulse_radius = -1.0
	_pulse_speed = 240.0
	_pulse_cooldown = 2.2
	_pulse_timer = 2.2

	player.texture = _square_texture
	player.scale = PLAYER_SIZE
	player.modulate = Color(0.5, 1.0, 0.8)

	package.texture = _circle_texture
	package.scale = PACKAGE_SIZE
	package.modulate = Color(1.0, 0.85, 0.35)

	_move_player(0.0)
	_spawn_package()
	_update_hud()
	queue_redraw()

func _update_hud() -> void:
	if _game_over:
		hud.text = "Correio Orbital | Entregas: %d | Enter reinicia | ESC menu" % _score
		return

	hud.text = "Correio Orbital | Entregas: %d | Escudo: %d | Tempo: %02d" % [_score, _shield, int(_time_left)]

func _draw() -> void:
	draw_circle(CENTER, MAX_RADIUS + 20.0, Color(0.03, 0.03, 0.08, 1.0))
	draw_arc(CENTER, MIN_RADIUS, 0.0, TAU, 90, Color(0.2, 0.3, 0.6, 0.9), 2.0)
	draw_arc(CENTER, (MIN_RADIUS + MAX_RADIUS) * 0.5, 0.0, TAU, 96, Color(0.18, 0.4, 0.5, 0.6), 1.5)
	draw_arc(CENTER, MAX_RADIUS, 0.0, TAU, 128, Color(0.2, 0.3, 0.6, 0.9), 2.0)
	draw_circle(CENTER, 36.0, Color(0.95, 0.45, 0.2, 1.0))
	draw_circle(CENTER, 22.0, Color(1.0, 0.86, 0.4, 1.0))

	if _pulse_radius > 0.0:
		draw_arc(CENTER, _pulse_radius, 0.0, TAU, 128, Color(1.0, 0.35, 0.35, 0.95), 4.0)

	draw_string(ThemeDB.fallback_font, Vector2(372, 72), "Setas: orbite e ajuste raio | Evite pulsos solares", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.8, 0.92, 1.0))

func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

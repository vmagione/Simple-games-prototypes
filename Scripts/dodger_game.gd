extends Node2D

const GRID_SIZE := 24
const GRID_WIDTH := 48
const GRID_HEIGHT := 30
const PLAYER_SPEED := 320.0
const OBSTACLE_MIN_SPEED := 150.0
const OBSTACLE_MAX_SPEED := 300.0

@onready var player_sprite: Sprite2D = $Player
@onready var walls_container: Node2D = $Walls
@onready var obstacles_container: Node2D = $Obstacles
@onready var spawn_timer: Timer = $SpawnTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _square_texture: Texture2D
var _game_over := false
var _score := 0
var _score_accumulator := 0.0

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_randomize_seed()
	_draw_walls()
	_reset_game()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _game_over and event.is_action_pressed("ui_accept"):
		_reset_game()
		return

func _process(delta: float) -> void:
	if _game_over:
		return

	_move_player(delta)
	_move_obstacles(delta)
	_check_collisions()
	_update_score(delta)
	_cleanup_offscreen_obstacles()
	_update_label()

func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	player_sprite.position += direction * PLAYER_SPEED * delta
	player_sprite.position.x = clamp(player_sprite.position.x, GRID_SIZE * 1.5, GRID_SIZE * (GRID_WIDTH - 1.5))
	player_sprite.position.y = clamp(player_sprite.position.y, GRID_SIZE * 1.5, GRID_SIZE * (GRID_HEIGHT - 1.5))

func _move_obstacles(delta: float) -> void:
	for obstacle in obstacles_container.get_children():
		var velocity: Vector2 = obstacle.get_meta("velocity")
		obstacle.position += velocity * delta

func _check_collisions() -> void:
	for obstacle in obstacles_container.get_children():
		if obstacle.position.distance_to(player_sprite.position) <= GRID_SIZE * 0.7:
			_set_game_over()
			return

func _update_score(delta: float) -> void:
	_score_accumulator += delta
	while _score_accumulator >= 0.35:
		_score += 1
		_score_accumulator -= 0.35

func _cleanup_offscreen_obstacles() -> void:
	for obstacle in obstacles_container.get_children():
		if obstacle.position.y > GRID_SIZE * (GRID_HEIGHT + 1):
			obstacle.queue_free()

func _on_spawn_timer_timeout() -> void:
	if _game_over:
		return

	var obstacle := Sprite2D.new()
	obstacle.texture = _square_texture
	obstacle.modulate = Color(0.95, 0.35, 0.35, 1.0)
	obstacle.scale = Vector2(0.75, 0.75)
	obstacle.position = Vector2(
		randi_range(GRID_SIZE * 2, GRID_SIZE * (GRID_WIDTH - 2)),
		GRID_SIZE
	)
	var speed := randf_range(OBSTACLE_MIN_SPEED, OBSTACLE_MAX_SPEED)
	obstacle.set_meta("velocity", Vector2(0, speed))
	obstacles_container.add_child(obstacle)

	spawn_timer.wait_time = max(0.22, spawn_timer.wait_time - 0.005)

func _draw_walls() -> void:
	for child in walls_container.get_children():
		child.queue_free()

	for x in GRID_WIDTH:
		_add_square(walls_container, Vector2i(x, 0), Color(0.25, 0.35, 0.85, 1.0), Vector2(1.0, 1.0))
		_add_square(walls_container, Vector2i(x, GRID_HEIGHT - 1), Color(0.25, 0.35, 0.85, 1.0), Vector2(1.0, 1.0))

	for y in GRID_HEIGHT:
		_add_square(walls_container, Vector2i(0, y), Color(0.25, 0.35, 0.85, 1.0), Vector2(1.0, 1.0))
		_add_square(walls_container, Vector2i(GRID_WIDTH - 1, y), Color(0.25, 0.35, 0.85, 1.0), Vector2(1.0, 1.0))

func _reset_game() -> void:
	_game_over = false
	_score = 0
	_score_accumulator = 0.0
	spawn_timer.wait_time = 0.65

	for obstacle in obstacles_container.get_children():
		obstacle.queue_free()

	player_sprite.texture = _square_texture
	player_sprite.modulate = Color(0.2, 0.95, 0.3, 1.0)
	player_sprite.scale = Vector2(0.8, 0.8)
	player_sprite.position = Vector2(GRID_SIZE * GRID_WIDTH * 0.5, GRID_SIZE * (GRID_HEIGHT - 3))

	spawn_timer.start()
	_update_label()

func _set_game_over() -> void:
	_game_over = true
	spawn_timer.stop()
	_update_label()

func _add_square(parent: Node2D, cell: Vector2i, color: Color, scale_size: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _square_texture
	sprite.modulate = color
	sprite.scale = scale_size
	sprite.position = Vector2(cell * GRID_SIZE) + Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
	parent.add_child(sprite)

func _update_label() -> void:
	if _game_over:
		info_label.text = "Desvio | Pontos: %d | Fim de jogo! Enter reinicia | ESC menu" % _score
	else:
		info_label.text = "Desvio | Pontos: %d | Use setas para mover | ESC menu" % _score

func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

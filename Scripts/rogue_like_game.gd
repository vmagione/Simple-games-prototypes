extends Node2D

const GRID_SIZE := 24
const GRID_WIDTH := 48
const GRID_HEIGHT := 30
const PLAYER_SPEED := 240.0
const BULLET_SPEED := 420.0
const SHOOT_INTERVAL := 0.28
const PLAYER_MAX_HP := 12

const ENEMY_TYPES := [
	{
		"name": "Scout",
		"color": Color(1.0, 0.3, 0.3, 1.0),
		"hp": 1,
		"speed": 70.0,
		"points": 10,
		"weight": 50
	},
	{
		"name": "Brute",
		"color": Color(1.0, 0.55, 0.2, 1.0),
		"hp": 3,
		"speed": 48.0,
		"points": 25,
		"weight": 35
	},
	{
		"name": "Tank",
		"color": Color(0.75, 0.2, 1.0, 1.0),
		"hp": 6,
		"speed": 34.0,
		"points": 55,
		"weight": 15
	}
]

@onready var walls_container: Node2D = $Walls
@onready var player_sprite: Sprite2D = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var bullets_container: Node2D = $Bullets
@onready var info_label: Label = $CanvasLayer/InfoLabel
@onready var spawn_timer: Timer = $SpawnTimer
@onready var shoot_timer: Timer = $ShootTimer

var _square_texture: Texture2D
var _arena_rect := Rect2(Vector2(GRID_SIZE, GRID_SIZE), Vector2((GRID_WIDTH - 2) * GRID_SIZE, (GRID_HEIGHT - 2) * GRID_SIZE))
var _score := 0
var _player_hp := PLAYER_MAX_HP
var _game_over := false

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	seed(Time.get_unix_time_from_system())
	_draw_walls()
	_reset_game()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	spawn_timer.start()
	shoot_timer.start()

func _process(delta: float) -> void:
	if _game_over:
		return
	_handle_player_movement(delta)
	_update_enemies(delta)
	_update_bullets(delta)
	_check_enemy_collisions_with_player()
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _game_over and event.is_action_pressed("ui_accept"):
		_reset_game()

func _handle_player_movement(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector == Vector2.ZERO:
		return

	player_sprite.position += input_vector.normalized() * PLAYER_SPEED * delta
	player_sprite.position.x = clamp(player_sprite.position.x, _arena_rect.position.x, _arena_rect.end.x)
	player_sprite.position.y = clamp(player_sprite.position.y, _arena_rect.position.y, _arena_rect.end.y)

func _update_enemies(delta: float) -> void:
	for enemy in enemies_container.get_children():
		var to_player = player_sprite.position - enemy.position
		if to_player.length() > 0.1:
			enemy.position += to_player.normalized() * enemy.get_meta("speed") * delta

func _update_bullets(delta: float) -> void:
	for bullet in bullets_container.get_children():
		bullet.position += bullet.get_meta("velocity") * delta
		if not _is_inside_arena(bullet.position):
			bullet.queue_free()
			continue

		for enemy in enemies_container.get_children():
			if bullet.position.distance_to(enemy.position) <= GRID_SIZE * 0.5:
				var current_hp: int = enemy.get_meta("hp")
				current_hp -= 1
				if current_hp <= 0:
					_score += enemy.get_meta("points")
					enemy.queue_free()
				else:
					enemy.set_meta("hp", current_hp)
				bullet.queue_free()
				break

func _check_enemy_collisions_with_player() -> void:
	for enemy in enemies_container.get_children():
		if enemy.position.distance_to(player_sprite.position) <= GRID_SIZE * 0.6:
			_player_hp -= 1
			enemy.queue_free()
			if _player_hp <= 0:
				_set_game_over()
				return

func _on_spawn_timer_timeout() -> void:
	if _game_over:
		return

	var enemy_data := _pick_enemy_type()
	var enemy := Sprite2D.new()
	enemy.texture = _square_texture
	enemy.modulate = enemy_data["color"]
	enemy.scale = Vector2(0.75, 0.75)
	enemy.position = _random_border_position()
	enemy.set_meta("hp", enemy_data["hp"])
	enemy.set_meta("speed", enemy_data["speed"])
	enemy.set_meta("points", enemy_data["points"])
	enemies_container.add_child(enemy)

	spawn_timer.wait_time = max(0.4, spawn_timer.wait_time - 0.015)

func _on_shoot_timer_timeout() -> void:
	if _game_over:
		return
	if enemies_container.get_child_count() == 0:
		return

	var target := _get_closest_enemy()
	if target == null:
		return

	var direction := (target.position - player_sprite.position).normalized()
	var bullet := Sprite2D.new()
	bullet.texture = _square_texture
	bullet.modulate = Color(0.9, 1.0, 0.6, 1.0)
	bullet.scale = Vector2(0.35, 0.35)
	bullet.position = player_sprite.position
	bullet.set_meta("velocity", direction * BULLET_SPEED)
	bullets_container.add_child(bullet)

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
	_player_hp = PLAYER_MAX_HP
	spawn_timer.wait_time = 1.2
	shoot_timer.wait_time = SHOOT_INTERVAL

	for enemy in enemies_container.get_children():
		enemy.queue_free()
	for bullet in bullets_container.get_children():
		bullet.queue_free()

	player_sprite.texture = _square_texture
	player_sprite.modulate = Color(0.2, 0.95, 0.3, 1.0)
	player_sprite.scale = Vector2(0.9, 0.9)
	player_sprite.position = _arena_rect.position + _arena_rect.size * 0.5

	_update_label()
	spawn_timer.start()
	shoot_timer.start()

func _set_game_over() -> void:
	_game_over = true
	spawn_timer.stop()
	shoot_timer.stop()
	_update_label()

func _pick_enemy_type() -> Dictionary:
	var total_weight := 0
	for enemy_type in ENEMY_TYPES:
		total_weight += enemy_type["weight"]

	var random_value := randi() % total_weight
	for enemy_type in ENEMY_TYPES:
		random_value -= enemy_type["weight"]
		if random_value < 0:
			return enemy_type
	return ENEMY_TYPES[0]

func _get_closest_enemy() -> Sprite2D:
	var closest_enemy: Sprite2D = null
	var best_distance := INF

	for enemy in enemies_container.get_children():
		var distance = enemy.position.distance_squared_to(player_sprite.position)
		if distance < best_distance:
			best_distance = distance
			closest_enemy = enemy

	return closest_enemy

func _random_border_position() -> Vector2:
	var side := randi() % 4
	if side == 0:
		return Vector2(randi_range(_arena_rect.position.x, _arena_rect.end.x), _arena_rect.position.y)
	if side == 1:
		return Vector2(randi_range(_arena_rect.position.x, _arena_rect.end.x), _arena_rect.end.y)
	if side == 2:
		return Vector2(_arena_rect.position.x, randi_range(_arena_rect.position.y, _arena_rect.end.y))
	return Vector2(_arena_rect.end.x, randi_range(_arena_rect.position.y, _arena_rect.end.y))

func _is_inside_arena(position: Vector2) -> bool:
	return position.x >= _arena_rect.position.x and position.x <= _arena_rect.end.x and position.y >= _arena_rect.position.y and position.y <= _arena_rect.end.y

func _add_square(parent: Node2D, cell: Vector2i, color: Color, scale_size: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _square_texture
	sprite.modulate = color
	sprite.scale = scale_size
	sprite.position = Vector2(cell * GRID_SIZE) + Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
	parent.add_child(sprite)

func _update_label() -> void:
	if _game_over:
		info_label.text = "Rogue Like | Pontos: %d | Você perdeu! Enter reinicia | ESC menu" % _score
	else:
		info_label.text = "Rogue Like | Vida: %d | Pontos: %d | Mova com setas/wasd | ESC menu" % [_player_hp, _score]

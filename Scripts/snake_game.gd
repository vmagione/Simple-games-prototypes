extends Node2D

const GRID_SIZE := 24
const GRID_WIDTH := 48
const GRID_HEIGHT := 30

@onready var wall_container: Node2D = $Walls
@onready var snake_container: Node2D = $Snake
@onready var food_container: Node2D = $Food
@onready var tick_timer: Timer = $TickTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _square_texture: Texture2D
var _snake: Array[Vector2i] = []
var _direction := Vector2i.RIGHT
var _next_direction := Vector2i.RIGHT
var _food_position := Vector2i.ZERO
var _pending_growth := 0
var _score := 0

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_randomize_seed()
	_draw_walls()
	_reset_game()
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if event.is_action_pressed("ui_up") and _direction != Vector2i.DOWN:
		_next_direction = Vector2i.UP
	elif event.is_action_pressed("ui_down") and _direction != Vector2i.UP:
		_next_direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_left") and _direction != Vector2i.RIGHT:
		_next_direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right") and _direction != Vector2i.LEFT:
		_next_direction = Vector2i.RIGHT

func _on_tick() -> void:
	_direction = _next_direction
	var new_head := _snake[0] + _direction

	if _hits_wall(new_head) or _snake.has(new_head):
		_reset_game()
		return

	_snake.push_front(new_head)
	if _pending_growth > 0:
		_pending_growth -= 1
	else:
		_snake.pop_back()

	if new_head == _food_position:
		_score += 1
		_pending_growth += 1
		_spawn_food()

	_render_snake()
	_render_food()
	_update_label()

func _reset_game() -> void:
	_direction = Vector2i.RIGHT
	_next_direction = Vector2i.RIGHT
	_pending_growth = 0
	_score = 0
	_snake = [
		Vector2i(24, 15),
		Vector2i(23, 15),
		Vector2i(22, 15)
	]
	_spawn_food()
	_render_snake()
	_render_food()
	_update_label()

func _spawn_food() -> void:
	while true:
		var candidate := Vector2i(
			randi_range(1, GRID_WIDTH - 2),
			randi_range(1, GRID_HEIGHT - 2)
		)
		if not _snake.has(candidate):
			_food_position = candidate
			return

func _hits_wall(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.x >= GRID_WIDTH - 1 or cell.y <= 0 or cell.y >= GRID_HEIGHT - 1

func _draw_walls() -> void:
	for child in wall_container.get_children():
		child.queue_free()

	for x in GRID_WIDTH:
		_add_square(wall_container, Vector2i(x, 0), Color.WHITE)
		_add_square(wall_container, Vector2i(x, GRID_HEIGHT - 1), Color.WHITE)

	for y in GRID_HEIGHT:
		_add_square(wall_container, Vector2i(0, y), Color.WHITE)
		_add_square(wall_container, Vector2i(GRID_WIDTH - 1, y), Color.WHITE)

func _render_snake() -> void:
	for child in snake_container.get_children():
		child.queue_free()

	for index in _snake.size():
		var color := Color(0.1, 0.85, 0.2, 1)
		if index == 0:
			color = Color(0.15, 1.0, 0.3, 1)
		_add_square(snake_container, _snake[index], color)

func _render_food() -> void:
	for child in food_container.get_children():
		child.queue_free()

	var sprite := _add_square(food_container, _food_position, Color(0.95, 0.15, 0.15, 1))
	sprite.scale = Vector2(0.55, 0.55)

func _add_square(parent: Node2D, cell: Vector2i, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _square_texture
	sprite.modulate = color
	sprite.position = Vector2(cell * GRID_SIZE) + Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
	parent.add_child(sprite)
	return sprite

func _update_label() -> void:
	info_label.text = "Snake  |  Pontos: %d  |  ESC para voltar ao menu" % _score

func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

extends Node2D

const CELL_SIZE := 32
const WALL_SCALE := Vector2(1.0, 1.0)
const MAZE_LAYOUT := [
	"####################",
	"S.............#....#",
	"###.#.#.#####.#.###",
	"#...#.#.....#.#...#",
	"#.###.#####.#.###.#",
	"#.....#...#.#.....#",
	"#.#####.#.#.#####.#",
	"#.#.....#.#.....#.#",
	"#.#.#####.#####.#.#",
	"#.#.....#.....#.#.#",
	"#.#####.#####.#.#.#",
	"#.....#.....#...#E#",
	"####################"
]

@onready var walls_container: Node2D = $Walls
@onready var exit_container: Node2D = $Exit
@onready var player_container: Node2D = $Player
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _square_texture: Texture2D
var _start_cell := Vector2i.ZERO
var _exit_cell := Vector2i.ZERO
var _player_cell := Vector2i.ZERO
var _won := false

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_draw_maze()
	_reset_player()
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _won:
		if event.is_action_pressed("ui_accept"):
			_reset_player()
			_update_label()
		return

	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT

	if direction != Vector2i.ZERO:
		_try_move(direction)

func _draw_maze() -> void:
	for child in walls_container.get_children():
		child.queue_free()
	for child in exit_container.get_children():
		child.queue_free()

	for y in MAZE_LAYOUT.size():
		var row = MAZE_LAYOUT[y]
		for x in row.length():
			var cell = row[x]
			var grid_pos := Vector2i(x, y)
			if cell == "#":
				_add_square(walls_container, grid_pos, Color(0.25, 0.35, 0.85, 1.0), WALL_SCALE)
			elif cell == "S":
				_start_cell = grid_pos
			elif cell == "E":
				_exit_cell = grid_pos
				_add_square(exit_container, grid_pos, Color(0.95, 0.75, 0.2, 1.0), Vector2(0.9, 0.9))

func _reset_player() -> void:
	_won = false
	_player_cell = _start_cell
	_render_player()

func _try_move(direction: Vector2i) -> void:
	var next_cell := _player_cell + direction
	if _is_wall(next_cell):
		return

	_player_cell = next_cell
	_render_player()

	if _player_cell == _exit_cell:
		_won = true

	_update_label()

func _is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAZE_LAYOUT.size():
		return true
	if cell.x < 0 or cell.x >= MAZE_LAYOUT[cell.y].length():
		return true
	return MAZE_LAYOUT[cell.y][cell.x] == "#"

func _render_player() -> void:
	for child in player_container.get_children():
		child.queue_free()

	_add_square(player_container, _player_cell, Color(0.2, 0.95, 0.3, 1.0), Vector2(0.8, 0.8))

func _add_square(parent: Node2D, cell: Vector2i, color: Color, scale_size: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _square_texture
	sprite.modulate = color
	sprite.scale = scale_size
	sprite.position = Vector2(cell * CELL_SIZE) + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	parent.add_child(sprite)

func _update_label() -> void:
	if _won:
		info_label.text = "Labirinto concluído! Enter para reiniciar | ESC para voltar ao menu"
	else:
		info_label.text = "Labirinto: setas para mover | Objetivo: chegar na saída amarela | ESC para menu"

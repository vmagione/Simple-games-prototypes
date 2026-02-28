extends Node2D

const TILE_SIZE := 24
const WORLD_WIDTH := 180
const WORLD_HEIGHT := 70
const GRAVITY := 1200.0
const MOVE_SPEED := 220.0
const JUMP_SPEED := -460.0
const REACH_DISTANCE := 4

const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3

const BLOCK_COLORS := {
	BLOCK_GRASS: Color(0.25, 0.75, 0.25, 1.0),
	BLOCK_DIRT: Color(0.48, 0.32, 0.18, 1.0),
	BLOCK_STONE: Color(0.56, 0.56, 0.6, 1.0)
}

@onready var world_blocks: Node2D = $WorldBlocks
@onready var player_bottom: Sprite2D = $PlayerBottom
@onready var player_top: Sprite2D = $PlayerTop
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _square_texture: Texture2D
var _world_data: Array = []
var _block_sprites: Dictionary = {}
var _velocity := Vector2.ZERO
var _player_position := Vector2.ZERO
var _player_facing := Vector2.RIGHT
var _player_on_floor := false
var _inventory := {
	BLOCK_GRASS: 0,
	BLOCK_DIRT: 0,
	BLOCK_STONE: 0
}

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	seed(Time.get_unix_time_from_system())
	_generate_world()
	_spawn_player()
	_setup_player_visuals()
	_setup_camera()
	_update_player_visuals()
	_update_info_label()

func _physics_process(delta: float) -> void:
	_handle_input()
	_apply_physics(delta)
	_update_player_visuals()
	_update_info_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if event.is_action_pressed("mine_block"):
		_mine_target_block()

	if event.is_action_pressed("place_block"):
		_place_target_block()

func _handle_input() -> void:
	var horizontal := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	_velocity.x = horizontal * MOVE_SPEED

	if horizontal < -0.1:
		_player_facing = Vector2.LEFT
	elif horizontal > 0.1:
		_player_facing = Vector2.RIGHT

	if Input.is_action_just_pressed("ui_up") and _player_on_floor:
		_velocity.y = JUMP_SPEED
		_player_on_floor = false

func _apply_physics(delta: float) -> void:
	_velocity.y += GRAVITY * delta

	_player_position.x += _velocity.x * delta
	_resolve_horizontal_collisions()

	_player_position.y += _velocity.y * delta
	_resolve_vertical_collisions()

func _resolve_horizontal_collisions() -> void:
	if _velocity.x == 0.0:
		return

	var half_width := TILE_SIZE * 0.38
	var top := _player_position.y - TILE_SIZE * 1.5 + 2.0
	var bottom := _player_position.y + TILE_SIZE * 0.5 - 2.0

	if _velocity.x > 0.0:
		var right := _player_position.x + half_width
		var cell_x := int(floor(right / TILE_SIZE))
		for sample_y in [top, _player_position.y - TILE_SIZE * 0.5, bottom]:
			var cell_y := int(floor(sample_y / TILE_SIZE))
			if _is_solid(cell_x, cell_y):
				_player_position.x = cell_x * TILE_SIZE - half_width - 0.01
				_velocity.x = 0.0
				break
	else:
		var left := _player_position.x - half_width
		var cell_x := int(floor(left / TILE_SIZE))
		for sample_y in [top, _player_position.y - TILE_SIZE * 0.5, bottom]:
			var cell_y := int(floor(sample_y / TILE_SIZE))
			if _is_solid(cell_x, cell_y):
				_player_position.x = (cell_x + 1) * TILE_SIZE + half_width + 0.01
				_velocity.x = 0.0
				break

func _resolve_vertical_collisions() -> void:
	var half_width := TILE_SIZE * 0.38
	var left := _player_position.x - half_width
	var center := _player_position.x
	var right := _player_position.x + half_width
	var top := _player_position.y - TILE_SIZE * 1.5
	var bottom := _player_position.y + TILE_SIZE * 0.5

	_player_on_floor = false

	if _velocity.y > 0.0:
		var cell_y := int(floor(bottom / TILE_SIZE))
		for sample_x in [left, center, right]:
			var cell_x := int(floor(sample_x / TILE_SIZE))
			if _is_solid(cell_x, cell_y):
				_player_position.y = cell_y * TILE_SIZE - TILE_SIZE * 0.5 - 0.01
				_velocity.y = 0.0
				_player_on_floor = true
				return
	elif _velocity.y < 0.0:
		var cell_y := int(floor(top / TILE_SIZE))
		for sample_x in [left, center, right]:
			var cell_x := int(floor(sample_x / TILE_SIZE))
			if _is_solid(cell_x, cell_y):
				_player_position.y = (cell_y + 1) * TILE_SIZE + TILE_SIZE * 1.5 + 0.01
				_velocity.y = 0.0
				return

func _mine_target_block() -> void:
	var target := _get_targeted_cell()
	if not _is_inside_world(target.x, target.y):
		return

	var block_type = _world_data[target.y][target.x]
	if block_type == BLOCK_AIR:
		return

	_world_data[target.y][target.x] = BLOCK_AIR
	_inventory[block_type] += 1
	_remove_block_sprite(target.x, target.y)

func _place_target_block() -> void:
	var target := _get_targeted_cell()
	if not _is_inside_world(target.x, target.y):
		return
	if _world_data[target.y][target.x] != BLOCK_AIR:
		return

	var chosen_block := _get_best_inventory_block()
	if chosen_block == BLOCK_AIR:
		return

	_world_data[target.y][target.x] = chosen_block
	_inventory[chosen_block] -= 1
	_add_block_sprite(target.x, target.y, chosen_block)

func _get_best_inventory_block() -> int:
	for block_type in [BLOCK_DIRT, BLOCK_STONE, BLOCK_GRASS]:
		if _inventory[block_type] > 0:
			return block_type
	return BLOCK_AIR

func _get_targeted_cell() -> Vector2i:
	var player_feet_cell := Vector2i(
		int(floor(_player_position.x / TILE_SIZE)),
		int(floor(_player_position.y / TILE_SIZE))
	)
	var direction := Vector2i(int(_player_facing.x), 0)
	return player_feet_cell + direction * REACH_DISTANCE

func _setup_player_visuals() -> void:
	player_bottom.texture = _square_texture
	player_bottom.modulate = Color(0.95, 0.35, 0.5, 1.0)
	player_bottom.scale = Vector2(0.95, 0.95)

	player_top.texture = _square_texture
	player_top.modulate = Color(0.95, 0.35, 0.5, 1.0)
	player_top.scale = Vector2(0.95, 0.95)

func _update_player_visuals() -> void:
	player_bottom.position = _player_position
	player_top.position = _player_position + Vector2(0, -TILE_SIZE)

func _setup_camera() -> void:
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_WIDTH * TILE_SIZE
	camera.limit_bottom = WORLD_HEIGHT * TILE_SIZE
	camera.position = _player_position

func _spawn_player() -> void:
	var spawn_x := 8
	var spawn_y := 0
	for y in WORLD_HEIGHT:
		if _world_data[y][spawn_x] != BLOCK_AIR:
			spawn_y = y - 1
			break

	_player_position = Vector2(spawn_x * TILE_SIZE + TILE_SIZE * 0.5, spawn_y * TILE_SIZE + TILE_SIZE * 0.5)

func _generate_world() -> void:
	for child in world_blocks.get_children():
		child.queue_free()

	_world_data.clear()
	_block_sprites.clear()

	var surface_height := int(WORLD_HEIGHT * 0.45)
	for y in WORLD_HEIGHT:
		var row: Array[int] = []
		for _x in WORLD_WIDTH:
			row.append(BLOCK_AIR)
		_world_data.append(row)

	for x in WORLD_WIDTH:
		surface_height += randi_range(-1, 1)
		surface_height = clamp(surface_height, int(WORLD_HEIGHT * 0.28), int(WORLD_HEIGHT * 0.62))

		for y in range(surface_height, WORLD_HEIGHT):
			var block_type := BLOCK_STONE
			if y == surface_height:
				block_type = BLOCK_GRASS
			elif y < surface_height + 4:
				block_type = BLOCK_DIRT

			if y > surface_height + 6 and randf() < 0.14:
				block_type = BLOCK_AIR

			_world_data[y][x] = block_type
			if block_type != BLOCK_AIR:
				_add_block_sprite(x, y, block_type)

func _add_block_sprite(x: int, y: int, block_type: int) -> void:
	var key := _block_key(x, y)
	if _block_sprites.has(key):
		return

	var sprite := Sprite2D.new()
	sprite.texture = _square_texture
	sprite.modulate = BLOCK_COLORS[block_type]
	sprite.position = Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
	world_blocks.add_child(sprite)
	_block_sprites[key] = sprite

func _remove_block_sprite(x: int, y: int) -> void:
	var key := _block_key(x, y)
	if not _block_sprites.has(key):
		return

	var sprite: Sprite2D = _block_sprites[key]
	sprite.queue_free()
	_block_sprites.erase(key)

func _is_solid(cell_x: int, cell_y: int) -> bool:
	if not _is_inside_world(cell_x, cell_y):
		return true
	return _world_data[cell_y][cell_x] != BLOCK_AIR

func _is_inside_world(cell_x: int, cell_y: int) -> bool:
	return cell_x >= 0 and cell_x < WORLD_WIDTH and cell_y >= 0 and cell_y < WORLD_HEIGHT

func _block_key(x: int, y: int) -> String:
	return "%d:%d" % [x, y]

func _update_info_label() -> void:
	var floor_state := "Ar"
	if _player_on_floor:
		floor_state = "Chão"

	info_label.text = "Terraria Lite | %s | Mineração: E | Construir: Q | Inventário T:%d P:%d G:%d | ESC Menu" % [
		floor_state,
		_inventory[BLOCK_DIRT],
		_inventory[BLOCK_STONE],
		_inventory[BLOCK_GRASS]
	]

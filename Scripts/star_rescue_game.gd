extends Node2D

const SCREEN_SIZE := Vector2(1152, 720)
const PLAYER_SPEED := 420.0
const PLAYER_RADIUS := 28.0
const STAR_RADIUS := 22.0
const HAZARD_RADIUS := 30.0
const PLAYER_MARGIN := Vector2(56, 72)
const HAZARD_SPAWN_PADDING := 80.0

const SHIP_TEXTURE := preload("res://Assets/Sprites/SpaceShooter/playerShip1_blue.png")
const METEOR_TEXTURE := preload("res://Assets/Sprites/SpaceShooter/meteorBrown_med1.png")
const STAR_TEXTURE := preload("res://Assets/Sprites/SpaceShooter/powerupBlue_star.png")
const UFO_TEXTURE := preload("res://Assets/Sprites/SpaceShooter/ufoRed.png")

@onready var collectibles_container: Node2D = $Collectibles
@onready var hazards_container: Node2D = $Hazards
@onready var player_sprite: Sprite2D = $Player
@onready var hazard_timer: Timer = $HazardTimer
@onready var star_timer: Timer = $StarTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _game_over := false
var _score := 0
var _survival_time := 0.0
var _background_stars: Array[Dictionary] = []

func _ready() -> void:
	_randomize_seed()
	_build_background_stars()
	_configure_player()
	_reset_game()
	hazard_timer.timeout.connect(_on_hazard_timer_timeout)
	star_timer.timeout.connect(_on_star_timer_timeout)
	hazard_timer.start()
	star_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _game_over and event.is_action_pressed("ui_accept"):
		_reset_game()

func _process(delta: float) -> void:
	if _game_over:
		_spin_collectibles(delta)
		return

	_survival_time += delta
	_move_player(delta)
	_move_hazards(delta)
	_spin_collectibles(delta)
	_check_star_collection()
	_check_hazard_collisions()
	_cleanup_hazards()
	_update_difficulty()
	_update_label()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.039, 0.059, 0.157))
	draw_rect(Rect2(Vector2(24, 24), SCREEN_SIZE - Vector2(48, 48)), Color(0.082, 0.125, 0.278, 0.92), false, 4.0)

	for star in _background_stars:
		draw_circle(star["position"], star["radius"], star["color"])

func _configure_player() -> void:
	player_sprite.texture = SHIP_TEXTURE
	player_sprite.scale = Vector2(0.75, 0.75)
	player_sprite.rotation_degrees = 0.0
	player_sprite.modulate = Color(1, 1, 1, 1)
	player_sprite.centered = true

func _reset_game() -> void:
	_game_over = false
	_score = 0
	_survival_time = 0.0
	hazard_timer.wait_time = 0.85

	for child in hazards_container.get_children():
		child.queue_free()
	for child in collectibles_container.get_children():
		child.queue_free()

	player_sprite.position = Vector2(SCREEN_SIZE.x * 0.5, SCREEN_SIZE.y - 88.0)
	_spawn_star()
	hazard_timer.start()
	star_timer.start()
	_update_label()

func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		direction = direction.normalized()

	player_sprite.position += direction * PLAYER_SPEED * delta
	player_sprite.position.x = clamp(player_sprite.position.x, PLAYER_MARGIN.x, SCREEN_SIZE.x - PLAYER_MARGIN.x)
	player_sprite.position.y = clamp(player_sprite.position.y, PLAYER_MARGIN.y, SCREEN_SIZE.y - PLAYER_MARGIN.y)

	if direction.x != 0.0:
		player_sprite.rotation = lerp(player_sprite.rotation, direction.x * 0.3, 0.12)
	else:
		player_sprite.rotation = lerp(player_sprite.rotation, 0.0, 0.12)

func _move_hazards(delta: float) -> void:
	for hazard in hazards_container.get_children():
		var velocity: Vector2 = hazard.get_meta("velocity", Vector2.ZERO)
		hazard.position += velocity * delta
		hazard.rotation += float(hazard.get_meta("spin_speed", 0.0)) * delta

func _spin_collectibles(delta: float) -> void:
	for collectible in collectibles_container.get_children():
		collectible.rotation += delta * 1.8

func _check_star_collection() -> void:
	for collectible in collectibles_container.get_children():
		if collectible.position.distance_to(player_sprite.position) <= PLAYER_RADIUS + STAR_RADIUS:
			collectible.queue_free()
			_score += 1
			_spawn_star()
			_update_label()
			return

func _check_hazard_collisions() -> void:
	for hazard in hazards_container.get_children():
		if hazard.position.distance_to(player_sprite.position) <= PLAYER_RADIUS + HAZARD_RADIUS:
			_set_game_over()
			return

func _cleanup_hazards() -> void:
	for hazard in hazards_container.get_children():
		if hazard.position.x < -160.0 or hazard.position.x > SCREEN_SIZE.x + 160.0:
			hazard.queue_free()
			continue
		if hazard.position.y < -160.0 or hazard.position.y > SCREEN_SIZE.y + 160.0:
			hazard.queue_free()

func _update_difficulty() -> void:
	hazard_timer.wait_time = max(0.3, 0.85 - float(_score) * 0.03)

func _on_hazard_timer_timeout() -> void:
	if _game_over:
		return

	if randf() < 0.65:
		_spawn_meteor()
	else:
		_spawn_ufo()

func _on_star_timer_timeout() -> void:
	if _game_over:
		return

	if collectibles_container.get_child_count() == 0:
		_spawn_star()

func _spawn_star() -> void:
	if collectibles_container.get_child_count() > 0:
		return

	var collectible := Sprite2D.new()
	collectible.texture = STAR_TEXTURE
	collectible.scale = Vector2(0.75, 0.75)
	collectible.position = Vector2(
		randf_range(PLAYER_MARGIN.x + 24.0, SCREEN_SIZE.x - PLAYER_MARGIN.x - 24.0),
		randf_range(PLAYER_MARGIN.y + 60.0, SCREEN_SIZE.y - PLAYER_MARGIN.y - 120.0)
	)
	collectible.modulate = Color(0.78, 0.95, 1.0, 1.0)
	collectibles_container.add_child(collectible)

func _spawn_meteor() -> void:
	var meteor := Sprite2D.new()
	meteor.texture = METEOR_TEXTURE
	meteor.scale = Vector2(0.9, 0.9)
	meteor.position = Vector2(
		randf_range(HAZARD_SPAWN_PADDING, SCREEN_SIZE.x - HAZARD_SPAWN_PADDING),
		-48.0
	)
	meteor.set_meta("velocity", Vector2(randf_range(-90.0, 90.0), randf_range(210.0, 360.0)))
	meteor.set_meta("spin_speed", randf_range(-2.5, 2.5))
	hazards_container.add_child(meteor)

func _spawn_ufo() -> void:
	var ufo := Sprite2D.new()
	ufo.texture = UFO_TEXTURE
	ufo.scale = Vector2(0.8, 0.8)

	var from_left := randf() < 0.5
	var start_x := -72.0 if from_left else SCREEN_SIZE.x + 72.0
	var target_velocity_x := randf_range(170.0, 290.0)
	if not from_left:
		target_velocity_x *= -1.0

	ufo.position = Vector2(start_x, randf_range(120.0, SCREEN_SIZE.y - 220.0))
	ufo.set_meta("velocity", Vector2(target_velocity_x, randf_range(-25.0, 25.0)))
	ufo.set_meta("spin_speed", 0.0)
	hazards_container.add_child(ufo)

func _set_game_over() -> void:
	_game_over = true
	hazard_timer.stop()
	star_timer.stop()
	_update_label()

func _update_label() -> void:
	var survival_seconds: float = snappedf(_survival_time, 0.1)
	if _game_over:
		info_label.text = "Resgate Estelar | Estrelas: %d | Tempo: %.1fs | Colisao! Enter reinicia | ESC menu" % [_score, survival_seconds]
	else:
		info_label.text = "Resgate Estelar | Estrelas: %d | Tempo: %.1fs | Colete estrelas e desvie dos inimigos | ESC menu" % [_score, survival_seconds]

func _build_background_stars() -> void:
	_background_stars.clear()
	for _i in range(55):
		var brightness := randf_range(0.45, 1.0)
		_background_stars.append({
			"position": Vector2(randf_range(0.0, SCREEN_SIZE.x), randf_range(0.0, SCREEN_SIZE.y)),
			"radius": randf_range(1.2, 2.8),
			"color": Color(0.55 * brightness, 0.78 * brightness, brightness, randf_range(0.4, 0.95))
		})
	queue_redraw()



func test():
	pass
func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

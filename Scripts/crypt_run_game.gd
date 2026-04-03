extends Node2D

const SCREEN_SIZE := Vector2(1152, 720)
const FLOOR_Y := 624.0
const FRAME_SIZE := Vector2i(32, 64)
const ACTOR_SCALE := Vector2(2.0, 2.0)
const ACTOR_HALF_HEIGHT := 64.0
const PLAYER_GROUND_Y := FLOOR_Y - ACTOR_HALF_HEIGHT
const PLAYER_SPEED := 250.0
const GRAVITY := 1700.0
const JUMP_VELOCITY := -760.0
const PLAYER_MAX_HP := 5
const ATTACK_DURATION := 0.24
const ATTACK_COOLDOWN := 0.42
const DAMAGE_COOLDOWN := 1.0
const ATTACK_RANGE := 108.0
const COLLISION_RANGE := 52.0

const PLAYER_SHEET := preload("res://Assets/Sprites/CryptRun/maleBase/maleBase/advnt_full.png")
const SKELETON_SHEET := preload("res://Assets/Sprites/CryptRun/skeletonBase.png")

@onready var enemies_container: Node2D = $Enemies
@onready var player_sprite: AnimatedSprite2D = $Player
@onready var enemy_timer: Timer = $EnemyTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _player_frames: SpriteFrames
var _skeleton_frames: SpriteFrames
var _player_velocity: Vector2 = Vector2.ZERO
var _facing := 1
var _score := 0
var _survival_time := 0.0
var _player_hp := PLAYER_MAX_HP
var _attack_time_left := 0.0
var _attack_cooldown_left := 0.0
var _damage_cooldown_left := 0.0
var _game_over := false
var _background_stars: Array[Dictionary] = []

func _ready() -> void:
	seed(Time.get_unix_time_from_system())
	_player_frames = _build_player_frames()
	_skeleton_frames = _build_skeleton_frames()
	_build_background()
	_configure_player()
	_reset_game()
	enemy_timer.timeout.connect(_on_enemy_timer_timeout)
	enemy_timer.start()

func _physics_process(delta: float) -> void:
	if _game_over:
		_update_enemy_animation()
		return

	_survival_time += delta
	_attack_time_left = max(0.0, _attack_time_left - delta)
	_attack_cooldown_left = max(0.0, _attack_cooldown_left - delta)
	_damage_cooldown_left = max(0.0, _damage_cooldown_left - delta)

	_handle_player_input(delta)
	_update_player_motion(delta)
	_update_enemies(delta)
	_resolve_player_attack()
	_check_enemy_hits()
	_cleanup_enemies()
	_update_player_animation()
	_update_enemy_animation()
	_update_label()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.06, 0.07, 0.14))
	draw_circle(Vector2(970, 120), 62.0, Color(0.95, 0.96, 1.0, 0.14))

	for star in _background_stars:
		draw_circle(star["position"], star["radius"], star["color"])

	draw_rect(Rect2(0, FLOOR_Y - 26.0, SCREEN_SIZE.x, 34.0), Color(0.12, 0.15, 0.21))
	draw_rect(Rect2(0, FLOOR_Y + 8.0, SCREEN_SIZE.x, SCREEN_SIZE.y - FLOOR_Y), Color(0.08, 0.1, 0.08))

	for i in range(10):
		var x := 32.0 + float(i) * 118.0
		draw_line(Vector2(x, FLOOR_Y - 18.0), Vector2(x + 24.0, FLOOR_Y - 64.0), Color(0.18, 0.2, 0.26), 5.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _game_over and event.is_action_pressed("ui_accept"):
		_reset_game()
		return

	if event.is_action_pressed("ui_up") and _is_on_floor() and not _game_over:
		_player_velocity.y = JUMP_VELOCITY

	if event.is_action_pressed("ui_accept") and not _game_over and _attack_cooldown_left <= 0.0:
		_attack_time_left = ATTACK_DURATION
		_attack_cooldown_left = ATTACK_COOLDOWN
		player_sprite.play("attack")

func _handle_player_input(delta: float) -> void:
	var horizontal := Input.get_axis("ui_left", "ui_right")
	_player_velocity.x = horizontal * PLAYER_SPEED
	player_sprite.position.x += _player_velocity.x * delta
	player_sprite.position.x = clamp(player_sprite.position.x, 48.0, SCREEN_SIZE.x - 48.0)

	if horizontal > 0.0:
		_facing = 1
	elif horizontal < 0.0:
		_facing = -1

	player_sprite.flip_h = _facing < 0

func _update_player_motion(delta: float) -> void:
	_player_velocity.y += GRAVITY * delta
	player_sprite.position.y += _player_velocity.y * delta

	if player_sprite.position.y >= PLAYER_GROUND_Y:
		player_sprite.position.y = PLAYER_GROUND_Y
		_player_velocity.y = 0.0

func _update_enemies(delta: float) -> void:
	for child in enemies_container.get_children():
		var enemy := child as AnimatedSprite2D
		if enemy == null:
			continue

		var speed: float = float(enemy.get_meta("speed"))
		var direction := signf(player_sprite.position.x - enemy.position.x)
		if direction == 0.0:
			direction = float(enemy.get_meta("direction"))

		enemy.position.x += direction * speed * delta
		enemy.position.x = clamp(enemy.position.x, 24.0, SCREEN_SIZE.x - 24.0)
		enemy.set_meta("direction", direction)
		enemy.flip_h = direction > 0.0

func _resolve_player_attack() -> void:
	if _attack_time_left <= 0.0:
		return

	for child in enemies_container.get_children():
		var enemy := child as AnimatedSprite2D
		if enemy == null:
			continue

		var offset_x := enemy.position.x - player_sprite.position.x
		var in_front := offset_x * float(_facing) > -8.0
		var close_enough := enemy.position.distance_to(player_sprite.position) <= ATTACK_RANGE
		if in_front and close_enough:
			_score += 10
			enemy.queue_free()

func _check_enemy_hits() -> void:
	if _damage_cooldown_left > 0.0:
		return

	for child in enemies_container.get_children():
		var enemy := child as AnimatedSprite2D
		if enemy == null:
			continue

		if enemy.position.distance_to(player_sprite.position) <= COLLISION_RANGE:
			_player_hp -= 1
			_damage_cooldown_left = DAMAGE_COOLDOWN
			enemy.queue_free()
			if _player_hp <= 0:
				_set_game_over()
			return

func _cleanup_enemies() -> void:
	for child in enemies_container.get_children():
		var enemy := child as AnimatedSprite2D
		if enemy == null:
			continue

		if enemy.position.x < -96.0 or enemy.position.x > SCREEN_SIZE.x + 96.0:
			enemy.queue_free()

func _update_player_animation() -> void:
	if _attack_time_left > 0.0:
		if player_sprite.animation != "attack":
			player_sprite.play("attack")
		return

	if not _is_on_floor():
		if player_sprite.animation != "jump":
			player_sprite.play("jump")
		return

	if absf(_player_velocity.x) > 8.0:
		if player_sprite.animation != "run":
			player_sprite.play("run")
	else:
		if player_sprite.animation != "idle":
			player_sprite.play("idle")

func _update_enemy_animation() -> void:
	for child in enemies_container.get_children():
		var enemy := child as AnimatedSprite2D
		if enemy == null:
			continue

		var distance := enemy.position.distance_to(player_sprite.position)
		if distance <= 78.0 and not _game_over:
			if enemy.animation != "attack":
				enemy.play("attack")
		elif enemy.animation != "run":
			enemy.play("run")

func _on_enemy_timer_timeout() -> void:
	if _game_over:
		return

	var enemy := AnimatedSprite2D.new()
	enemy.sprite_frames = _skeleton_frames
	enemy.scale = ACTOR_SCALE
	enemy.play("run")
	enemy.position.y = PLAYER_GROUND_Y

	var spawn_left := randf() < 0.5
	enemy.position.x = -32.0 if spawn_left else SCREEN_SIZE.x + 32.0
	enemy.set_meta("direction", 1.0 if spawn_left else -1.0)
	enemy.set_meta("speed", randf_range(90.0, 150.0))
	enemy.flip_h = spawn_left
	enemies_container.add_child(enemy)

	enemy_timer.wait_time = max(0.48, enemy_timer.wait_time - 0.025)

func _configure_player() -> void:
	player_sprite.sprite_frames = _player_frames
	player_sprite.scale = ACTOR_SCALE
	player_sprite.play("idle")

func _reset_game() -> void:
	_game_over = false
	_score = 0
	_survival_time = 0.0
	_player_hp = PLAYER_MAX_HP
	_attack_time_left = 0.0
	_attack_cooldown_left = 0.0
	_damage_cooldown_left = 0.0
	_player_velocity = Vector2.ZERO
	_facing = 1
	enemy_timer.wait_time = 1.35

	for child in enemies_container.get_children():
		child.queue_free()

	player_sprite.position = Vector2(SCREEN_SIZE.x * 0.5, PLAYER_GROUND_Y)
	player_sprite.flip_h = false
	player_sprite.play("idle")
	enemy_timer.start()
	_update_label()

func _set_game_over() -> void:
	_game_over = true
	enemy_timer.stop()
	player_sprite.play("idle")
	_update_label()

func _update_label() -> void:
	var survival_seconds: float = snappedf(_survival_time, 0.1)
	if _game_over:
		info_label.text = "Corrida da Cripta | Vida: 0 | Pontos: %d | Tempo: %.1fs | Enter reinicia | ESC menu" % [_score, survival_seconds]
	else:
		info_label.text = "Corrida da Cripta | Vida: %d | Pontos: %d | Tempo: %.1fs | Setas movem, cima pula, Enter ataca" % [_player_hp, _score, survival_seconds]

func _build_background() -> void:
	_background_stars.clear()
	for _i in range(42):
		var brightness := randf_range(0.5, 1.0)
		_background_stars.append({
			"position": Vector2(randf_range(0.0, SCREEN_SIZE.x), randf_range(0.0, FLOOR_Y - 90.0)),
			"radius": randf_range(1.1, 2.6),
			"color": Color(0.65 * brightness, 0.72 * brightness, brightness, randf_range(0.35, 0.85))
		})
	queue_redraw()

func _build_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_animation(frames, "idle", PLAYER_SHEET, [Vector2i(0, 0)], 2.0, true)
	_add_animation(frames, "run", PLAYER_SHEET, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)], 10.0, true)
	_add_animation(frames, "jump", PLAYER_SHEET, [Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1)], 7.0, false)
	_add_animation(frames, "attack", PLAYER_SHEET, [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)], 12.0, false)
	return frames

func _build_skeleton_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_animation(frames, "idle", SKELETON_SHEET, [Vector2i(0, 0)], 2.0, true)
	_add_animation(frames, "run", SKELETON_SHEET, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)], 10.0, true)
	_add_animation(frames, "attack", SKELETON_SHEET, [Vector2i(7, 2), Vector2i(8, 2)], 8.0, true)
	return frames

func _add_animation(sprite_frames: SpriteFrames, animation_name: StringName, sheet: Texture2D, frame_cells: Array[Vector2i], fps: float, looped: bool) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, looped)

	for cell in frame_cells:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(
			Vector2(cell.x * FRAME_SIZE.x, cell.y * FRAME_SIZE.y),
			Vector2(FRAME_SIZE.x, FRAME_SIZE.y)
		)
		sprite_frames.add_frame(animation_name, frame)

func _is_on_floor() -> bool:
	return is_equal_approx(player_sprite.position.y, PLAYER_GROUND_Y)

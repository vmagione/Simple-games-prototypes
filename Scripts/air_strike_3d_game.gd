extends Node3D

const PLAY_MIN_X := -14.0
const PLAY_MAX_X := 14.0
const ENEMY_SPAWN_Z := -30.0
const ENEMY_DESPAWN_Z := 16.0
const PLAYER_Z := 11.0
const PLAYER_SPEED := 16.0
const BULLET_SPEED := 30.0
const ENEMY_SPEED_MIN := 7.0
const ENEMY_SPEED_MAX := 12.5
const SHOOT_COOLDOWN := 0.22

@onready var player_container: Node3D = $PlayerContainer
@onready var enemies_container: Node3D = $Enemies
@onready var bullets_container: Node3D = $Bullets
@onready var spawn_timer: Timer = $SpawnTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel

var _player: Area3D
var _player_body: MeshInstance3D
var _bullets: Array[Area3D] = []
var _enemies: Array[Area3D] = []
var _rng := RandomNumberGenerator.new()
var _shoot_timer := 0.0
var _score := 0
var _game_over := false

func _ready() -> void:
	_rng.randomize()
	_create_player()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_reset_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if _game_over and event.is_action_pressed("ui_accept"):
		_reset_game()

func _process(delta: float) -> void:
	if _game_over:
		_update_label()
		return

	_shoot_timer = max(0.0, _shoot_timer - delta)
	_update_player(delta)
	_update_bullets(delta)
	_update_enemies(delta)
	_handle_collisions()
	_update_label()

func _create_player() -> void:
	_player = Area3D.new()
	player_container.add_child(_player)

	var collision_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 2.2
	collision_shape.shape = capsule
	collision_shape.rotation_degrees.x = 90
	_player.add_child(collision_shape)

	_player_body = _make_mesh_instance(BoxMesh.new(), Color(0.2, 0.8, 1.0), Vector3(1.1, 0.55, 2.2))
	_player.add_child(_player_body)

	var wing_left := _make_mesh_instance(BoxMesh.new(), Color(0.15, 0.58, 0.86), Vector3(1.3, 0.2, 0.45))
	wing_left.position = Vector3(-1.25, 0.0, 0.05)
	_player.add_child(wing_left)

	var wing_right := _make_mesh_instance(BoxMesh.new(), Color(0.15, 0.58, 0.86), Vector3(1.3, 0.2, 0.45))
	wing_right.position = Vector3(1.25, 0.0, 0.05)
	_player.add_child(wing_right)

	var nose := _make_mesh_instance(CylinderMesh.new(), Color(0.95, 0.95, 1.0), Vector3(0.32, 0.48, 0.32))
	nose.position = Vector3(0.0, 0.0, -1.55)
	nose.rotation_degrees.x = 90
	_player.add_child(nose)

func _update_player(delta: float) -> void:
	var direction := 0.0
	if Input.is_action_pressed("ui_left"):
		direction -= 1.0
	if Input.is_action_pressed("ui_right"):
		direction += 1.0

	_player.position.x = clamp(_player.position.x + direction * PLAYER_SPEED * delta, PLAY_MIN_X, PLAY_MAX_X)
	_player.position.z = PLAYER_Z

	if Input.is_action_pressed("ui_accept") and _shoot_timer == 0.0:
		_spawn_bullet()
		_shoot_timer = SHOOT_COOLDOWN

func _spawn_bullet() -> void:
	var bullet := Area3D.new()
	bullets_container.add_child(bullet)

	var collision_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.32
	collision_shape.shape = sphere
	bullet.add_child(collision_shape)

	var mesh := _make_mesh_instance(SphereMesh.new(), Color(1.0, 0.9, 0.2), Vector3(0.34, 0.34, 0.34))
	bullet.add_child(mesh)

	bullet.position = _player.position + Vector3(0.0, 0.0, -1.8)
	_bullets.append(bullet)

func _spawn_enemy() -> void:
	var enemy := Area3D.new()
	enemies_container.add_child(enemy)

	var collision_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 0.9, 2.1)
	collision_shape.shape = box
	enemy.add_child(collision_shape)

	var hull := _make_mesh_instance(BoxMesh.new(), Color(0.93, 0.25, 0.25), Vector3(1.15, 0.52, 1.3))
	enemy.add_child(hull)

	var wing_left := _make_mesh_instance(BoxMesh.new(), Color(0.75, 0.12, 0.12), Vector3(0.9, 0.18, 0.4))
	wing_left.position = Vector3(-0.95, 0.0, 0.0)
	enemy.add_child(wing_left)

	var wing_right := _make_mesh_instance(BoxMesh.new(), Color(0.75, 0.12, 0.12), Vector3(0.9, 0.18, 0.4))
	wing_right.position = Vector3(0.95, 0.0, 0.0)
	enemy.add_child(wing_right)

	var cockpit := _make_mesh_instance(SphereMesh.new(), Color(1.0, 0.55, 0.2), Vector3(0.35, 0.28, 0.38))
	cockpit.position = Vector3(0.0, 0.25, -0.25)
	enemy.add_child(cockpit)

	enemy.position = Vector3(_rng.randf_range(PLAY_MIN_X, PLAY_MAX_X), 0.0, ENEMY_SPAWN_Z)
	enemy.set_meta("speed", _rng.randf_range(ENEMY_SPEED_MIN, ENEMY_SPEED_MAX))
	_enemies.append(enemy)

func _update_bullets(delta: float) -> void:
	for bullet in _bullets.duplicate():
		bullet.position.z -= BULLET_SPEED * delta
		if bullet.position.z < ENEMY_SPAWN_Z - 4.0:
			_bullets.erase(bullet)
			bullet.queue_free()

func _update_enemies(delta: float) -> void:
	for enemy in _enemies.duplicate():
		enemy.position.z += float(enemy.get_meta("speed")) * delta
		if enemy.position.z > ENEMY_DESPAWN_Z:
			_set_game_over()
			return

func _handle_collisions() -> void:
	for enemy in _enemies.duplicate():
		if enemy.position.distance_to(_player.position) < 1.7:
			_set_game_over()
			return

		for bullet in _bullets.duplicate():
			if enemy.position.distance_to(bullet.position) < 1.4:
				_score += 1
				_bullets.erase(bullet)
				_enemies.erase(enemy)
				bullet.queue_free()
				enemy.queue_free()
				break

func _on_spawn_timer_timeout() -> void:
	if _game_over:
		return
	_spawn_enemy()
	spawn_timer.wait_time = max(0.34, spawn_timer.wait_time - 0.003)

func _set_game_over() -> void:
	_game_over = true
	spawn_timer.stop()
	_player_body.material_override = _create_material(Color(0.9, 0.25, 0.25))

func _reset_game() -> void:
	_game_over = false
	_score = 0
	_shoot_timer = 0.0
	spawn_timer.wait_time = 0.95

	for bullet in _bullets:
		bullet.queue_free()
	_bullets.clear()

	for enemy in _enemies:
		enemy.queue_free()
	_enemies.clear()

	_player.position = Vector3.ZERO
	_player.position.z = PLAYER_Z
	_player_body.material_override = _create_material(Color(0.2, 0.8, 1.0))

	spawn_timer.start()
	_update_label()

func _update_label() -> void:
	if _game_over:
		info_label.text = "Sky Raid 3D | Pontos: %d | Fim de jogo! Enter reinicia | ESC menu" % _score
	else:
		info_label.text = "Sky Raid 3D | Pontos: %d | ←/→ move | Espaço atira | ESC menu" % _score

func _make_mesh_instance(mesh: Mesh, color: Color, scale_value: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.scale = scale_value
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

func _create_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.56
	material.metallic = 0.08
	return material

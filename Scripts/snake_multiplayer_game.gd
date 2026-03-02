extends Node2D

const GRID_SIZE := 24
const GRID_WIDTH := 48
const GRID_HEIGHT := 30
const GAME_PORT := 42345
const DISCOVERY_PORT := 42346
const MAX_CLIENTS := 12
const DISCOVER_REQUEST := "SNAKE_DISCOVER"

@onready var wall_container: Node2D = $Walls
@onready var snakes_container: Node2D = $Snakes
@onready var food_container: Node2D = $Food
@onready var tick_timer: Timer = $TickTimer
@onready var info_label: Label = $CanvasLayer/InfoLabel
@onready var lobby_panel: Panel = $CanvasLayer/LobbyPanel
@onready var room_list: ItemList = $CanvasLayer/LobbyPanel/MarginContainer/VBoxContainer/RoomList
@onready var room_code_line: LineEdit = $CanvasLayer/LobbyPanel/MarginContainer/VBoxContainer/RoomCodeLine
@onready var status_label: Label = $CanvasLayer/LobbyPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var refresh_button: Button = $CanvasLayer/LobbyPanel/MarginContainer/VBoxContainer/ButtonRow/RefreshButton
@onready var create_button: Button = $CanvasLayer/LobbyPanel/MarginContainer/VBoxContainer/ButtonRow/CreateButton
@onready var join_button: Button = $CanvasLayer/LobbyPanel/MarginContainer/VBoxContainer/ButtonRow/JoinButton

var _square_texture: Texture2D
var _is_host := false
var _room_code := ""
var _my_peer_id := 1
var _snakes: Dictionary = {}
var _directions: Dictionary = {}
var _next_directions: Dictionary = {}
var _pending_growth: Dictionary = {}
var _scores: Dictionary = {}
var _alive: Dictionary = {}
var _foods: Array[Vector2i] = []
var _player_colors: Dictionary = {}
var _known_rooms: Array[Dictionary] = []

var _discovery_sender := PacketPeerUDP.new()
var _discovery_listener := PacketPeerUDP.new()

func _ready() -> void:
	_square_texture = preload("res://Assets/Sprites/Square.png")
	_randomize_seed()
	_draw_walls()
	_clear_board()
	_configure_discovery_listener()
	refresh_button.pressed.connect(_refresh_rooms)
	create_button.pressed.connect(_create_room)
	join_button.pressed.connect(_join_by_code)
	room_list.item_activated.connect(_on_room_activated)
	tick_timer.timeout.connect(_on_server_tick)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_refresh_rooms()

func _process(_delta: float) -> void:
	_poll_discovery_packets()
	if _is_host:
		_advertise_room_if_requested()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave_room_if_needed()
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	if lobby_panel.visible:
		return

	if event.is_action_pressed("ui_up"):
		_send_direction(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_send_direction(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		_send_direction(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		_send_direction(Vector2i.RIGHT)

func _send_direction(dir: Vector2i) -> void:
	if _is_host:
		_server_set_direction(_my_peer_id, dir)
	elif multiplayer.multiplayer_peer != null:
		rpc_id(1, "server_set_direction", dir)

func _refresh_rooms() -> void:
	_known_rooms.clear()
	_rebuild_room_list()
	status_label.text = "Buscando salas na rede local..."
	_discovery_sender.close()
	var bind_error := _discovery_sender.bind(0)
	if bind_error != OK:
		status_label.text = "Não foi possível procurar salas (erro %d)." % bind_error
		return
	_discovery_sender.set_broadcast_enabled(true)
	_discovery_sender.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_discovery_sender.put_packet(DISCOVER_REQUEST.to_utf8_buffer())

func _create_room() -> void:
	_leave_room_if_needed()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(GAME_PORT, MAX_CLIENTS)
	if error != OK:
		status_label.text = "Falha ao criar sala. Porta %d ocupada? (erro %d)" % [GAME_PORT, error]
		return

	_room_code = _generate_room_code()
	_is_host = true
	multiplayer.multiplayer_peer = peer
	_my_peer_id = multiplayer.get_unique_id()
	_setup_host_state()
	_start_match_ui()
	status_label.text = "Sala criada! Código: %s" % _room_code

func _join_by_code() -> void:
	var target_code := room_code_line.text.strip_edges().to_upper()
	if target_code.is_empty():
		status_label.text = "Digite o código da sala para entrar."
		return

	for room in _known_rooms:
		if room.get("code", "") == target_code:
			_join_room(room)
			return

	status_label.text = "Sala %s não encontrada. Atualize a lista." % target_code

func _on_room_activated(index: int) -> void:
	if index < 0 or index >= _known_rooms.size():
		return
	_join_room(_known_rooms[index])

func _join_room(room: Dictionary) -> void:
	_leave_room_if_needed()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(room.get("ip", ""), int(room.get("port", GAME_PORT)))
	if error != OK:
		status_label.text = "Falha ao entrar na sala (erro %d)." % error
		return

	_room_code = room.get("code", "")
	_is_host = false
	multiplayer.multiplayer_peer = peer
	status_label.text = "Conectando na sala %s..." % _room_code

func _on_connected_to_server() -> void:
	_my_peer_id = multiplayer.get_unique_id()
	_start_match_ui()
	status_label.text = "Conectado! Sala %s" % _room_code

func _on_connection_failed() -> void:
	status_label.text = "Falha na conexão com a sala."
	_leave_room_if_needed()

func _on_server_disconnected() -> void:
	status_label.text = "Conexão encerrada."
	_leave_room_if_needed()

func _on_peer_connected(peer_id: int) -> void:
	if not _is_host:
		return
	_spawn_player(peer_id)
	_sync_state_to_clients()

func _on_peer_disconnected(peer_id: int) -> void:
	_snakes.erase(peer_id)
	_directions.erase(peer_id)
	_next_directions.erase(peer_id)
	_pending_growth.erase(peer_id)
	_scores.erase(peer_id)
	_alive.erase(peer_id)
	_player_colors.erase(peer_id)
	if _is_host:
		_ensure_food_count()
		_sync_state_to_clients()

func _setup_host_state() -> void:
	_snakes.clear()
	_directions.clear()
	_next_directions.clear()
	_pending_growth.clear()
	_scores.clear()
	_alive.clear()
	_player_colors.clear()
	_foods.clear()
	_spawn_player(_my_peer_id)
	_ensure_food_count()
	_sync_state_to_clients()
	tick_timer.start()

func _spawn_player(peer_id: int) -> void:
	var spawn := _find_free_spawn_cell()
	_snakes[peer_id] = [spawn, spawn + Vector2i.LEFT, spawn + Vector2i.LEFT * 2]
	_directions[peer_id] = Vector2i.RIGHT
	_next_directions[peer_id] = Vector2i.RIGHT
	_pending_growth[peer_id] = 0
	_scores[peer_id] = 0
	_alive[peer_id] = true
	_player_colors[peer_id] = Color.from_hsv(float(peer_id % 10) / 10.0, 0.9, 0.95)

func _find_free_spawn_cell() -> Vector2i:
	for _attempt in 32:
		var candidate := Vector2i(randi_range(3, GRID_WIDTH - 4), randi_range(3, GRID_HEIGHT - 4))
		if _is_cell_free(candidate):
			return candidate
	return Vector2i(4, 4)

func _is_cell_free(cell: Vector2i) -> bool:
	for snake in _snakes.values():
		if (snake as Array).has(cell):
			return false
	return not _foods.has(cell)

func _on_server_tick() -> void:
	if not _is_host:
		return

	var planned_heads: Dictionary = {}
	for peer_id in _snakes.keys():
		if not _alive.get(peer_id, false):
			continue
		var current_dir: Vector2i = _directions[peer_id]
		var wanted_dir: Vector2i = _next_directions[peer_id]
		if wanted_dir + current_dir != Vector2i.ZERO:
			_directions[peer_id] = wanted_dir
		planned_heads[peer_id] = (_snakes[peer_id] as Array[Vector2i])[0] + _directions[peer_id]

	var occupied := {}
	for pid in _snakes.keys():
		for segment in _snakes[pid]:
			occupied[segment] = true

	var head_counts := {}
	for head in planned_heads.values():
		head_counts[head] = int(head_counts.get(head, 0)) + 1

	for peer_id in planned_heads.keys():
		var head: Vector2i = planned_heads[peer_id]
		var dead := _hits_wall(head) or occupied.has(head) or int(head_counts.get(head, 0)) > 1
		if dead:
			_alive[peer_id] = false
			continue

		var snake = _snakes[peer_id] as Array[Vector2i]
		snake.push_front(head)
		var ate_food := false
		for food_index in _foods.size():
			if _foods[food_index] == head:
				ate_food = true
				_foods.remove_at(food_index)
				break

		if ate_food:
			_scores[peer_id] = int(_scores.get(peer_id, 0)) + 1
			_pending_growth[peer_id] = int(_pending_growth.get(peer_id, 0)) + 1

		if int(_pending_growth.get(peer_id, 0)) > 0:
			_pending_growth[peer_id] = int(_pending_growth.get(peer_id, 0)) - 1
		else:
			snake.pop_back()
		_snakes[peer_id] = snake

	_ensure_food_count()
	_sync_state_to_clients()

func _ensure_food_count() -> void:
	var target_food_count = max(_snakes.size(), 1)
	while _foods.size() < target_food_count:
		_spawn_food()
	while _foods.size() > target_food_count:
		_foods.pop_back()

func _spawn_food() -> void:
	for _attempt in 200:
		var candidate := Vector2i(randi_range(1, GRID_WIDTH - 2), randi_range(1, GRID_HEIGHT - 2))
		if _is_cell_free(candidate):
			_foods.append(candidate)
			return

func _hits_wall(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.x >= GRID_WIDTH - 1 or cell.y <= 0 or cell.y >= GRID_HEIGHT - 1

func _sync_state_to_clients() -> void:
	var payload := {
		"snakes": _snakes,
		"foods": _foods,
		"scores": _scores,
		"alive": _alive,
		"colors": _player_colors
	}
	_apply_state(payload)
	rpc("client_receive_state", payload)

@rpc("any_peer", "reliable")
func server_set_direction(direction: Vector2i) -> void:
	_server_set_direction(multiplayer.get_remote_sender_id(), direction)

func _server_set_direction(peer_id: int, direction: Vector2i) -> void:
	if not _next_directions.has(peer_id):
		return
	var current_dir: Vector2i = _directions.get(peer_id, Vector2i.RIGHT)
	if direction + current_dir == Vector2i.ZERO:
		return
	_next_directions[peer_id] = direction

@rpc("authority", "unreliable")
func client_receive_state(payload: Dictionary) -> void:
	_apply_state(payload)

func _apply_state(payload: Dictionary) -> void:
	_snakes = payload.get("snakes", {})
	_foods = payload.get("foods", [])
	_scores = payload.get("scores", {})
	_alive = payload.get("alive", {})
	_player_colors = payload.get("colors", {})
	_render_snakes()
	_render_foods()
	_update_info_label()

func _start_match_ui() -> void:
	lobby_panel.visible = false
	room_code_line.clear()
	_update_info_label()

func _leave_room_if_needed() -> void:
	if tick_timer.time_left > 0.0:
		tick_timer.stop()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_is_host = false
	_room_code = ""
	_snakes.clear()
	_foods.clear()
	_clear_board()
	lobby_panel.visible = true

func _clear_board() -> void:
	for child in snakes_container.get_children():
		child.queue_free()
	for child in food_container.get_children():
		child.queue_free()
	info_label.text = "Snake Multiplayer | ESC para voltar ao menu"

func _draw_walls() -> void:
	for child in wall_container.get_children():
		child.queue_free()
	for x in GRID_WIDTH:
		_add_square(wall_container, Vector2i(x, 0), Color.WHITE)
		_add_square(wall_container, Vector2i(x, GRID_HEIGHT - 1), Color.WHITE)
	for y in GRID_HEIGHT:
		_add_square(wall_container, Vector2i(0, y), Color.WHITE)
		_add_square(wall_container, Vector2i(GRID_WIDTH - 1, y), Color.WHITE)

func _render_snakes() -> void:
	for child in snakes_container.get_children():
		child.queue_free()

	for peer_id in _snakes.keys():
		var snake: Array = _snakes[peer_id]
		var base_color: Color = _player_colors.get(peer_id, Color(0.2, 0.9, 0.2))
		for index in snake.size():
			var color := base_color
			if index == 0:
				color = color.lightened(0.25)
			if not _alive.get(peer_id, false):
				color = Color(0.4, 0.4, 0.4)
			_add_square(snakes_container, snake[index], color)

func _render_foods() -> void:
	for child in food_container.get_children():
		child.queue_free()
	for food in _foods:
		var sprite := _add_square(food_container, food, Color(0.95, 0.15, 0.15, 1.0))
		sprite.scale = Vector2(0.55, 0.55)

func _update_info_label() -> void:
	if lobby_panel.visible:
		info_label.text = "Snake Multiplayer | escolha/crie uma sala"
		return
	var score_parts: Array[String] = []
	for peer_id in _scores.keys():
		var status := "vivo"
		if not _alive.get(peer_id, false):
			status = "morto"
		score_parts.append("P%s: %d (%s)" % [str(peer_id), int(_scores[peer_id]), status])
	info_label.text = "Sala %s | %s | ESC para menu" % [_room_code, "  ".join(score_parts)]

func _add_square(parent: Node2D, cell: Vector2i, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _square_texture
	sprite.modulate = color
	sprite.position = Vector2(cell * GRID_SIZE) + Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
	parent.add_child(sprite)
	return sprite

func _rebuild_room_list() -> void:
	room_list.clear()
	for room in _known_rooms:
		room_list.add_item("%s  |  Código: %s  |  %s" % [room.get("name", "Sala"), room.get("code", "----"), room.get("ip", "")])

func _configure_discovery_listener() -> void:
	_discovery_listener.close()
	var error := _discovery_listener.bind(DISCOVERY_PORT)
	if error != OK:
		status_label.text = "Aviso: descoberta LAN indisponível (erro %d)." % error

func _poll_discovery_packets() -> void:
	while _discovery_listener.get_available_packet_count() > 0:
		var packet := _discovery_listener.get_packet().get_string_from_utf8()
		var sender_ip := _discovery_listener.get_packet_ip()
		if packet == DISCOVER_REQUEST and _is_host:
			var response := JSON.stringify({
				"type": "room",
				"name": "Sala %s" % _room_code,
				"code": _room_code,
				"ip": _get_local_ipv4(),
				"port": GAME_PORT
			})
			_discovery_listener.set_dest_address(sender_ip, _discovery_listener.get_packet_port())
			_discovery_listener.put_packet(response.to_utf8_buffer())
		elif packet.begins_with("{"):
			var parsed = JSON.parse_string(packet)
			if typeof(parsed) == TYPE_DICTIONARY and parsed.get("type", "") == "room":
				_register_room(parsed)

func _register_room(room: Dictionary) -> void:
	for existing in _known_rooms:
		if existing.get("code", "") == room.get("code", ""):
			return
	_known_rooms.append(room)
	_rebuild_room_list()
	status_label.text = "%d sala(s) encontrada(s)." % _known_rooms.size()

func _advertise_room_if_requested() -> void:
	# Placeholder para manter host apto a responder pacotes LAN em _poll_discovery_packets.
	pass

func _generate_room_code() -> String:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for _i in 6:
		code += letters[randi_range(0, letters.length() - 1)]
	return code

func _randomize_seed() -> void:
	seed(Time.get_unix_time_from_system())

func _get_local_ipv4() -> String:
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127."):
			return address
	return "127.0.0.1"

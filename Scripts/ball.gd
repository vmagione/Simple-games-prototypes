extends RigidBody2D

@export var serve_speed: float = 560.0
@export var speed_increment: float = 45.0
@export var max_speed: float = 920.0

var _start_position: Vector2
var _current_speed: float
var _active_contacts: Dictionary = {}
var _is_in_play := false

func _ready() -> void:
	_start_position = global_position
	_current_speed = serve_speed
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	sleeping = false

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_track_contacts(state)

	if not _is_in_play:
		return

	var speed := state.linear_velocity.length()
	if speed <= 0.001:
		return

	if speed < _current_speed:
		state.linear_velocity = state.linear_velocity.normalized() * _current_speed
	elif speed > max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed

func reset_ball(direction: float, launch: bool = true) -> void:
	global_position = _start_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_current_speed = serve_speed
	_active_contacts.clear()
	_is_in_play = false
	sleeping = false

	if launch:
		_launch(direction)

func is_in_play() -> bool:
	return _is_in_play and linear_velocity.length() > 0.001

func _launch(direction: float) -> void:
	var dir := Vector2(direction, randf_range(-0.65, 0.65)).normalized()
	linear_velocity = dir * _current_speed
	_is_in_play = true
	sleeping = false

func _track_contacts(state: PhysicsDirectBodyState2D) -> void:
	var frame_contacts: Dictionary = {}

	for i in range(state.get_contact_count()):
		var collider = state.get_contact_collider_object(i)
		if not (collider is Node):
			continue

		var collider_node := collider as Node
		if collider_node.is_in_group("goal_left") or collider_node.is_in_group("goal_right"):
			continue

		var collider_id := collider_node.get_instance_id()
		frame_contacts[collider_id] = true

		if _is_in_play and not _active_contacts.has(collider_id):
			_increase_speed(state)

	_active_contacts = frame_contacts

func _increase_speed(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.is_zero_approx():
		return

	_current_speed = minf(_current_speed + speed_increment, max_speed)
	state.linear_velocity = state.linear_velocity.normalized() * _current_speed

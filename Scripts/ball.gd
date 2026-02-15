extends RigidBody2D

@export var serve_speed: float = 560.0
@export var speed_increment: float = 45.0
@export var max_speed: float = 920.0

var _start_position: Vector2
var _current_speed: float
var _active_paddle_contacts: Dictionary = {}

func _ready() -> void:
	_start_position = global_position
	_current_speed = serve_speed
	contact_monitor = true
	max_contacts_reported = 8

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_track_paddle_contacts(state)

	if state.linear_velocity.length() > max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed

func reset_ball(direction: float, launch: bool = true) -> void:
	global_position = _start_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_current_speed = serve_speed
	_active_paddle_contacts.clear()

	if launch:
		_launch(direction)

func _launch(direction: float) -> void:
	var dir := Vector2(direction, randf_range(-0.65, 0.65)).normalized()
	apply_central_impulse(dir * _current_speed)

func _track_paddle_contacts(state: PhysicsDirectBodyState2D) -> void:
	var frame_contacts: Dictionary = {}

	for i in range(state.get_contact_count()):
		var collider = state.get_contact_collider_object(i)
		if collider is Node and collider.is_in_group("paddle"):
			var collider_id := collider.get_instance_id()
			frame_contacts[collider_id] = true
			if not _active_paddle_contacts.has(collider_id):
				_increase_speed(state)

	_active_paddle_contacts = frame_contacts

func _increase_speed(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.is_zero_approx():
		return

	_current_speed = minf(_current_speed + speed_increment, max_speed)
	state.linear_velocity = state.linear_velocity.normalized() * _current_speed


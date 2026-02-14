extends RigidBody2D

signal goal_scored(player: int)

@export var serve_speed: float = 560.0
@export var max_speed: float = 920.0

var _start_position: Vector2

func _ready() -> void:
	_start_position = global_position
	contact_monitor = true
	max_contacts_reported = 4

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length() > max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed

func reset_ball(direction: float) -> void:
	global_position = _start_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	var dir := Vector2(direction, randf_range(-0.65, 0.65)).normalized()
	apply_central_impulse(dir * serve_speed)

func _on_goal_detector_area_entered(area: Area2D) -> void:
	if area.is_in_group("goal_left"):
		goal_scored.emit(2)
	elif area.is_in_group("goal_right"):
		goal_scored.emit(1)

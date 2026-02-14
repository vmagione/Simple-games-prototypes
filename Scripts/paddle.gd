extends CharacterBody2D

@export var up_action: StringName
@export var down_action: StringName
@export var speed: float = 520.0
@export var top_limit: float = 48.0
@export var bottom_limit: float = 672.0

var _start_position: Vector2

func _ready() -> void:
	_start_position = global_position

func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_axis(up_action, down_action)
	velocity = Vector2(0.0, input_dir * speed)
	move_and_slide()
	global_position.y = clampf(global_position.y, top_limit, bottom_limit)

func reset_position() -> void:
	global_position = _start_position
	velocity = Vector2.ZERO

extends Node2D

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var left_paddle = $LeftPaddle
@onready var right_paddle = $RightPaddle
@onready var ball = $Ball
@onready var left_goal = $LeftGoal
@onready var right_goal = $RightGoal

var _left_score := 0
var _right_score := 0
var _serve_to_right := true

func _ready() -> void:
	left_goal.body_entered.connect(_on_left_goal_body_entered)
	right_goal.body_entered.connect(_on_right_goal_body_entered)
	_serve_to_right = randf() > 0.5
	_update_score()
	_prepare_round(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not ball.is_in_play():
		_prepare_round(true)

func _on_left_goal_body_entered(body: Node) -> void:
	if body == ball and ball.is_in_play():
		_on_goal_scored(2)

func _on_right_goal_body_entered(body: Node) -> void:
	if body == ball and ball.is_in_play():
		_on_goal_scored(1)

func _on_goal_scored(player: int) -> void:
	if player == 1:
		_left_score += 1
	else:
		_right_score += 1

	_serve_to_right = player == 1
	_update_score()
	_prepare_round(false)

func _update_score() -> void:
	score_label.text = "%d   :   %d\nPressione ESPAÇO para iniciar" % [_left_score, _right_score]

func _prepare_round(launch: bool) -> void:
	left_paddle.reset_position()
	right_paddle.reset_position()

	var direction := 1.0 if _serve_to_right else -1.0
	ball.reset_ball(direction, launch)

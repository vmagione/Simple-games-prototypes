extends Node2D

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var left_paddle = $LeftPaddle
@onready var right_paddle = $RightPaddle
@onready var ball = $Ball

var _left_score := 0
var _right_score := 0

func _ready() -> void:
	ball.goal_scored.connect(_on_goal_scored)
	_update_score()
	_start_round(randf() > 0.5)

func _on_goal_scored(player: int) -> void:
	if player == 1:
		_left_score += 1
	else:
		_right_score += 1

	_update_score()
	left_paddle.reset_position()
	right_paddle.reset_position()
	_start_round(player == 1)

func _update_score() -> void:
	score_label.text = "%d   :   %d" % [_left_score, _right_score]

func _start_round(serve_to_right: bool) -> void:
	var direction := 1.0 if serve_to_right else -1.0
	ball.reset_ball(direction)

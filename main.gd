extends Node3D

@onready var ball: RigidBody3D = $Ball
@onready var stroke_label: Label = $StrokeLabel
@onready var aim_line: Line2D = $AimLine
@onready var camera: Camera3D = $Camera3D
@onready var course: Node3D = $Course

const BALL_START_POS := Vector3(-5, 0.25, 0)
const MAX_DRAG := 250.0
const MAX_POWER := 20.0

var aim_start := Vector2.ZERO
var is_won := false

func _ready() -> void:
	ball.stroke_added.connect(_on_stroke_added)
	course.ball_entered_hole.connect(_on_ball_entered_hole)
	aim_line.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_ball()
	
	if ball.is_moving or is_won:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				aim_start = event.position
				aim_line.visible = true
			else:
				aim_line.visible = false
				var drag_vector = aim_start - event.position
				if drag_vector.length() > 10:
					var drag_length = mini(drag_vector.length(), MAX_DRAG)
					var power = (drag_length / MAX_DRAG) * MAX_POWER
					var direction = Vector3(-drag_vector.x, 0, -drag_vector.y).normalized()
					ball.apply_impulse(direction * power)
					ball.stroke_count += 1
					ball.is_moving = true
					_on_stroke_added(ball.stroke_count)

func _process(_delta: float) -> void:
	if aim_line.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		var ball_screen_pos := camera.unproject_position(ball.global_position)
		aim_line.clear_points()
		aim_line.add_point(ball_screen_pos)
		var drag_vector := aim_start - mouse_pos
		var clamped_drag_length = mini(drag_vector.length(), MAX_DRAG)
		var clamped_drag = drag_vector.normalized() * clamped_drag_length
		var end_pos := ball_screen_pos + Vector2(-clamped_drag.x * 0.3, -clamped_drag.y * 0.3)
		aim_line.add_point(end_pos)
		var power := mini(int((drag_vector.length() / MAX_DRAG) * 100), 100)
		stroke_label.text = "Power: %d" % power

func _on_stroke_added(count: int) -> void:
	stroke_label.text = "Strokes: %d" % count

func _on_ball_entered_hole() -> void:
	is_won = true
	stroke_label.text = "You Win! Strokes: %d" % ball.stroke_count

func reset_ball() -> void:
	is_won = false
	ball.reset(BALL_START_POS)
	_on_stroke_added(0)

extends Node3D

var target_ball: Ball = null
var is_aiming := false

var orbit_yaw := 0.0
var orbit_pitch := -15.0
var orbit_distance := 12.0
const MOUSE_SENSITIVITY := 0.1

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func set_target(ball: Ball) -> void:
	target_ball = ball

func get_aim_direction() -> Vector3:
	var yaw = deg_to_rad(orbit_yaw)
	var launch_angle = remap(orbit_pitch, -80.0, 45.0, 10.0, 70.0)
	var pitch = deg_to_rad(launch_angle)
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()

func _ready() -> void:
	spring_arm.spring_length = orbit_distance

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit_yaw -= event.relative.x * MOUSE_SENSITIVITY
		orbit_pitch = clampf(orbit_pitch - event.relative.y * MOUSE_SENSITIVITY, -80.0, 45.0)

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				orbit_distance = max(3.0, orbit_distance - 1.0)
				spring_arm.spring_length = orbit_distance
			MOUSE_BUTTON_WHEEL_DOWN:
				orbit_distance = min(25.0, orbit_distance + 1.0)
				spring_arm.spring_length = orbit_distance

func _process(delta: float) -> void:
	_update_orbital(delta)

func _update_orbital(delta: float) -> void:
	if not target_ball:
		return

	var ball_pos = target_ball.rigid_body.global_position
	global_position = global_position.lerp(ball_pos, minf(10.0 * delta, 1.0))
	spring_arm.rotation_degrees = Vector3(orbit_pitch, orbit_yaw, 0)

	var look_idle = ball_pos + Vector3.UP * 1.5
	var look_aim = ball_pos + get_aim_direction() * 15
	var look_target = look_aim if is_aiming else look_idle
	camera.look_at(look_target)

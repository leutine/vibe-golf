extends Node3D

enum Mode { ORBITAL, FREE }

var mode := Mode.ORBITAL
var target_ball: Ball = null

var orbit_yaw := 0.0
var orbit_pitch := -30.0
var orbit_distance := 12.0

var free_yaw := 0.0
var free_pitch := 0.0
var free_move_speed := 15.0
const MOUSE_SENSITIVITY := 0.1

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func set_target(ball: Ball) -> void:
	target_ball = ball

func _ready() -> void:
	spring_arm.spring_length = orbit_distance

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		toggle_mode()
		get_viewport().set_input_as_handled()

	if mode == Mode.ORBITAL:
		_handle_orbital_input(event)
	else:
		_handle_free_input(event)

func _handle_orbital_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit_yaw -= event.relative.x * MOUSE_SENSITIVITY
		orbit_pitch = clampf(orbit_pitch - event.relative.y * MOUSE_SENSITIVITY, -80.0, -5.0)

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				orbit_distance = max(3.0, orbit_distance - 1.0)
				spring_arm.spring_length = orbit_distance
			MOUSE_BUTTON_WHEEL_DOWN:
				orbit_distance = min(25.0, orbit_distance + 1.0)
				spring_arm.spring_length = orbit_distance

func _handle_free_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		free_yaw -= event.relative.x * MOUSE_SENSITIVITY
		free_pitch = clampf(free_pitch - event.relative.y * MOUSE_SENSITIVITY, -90.0, 90.0)

func toggle_mode() -> void:
	if mode == Mode.ORBITAL:
		mode = Mode.FREE
	else:
		mode = Mode.ORBITAL
		orbit_yaw = free_yaw
		orbit_pitch = free_pitch
		spring_arm.spring_length = orbit_distance
		if target_ball:
			global_position = target_ball.rigid_body.global_position

func _process(delta: float) -> void:
	if mode == Mode.ORBITAL:
		_update_orbital(delta)
	else:
		_update_free(delta)

func _update_orbital(delta: float) -> void:
	if not target_ball:
		return

	var ball_pos = target_ball.rigid_body.global_position
	global_position = global_position.lerp(ball_pos, minf(10.0 * delta, 1.0))
	spring_arm.rotation_degrees = Vector3(orbit_pitch, orbit_yaw, 0)
	camera.look_at(target_ball.rigid_body.global_position)

func _update_free(delta: float) -> void:
	var forward = -spring_arm.global_transform.basis.z
	var right = spring_arm.global_transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var dir := Vector3()
	if Input.is_key_pressed(KEY_W): dir += forward
	if Input.is_key_pressed(KEY_S): dir -= forward
	if Input.is_key_pressed(KEY_A): dir -= right
	if Input.is_key_pressed(KEY_D): dir += right

	if dir.length() > 0:
		global_position += dir.normalized() * free_move_speed * delta

	if Input.is_key_pressed(KEY_SPACE):
		global_position.y += free_move_speed * delta
	if Input.is_key_pressed(KEY_CTRL):
		global_position.y -= free_move_speed * delta

	spring_arm.rotation_degrees = Vector3(free_pitch, free_yaw, 0)

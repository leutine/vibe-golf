extends Node3D
class_name Ball

signal stroke_added
signal ball_reset(ball: Ball)

enum AimMode { DIRECT, LOB }

const MAX_DRAG_PX := 300.0
const MAX_POWER := 20.0
const TRAJECTORY_POINTS := 20
const LOB_ANGLE := 55.0
const LOB_ANGLE_RANGE := 15.0

var stroke_count := 0
var material = StandardMaterial3D.new()
var pending_reset = false
var pending_reset_pos = Vector3.ZERO

var aim_mode := AimMode.DIRECT
var aim_visible := false
var aim_power := 0.0
var aim_power_ratio := 0.0
var aim_direction := Vector3.FORWARD

@onready var rigid_body: RigidBody3D = $RigidBody
@onready var name_label: Label3D = $NameLabel
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var trajectory: MultiMeshInstance3D = $TrajectoryPoints

@export var color := Color.BLACK:
	set(value):
		color = value
		material.albedo_color = value
		$RigidBody/MeshInstance3D.material_override = material

@export var player_name := "Player":
	set(value):
		player_name = value
		if name_label:
			name_label.text = value

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	if is_multiplayer_authority():
		trajectory.visible = false
		color = PlayerData.my_color
		player_name = PlayerData.my_name
	else:
		set_physics_process(false)
		set_process_input(false)

	if multiplayer.get_unique_id() == int(name):
		name_label.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		do_reset(get_random_spawn_position())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			aim_visible = true
			aim_mode = AimMode.DIRECT
		elif aim_visible:
			aim_visible = false
			apply_shot()

	if event is InputEventKey and event.pressed and event.keycode == KEY_SHIFT:
		if aim_visible:
			aim_mode = AimMode.LOB if aim_mode == AimMode.DIRECT else AimMode.DIRECT

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if pending_reset:
		pending_reset = false
		rigid_body.global_position = pending_reset_pos
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO

func _process(_delta: float) -> void:
	if name_label.visible:
		name_label.global_position = rigid_body.global_position + Vector3.UP * 0.5

	if not is_multiplayer_authority():
		return

	if not aim_visible:
		trajectory.visible = false
		return

	trajectory.visible = true

	var mouse_pos := get_viewport().get_mouse_position()
	var ball_screen = camera.unproject_position(rigid_body.global_position)
	var drag_screen = ball_screen - mouse_pos
	var dist = drag_screen.length()

	var camera_basis = camera.global_transform.basis
	var world_dir = drag_screen.x * camera_basis.x - drag_screen.y * camera_basis.y
	world_dir.y = 0.0
	var dir_norm = world_dir.normalized()

	var power_ratio = clampf(dist / MAX_DRAG_PX, 0.0, 1.0)
	var power = power_ratio * MAX_POWER

	aim_power = power
	aim_power_ratio = power_ratio
	aim_direction = dir_norm

	var origin = rigid_body.global_position
	var points: PackedVector3Array

	if aim_mode == AimMode.DIRECT:
		points = _generate_direct_trajectory(origin, dir_norm, power)
	else:
		points = _generate_lob_trajectory(origin, dir_norm, power, power_ratio)

	_update_trajectory_mesh(points)

func _generate_direct_trajectory(origin: Vector3, dir: Vector3, power: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var vel = dir * power
	var pos = origin
	pos.y = 0.1
	var damp = rigid_body.linear_damp
	var dt = 1.0 / 60.0
	var max_points = trajectory.multimesh.instance_count

	for i in range(max_points):
		points.append(pos)
		vel *= (1.0 - damp * dt)
		pos += vel * dt
		if vel.length() < 0.1:
			break
	return points

func _generate_lob_trajectory(origin: Vector3, dir: Vector3, power: float, ratio: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var angle = deg_to_rad(LOB_ANGLE + ratio * LOB_ANGLE_RANGE)
	var vel = Vector3(dir.x * cos(angle), sin(angle), dir.z * cos(angle)) * power
	var pos = origin
	var damp = rigid_body.linear_damp
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	var dt = 1.0 / 60.0
	var max_points = trajectory.multimesh.instance_count

	for i in range(max_points):
		points.append(pos)
		if pos.y <= 0.05 and i > 5:
			break
		vel.y -= gravity * dt
		vel *= (1.0 - damp * dt)
		pos += vel * dt
	return points

func _update_trajectory_mesh(points: PackedVector3Array) -> void:
	var mm = trajectory.multimesh
	var count = mini(points.size(), mm.instance_count)
	mm.visible_instance_count = count
	for i in range(count):
		mm.set_instance_transform(i, Transform3D(Basis(), points[i] - global_position))

func apply_shot() -> void:
	var impulse: Vector3
	if aim_mode == AimMode.DIRECT:
		impulse = aim_direction * aim_power
	else:
		var angle = deg_to_rad(LOB_ANGLE + aim_power_ratio * LOB_ANGLE_RANGE)
		impulse = Vector3(aim_direction.x * cos(angle), sin(angle), aim_direction.z * cos(angle)) * aim_power

	rigid_body.apply_impulse(impulse)
	stroke_added.emit()

func do_reset(pos: Vector3) -> void:
	pending_reset = true
	pending_reset_pos = pos
	ball_reset.emit(self)

func get_random_spawn_position() -> Vector3:
	var x := randf_range(0.1, 9.0)
	var z := randf_range(0.1, 9.0)
	return Vector3(x, 1, z)

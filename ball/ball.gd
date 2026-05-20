extends Node3D
class_name Ball

signal stroke_added
signal ball_reset(ball: Ball)

const MAX_POWER := 20.0
const MAX_DRAG_PX := 400.0

var stroke_count := 0
var material = StandardMaterial3D.new()
var pending_reset = false
var pending_reset_pos = Vector3.ZERO

var camera_controller: Node = null
var is_aiming := false
var aim_accumulated_vec := Vector2.ZERO
var aim_power := 0.0
var aim_direction := Vector3.FORWARD

@onready var rigid_body: RigidBody3D = $RigidBody
@onready var name_label: Label3D = $NameLabel
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var trajectory: MultiMeshInstance3D = $TrajectoryPoints

@export var trajectory_opacity := 0.75

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
		if event.pressed and not is_aiming:
			is_aiming = true
			aim_accumulated_vec = Vector2.ZERO
			aim_direction = _get_aim_direction()
			if camera_controller:
				camera_controller.is_aiming = true
		elif not event.pressed and is_aiming:
			is_aiming = false
			if camera_controller:
				camera_controller.is_aiming = false
			apply_shot()

	if event is InputEventMouseMotion and is_aiming:
		aim_accumulated_vec += event.relative

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

	if not is_aiming:
		trajectory.visible = false
		return

	var power_ratio = clampf(aim_accumulated_vec.length() / MAX_DRAG_PX, 0.0, 1.0)
	aim_power = power_ratio * MAX_POWER

	trajectory.visible = true
	var points = _generate_trajectory(rigid_body.global_position, aim_direction, aim_power)
	_update_trajectory_mesh(points)

func _generate_trajectory(origin: Vector3, direction: Vector3, power: float) -> PackedVector3Array:
	var raw := PackedVector3Array()
	var vel = direction.normalized() * power
	var pos = origin
	var damp = rigid_body.linear_damp
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	var dt = 1.0 / 60.0
	var max_points = trajectory.multimesh.instance_count

	for _i in range(600):
		raw.append(pos)
		if pos.y <= 0.05 and raw.size() > 5:
			break
		vel.y -= gravity * dt
		vel *= (1.0 - damp * dt)
		pos += vel * dt

	if raw.size() <= max_points:
		return raw
	var result := PackedVector3Array()
	for i in range(max_points):
		result.append(raw[i * (raw.size() - 1) / (max_points - 1)])
	return result

func _update_trajectory_mesh(points: PackedVector3Array) -> void:
	var mm = trajectory.multimesh
	var count = mini(points.size(), mm.instance_count)
	mm.visible_instance_count = count
	for i in range(count):
		var t = float(i) / (count - 1) if count > 1 else 0.0
		mm.set_instance_color(i, Color(1, 1, 1, lerpf(trajectory_opacity, 0.0, t)))
		mm.set_instance_transform(i, Transform3D(Basis(), points[i] - global_position))

func _get_aim_direction() -> Vector3:
	var cc = camera.get_parent().get_parent()
	if cc.has_method("get_aim_direction"):
		return cc.get_aim_direction()
	return -camera.global_transform.basis.z

func apply_shot() -> void:
	var impulse = aim_direction.normalized() * aim_power
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

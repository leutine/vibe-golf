extends RigidBody3D
class_name Ball

signal stroke_added
signal ball_reset(ball: Ball)

const MAX_DRAG_PX := 300.0
const MAX_POWER := 20.0

var stroke_count := 0
var material = StandardMaterial3D.new()
var pending_reset = false
var pending_reset_pos = Vector3.ZERO

@onready var aim_line: Line2D = $AimLine
@onready var camera: Camera3D = get_viewport().get_camera_3d()

@export var color := Color.BLACK:
	set(new_color):
		color = new_color
		material.albedo_color = new_color
		$MeshInstance3D.material_override = material

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return
	aim_line.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		do_reset(get_random_spawn_position())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			aim_line.visible = true
		elif aim_line.visible:
			aim_line.visible = false
			var ball_screen = camera.unproject_position(global_position)
			var drag_screen = ball_screen - event.position
			var dist = drag_screen.length()
			if dist >= 1.0:
				var power_ratio = clampf(dist / MAX_DRAG_PX, 0.0, 1.0)
				var camera_basis = camera.global_transform.basis
				var world_dir = drag_screen.x * camera_basis.x - drag_screen.y * camera_basis.y
				world_dir.y = 0.0
				apply_stroke(power_ratio * MAX_POWER, world_dir.normalized())

func _physics_process(_delta: float) -> void:
	if pending_reset:
		pending_reset = false
		global_transform = Transform3D(Basis(), pending_reset_pos)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

func _process(_delta: float) -> void:
	if aim_line.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		var ball_screen = camera.unproject_position(global_position)
		var drag_screen = ball_screen - mouse_pos
		var dist = drag_screen.length()
		var power_ratio = clampf(dist / MAX_DRAG_PX, 0.0, 1.0)
		var camera_basis = camera.global_transform.basis
		var world_dir = drag_screen.x * camera_basis.x - drag_screen.y * camera_basis.y
		world_dir.y = 0.0

		var aim_len = 50.0 + power_ratio * 150.0
		var end_pos = ball_screen + drag_screen.normalized() * aim_len

		aim_line.clear_points()
		aim_line.add_point(ball_screen)
		aim_line.add_point(end_pos)
		aim_line.default_color = Color(power_ratio, 1.0 - power_ratio, 0)

func apply_stroke(power: float, direction: Vector3) -> void:
	apply_impulse(direction * power)
	stroke_added.emit()

func do_reset(pos: Vector3) -> void:
	pending_reset = true
	pending_reset_pos = pos
	ball_reset.emit(self)

func get_random_spawn_position() -> Vector3:
	var x := randf_range(0.1, 9.0)
	var z := randf_range(0.1, 9.0)
	return Vector3(x, 1, z)

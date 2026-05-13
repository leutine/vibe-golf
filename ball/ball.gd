extends RigidBody3D
class_name Ball

signal stroke_added
signal ball_reset

const MAX_DRAG := 250.0
const MAX_POWER := 20.0

var aim_start := Vector2.ZERO
var stroke_count := 0
var material = StandardMaterial3D.new()
var pending_reset = false
var pending_reset_pos = Vector3.ZERO

@onready var aim_line: Line2D = $AimLine

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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				aim_start = event.position
				aim_line.visible = true
			elif aim_line.visible:
				aim_line.visible = false
				var drag_vector = aim_start - event.position
				if drag_vector.length() > 10:
					var drag_length = mini(drag_vector.length(), MAX_DRAG)
					var power = (drag_length / MAX_DRAG) * MAX_POWER
					var direction := Vector3(-drag_vector.x, 0, -drag_vector.y).normalized()
					apply_stroke(power, direction)

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
		var ball_screen_pos = get_parent_node_3d().get_parent().camera.unproject_position(global_position)
		aim_line.clear_points()
		aim_line.add_point(ball_screen_pos)
		var drag_vector := aim_start - mouse_pos
		var clamped_drag_length = mini(drag_vector.length(), MAX_DRAG)
		var clamped_drag = drag_vector.normalized() * clamped_drag_length
		var end_pos = ball_screen_pos + Vector2(-clamped_drag.x * 0.3, -clamped_drag.y * 0.3)
		aim_line.add_point(end_pos)
		var power := mini(int((drag_vector.length() / MAX_DRAG) * 100), 100)

func apply_stroke(power: float, direction: Vector3) -> void:
	apply_impulse(direction * power)
	stroke_added.emit()

func do_reset(pos: Vector3) -> void:
	pending_reset = true
	pending_reset_pos = pos
	ball_reset.emit()

func get_random_spawn_position() -> Vector3:
	var x := randf_range(0.1, 9.0)
	var z := randf_range(0.1, 9.0)
	return Vector3(x, 1, z)

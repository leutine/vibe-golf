extends RigidBody3D
class_name Ball

signal stroke_added(count: int)

const MAX_DRAG := 250.0
const MAX_POWER := 20.0

var aim_start := Vector2.ZERO
var stroke_count := 0
var material = StandardMaterial3D.new()

@onready var aim_line: Line2D = $AimLine

@export var ball_color := Color.BLACK:
	set(new_color):
		ball_color = new_color
		material.albedo_color = new_color
		$MeshInstance3D.material_override = material

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
		return
	aim_line.visible = false

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

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if linear_velocity.length() < 0.1 and linear_velocity != Vector3.ZERO:
		linear_velocity = Vector3.ZERO

func apply_stroke(power: float, direction: Vector3) -> void:
	apply_impulse(direction * power)
	stroke_count += 1
	stroke_added.emit(stroke_count)

func do_reset(pos: Vector3) -> void:
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	stroke_count = 0
	stroke_added.emit(stroke_count)

func _get_random_spawn_position() -> Vector3:
	var x := randf_range(0, 9.0)
	var z := randf_range(0, 9.0)
	return Vector3(x, 1, z)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		do_reset(_get_random_spawn_position())
		
	#if my_ball.linear_velocity.length() > 0.1:
		#return
	#
	#if scored_players.has(peer_id):
		#return

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

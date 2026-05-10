extends RigidBody3D

signal stroke_added(count: int)
signal entered_hole

@export var owner_peer_id: int = 1
@export var ball_color: Color = Color(1, 0.2, 0.2, 1)

var stroke_count := 0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 10
	linear_damp = 0.5
	angular_damp = 0.5

	_apply_color()

func _apply_color() -> void:
	var mesh := $MeshInstance3D as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ball_color
		mesh.set_surface_override_material(0, mat)

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		if linear_velocity.length() < 0.1 and linear_velocity != Vector3.ZERO:
			linear_velocity = Vector3.ZERO

func do_spawn(pos: Vector3) -> void:
	global_position = pos

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

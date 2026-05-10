extends RigidBody3D

signal stroke_added(count: int)

var is_moving := false
var stroke_count := 0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.5
	angular_damp = 0.5

func _physics_process(_delta: float) -> void:
	if is_moving and linear_velocity.length() < 0.1:
		is_moving = false

func reset(pos: Vector3) -> void:
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	is_moving = false
	stroke_count = 0
	stroke_added.emit(stroke_count)

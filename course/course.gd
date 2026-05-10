extends Node3D

signal ball_entered_hole(ball: RigidBody3D)

@onready var hole_area: Area3D = $Floor/Hole/HoleArea

func _ready() -> void:
	hole_area.body_entered.connect(_on_hole_body_entered)

func _on_hole_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		ball_entered_hole.emit(body)

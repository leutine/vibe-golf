extends Node3D

signal ball_entered_hole(ball: Ball)

@onready var hole_area: Area3D = $Floor/Hole/HoleArea

func _ready() -> void:
	hole_area.body_entered.connect(_on_hole_body_entered)

func _on_hole_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		var ball := body.get_parent() as Ball
		if ball:
			ball_entered_hole.emit(ball)

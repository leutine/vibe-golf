extends Node3D

const MAX_DRAG := 250.0

const PLAYER_COLORS := [
	Color(1, 0.2, 0.2),
	Color(0.2, 0.4, 1),
	Color(0.2, 0.8, 0.2),
	Color(1, 0.8, 0.2),
	Color(0.8, 0.2, 1)
]

const PLAYER: PackedScene = preload("res://ball/ball.tscn")

@onready var stroke_label: Label = $StrokeLabel
@onready var camera: Camera3D = $Camera3D
@onready var course: Node3D = $Course
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var peer_id: int = -1
var is_host := false
var aim_start := Vector2.ZERO
var my_ball: Ball
var players: Dictionary = {}
var scored_players: Array = []

func _ready() -> void:
	Engine.max_fps = 60
	peer_id = multiplayer.get_unique_id()
	is_host = multiplayer.is_server()

	spawner.spawn_function = _spawn_ball_custom
	spawner.spawned.connect(_on_ball_spawned)

	course.ball_entered_hole.connect(_on_ball_entered_hole)
	
	if is_host:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		spawn_ball(peer_id)

func _spawn_ball_custom(data: Dictionary) -> Node:
	var ball: Ball = PLAYER.instantiate()
	ball.name = str(data["id"])
	ball.ball_color = data["color"]
	ball.position = data["position"]
	return ball

func _on_ball_spawned(ball: Ball) -> void:
	var id = int(ball.name)
	print_debug(id)
	players[id] = {
		"ball": ball,
		"position": ball.global_position,
		"color": ball.ball_color
	}
	# Если это наш мяч — сохраняем ссылку
	if id == peer_id:
		print("i am %s; my ball is %s" % [str(multiplayer.get_unique_id()), str(peer_id)])
		my_ball = ball
		ball.stroke_added.connect(_on_stroke_added)

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	spawn_ball(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	if players.has(id):
		players[id].ball.queue_free()
		players.erase(id)

func spawn_ball(id: int) -> void:
	if players.has(id):
		return

	print_debug(id)
	var pos := _get_random_spawn_position()
	var color = PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()]
	
	var ball: Ball = spawner.spawn({
		"id": id,
		"position": pos,
		"color": color
	})
	
	players[id] = {
		"ball": ball,
		"position": ball.global_position,
		"color": ball.ball_color
	}

	# Если это наш мяч — сохраняем ссылку
	if id == peer_id:
		my_ball = ball
		ball.stroke_added.connect(_on_stroke_added)
	
func _get_random_spawn_position() -> Vector3:
	var x := randf_range(0, 9.0)
	var z := randf_range(0, 9.0)
	return Vector3(x, 1, z)

#func _process(_delta: float) -> void:
	#if my_ball.aim_line.visible and my_ball:
		#var mouse_pos := get_viewport().get_mouse_position()
		#var ball_screen_pos := camera.unproject_position(my_ball.global_position)
		#my_ball.aim_line.clear_points()
		#my_ball.aim_line.add_point(ball_screen_pos)
		#var drag_vector := aim_start - mouse_pos
		#var clamped_drag_length = mini(drag_vector.length(), MAX_DRAG)
		#var clamped_drag = drag_vector.normalized() * clamped_drag_length
		#var end_pos := ball_screen_pos + Vector2(-clamped_drag.x * 0.3, -clamped_drag.y * 0.3)
		#my_ball.aim_line.add_point(end_pos)
		#var power := mini(int((drag_vector.length() / MAX_DRAG) * 100), 100)
		#stroke_label.text = "Power: %d" % power

func _on_stroke_added(count: int) -> void:
	stroke_label.text = "Strokes: %d" % count

func _on_ball_entered_hole(ball: RigidBody3D) -> void:
	var scorer_id := -1
	for id in players:
		if players[id].ball == ball:
			scorer_id = id
			break
	
	if scorer_id == -1:
		return
	
	if not scored_players.has(scorer_id):
		scored_players.append(scorer_id)
		stroke_label.text = "Player %d scored!" % scorer_id
		tween_label(stroke_label)

func tween_label(label):
	var tw = create_tween().bind_node(label)
	tw.set_parallel()
	tw.set_trans(Tween.TRANS_ELASTIC)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "rotation", 2 * PI, 1)
	tw.tween_property(label, "theme_override_font_sizes/font_size", 50, 1)

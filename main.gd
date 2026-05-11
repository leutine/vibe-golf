extends Node3D

const MAX_DRAG := 250.0
const MAX_POWER := 20.0

const PLAYER_COLORS := [
	Color(1, 0.2, 0.2),
	Color(0.2, 0.4, 1),
	Color(0.2, 0.8, 0.2),
	Color(1, 0.8, 0.2),
	Color(0.8, 0.2, 1)
]

const SPAWN_PATH := "res://ball/ball.tscn"
var ball_scene: PackedScene = preload("res://ball/ball.tscn")

@onready var stroke_label: Label = $StrokeLabel
@onready var aim_line: Line2D = $AimLine
@onready var camera: Camera3D = $Camera3D
@onready var course: Node3D = $Course
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var peer_id: int = 1
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
	aim_line.visible = false
	
	if is_host:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		spawn_ball(peer_id)

func _spawn_ball_custom(data: Dictionary) -> Node:
	var ball: Ball = ball_scene.instantiate()
	ball.name = "Ball_%d" % data["id"]
	ball.ball_color = data["color"]
	ball.position = data["position"]
	ball.set_multiplayer_authority(1)
	return ball

func _on_ball_spawned(ball: Ball) -> void:
	print("_on_ball_spawned")
	var id_str := ball.name.trim_prefix("Ball_")
	var id := id_str.to_int()
	players[id] = {
		"ball": ball,
		"position": ball.global_position,
		"color": ball.ball_color
	}
	# Если это наш мяч — сохраняем ссылку
	if id == peer_id:
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
	var x := randf_range(-4.0, 4.0)
	var z := randf_range(-2.5, 2.5)
	return Vector3(x, 0.25, z)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_my_ball()
		return
	
	if not my_ball:
		return
	
	if my_ball.linear_velocity.length() > 0.1:
		return
	
	if scored_players.has(peer_id):
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				aim_start = event.position
				aim_line.visible = true
			elif aim_line.visible:
				aim_line.visible = false
				var drag_vector = aim_start - event.position
				if drag_vector.length() > 10:
					var drag_length := mini(drag_vector.length(), MAX_DRAG)
					var power := (drag_length / MAX_DRAG) * MAX_POWER
					var direction := Vector3(-drag_vector.x, 0, -drag_vector.y).normalized()
					
					if is_host:
						my_ball.apply_stroke(power, direction)
					else:
						_apply_stroke_rpc.rpc_id(1, peer_id, power, direction)

func _process(_delta: float) -> void:
	if aim_line.visible and my_ball:
		var mouse_pos := get_viewport().get_mouse_position()
		var ball_screen_pos := camera.unproject_position(my_ball.global_position)
		aim_line.clear_points()
		aim_line.add_point(ball_screen_pos)
		var drag_vector := aim_start - mouse_pos
		var clamped_drag_length := mini(drag_vector.length(), MAX_DRAG)
		var clamped_drag := drag_vector.normalized() * clamped_drag_length
		var end_pos := ball_screen_pos + Vector2(-clamped_drag.x * 0.3, -clamped_drag.y * 0.3)
		aim_line.add_point(end_pos)
		var power := mini(int((drag_vector.length() / MAX_DRAG) * 100), 100)
		stroke_label.text = "Power: %d" % power

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

func reset_my_ball() -> void:
	if not my_ball:
		return
	
	scored_players.erase(peer_id)
	var pos := _get_random_spawn_position()
	my_ball.do_reset(pos)
	if players.has(peer_id):
		players[peer_id].position = pos
	stroke_label.text = "Strokes: 0"

@rpc("any_peer", "call_remote", "reliable")
func _apply_stroke_rpc(player_id: int, power: float, direction: Vector3):
	print("RPC received on: ", get_path())
	print("Sender ID: ", multiplayer.get_remote_sender_id())
	print("_apply_stroke_rpc called! player_id=", player_id)
	if not is_host:
		return
	if players.has(player_id):
		players[player_id].ball.apply_stroke(power, direction)

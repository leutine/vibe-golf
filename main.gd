extends Node3D

const PLAYER_COLORS := [
	Color(1, 0.2, 0.2),
	Color(0.2, 0.4, 1),
	Color(0.2, 0.8, 0.2),
	Color(1, 0.8, 0.2),
	Color(0.8, 0.2, 1)
]

const BALL: PackedScene = preload("uid://ball001")

const CAMERA_OFFSET := Vector3(0, 12, 10)
const FOLLOW_CAM_OFFSET := Vector3(0, 1.5, 5)
const DEAD_ZONE := 3.0
const CAMERA_LERP_SPEED := 5.0

@onready var stroke_label: Label = $StrokeLabel
@onready var goal_label: Label = $GoalLabel
@onready var course: Node3D = $Course
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var camera: Camera3D = $Camera3D

var players: Dictionary = {}
var scored_players: Array = []
var strokes := 0:
	set(value):
		strokes = value
		stroke_label.text = "Strokes: %d" % strokes

var levels: Array[PackedScene] = []
var current_level_index := -1
var camera_focus := Vector3(5, 0, 5)
var follow_camera := false
var camera_basis: Basis

func _ready() -> void:
	goal_label.visible = false
	camera_basis = camera.global_transform.basis

	load_levels()
	spawner.spawn_function = custom_spawn_ball
	$Balls.child_entered_tree.connect(_on_ball_spawned)

	switch_level(0)

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(on_peer_connected)
		multiplayer.peer_disconnected.connect(on_peer_disconnected)
		spawner.spawn(multiplayer.get_unique_id())

func _process(delta: float) -> void:
	var my_id := multiplayer.get_unique_id()
	if not players.has(my_id):
		return
	var ball = players[my_id].ball
	var ball_pos = ball.rigid_body.global_position

	if follow_camera:
		camera.global_position = ball_pos + FOLLOW_CAM_OFFSET
		camera.look_at(ball_pos)
		return

	var diff = ball_pos - camera_focus
	var flat_dist := Vector2(diff.x, diff.z).length()
	if flat_dist > DEAD_ZONE:
		var target_focus = camera_focus + diff * (1.0 - DEAD_ZONE / flat_dist)
		camera_focus = camera_focus.lerp(target_focus, minf(CAMERA_LERP_SPEED * delta, 1.0))

	camera.global_position = camera_focus + CAMERA_OFFSET
	camera.global_transform.basis = camera_basis

func load_levels():
	var dir = DirAccess.open("res://levels/")
	if not dir:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tscn") and file.begins_with("level_"):
			levels.append(load("res://levels/" + file))
		file = dir.get_next()
	levels.sort_custom(func(a, b): return a.resource_path < b.resource_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		match key:
			KEY_C:
				follow_camera = not follow_camera
				if not follow_camera:
					var my_id := multiplayer.get_unique_id()
					if players.has(my_id):
						camera_focus = players[my_id].ball.rigid_body.global_position
						camera_focus.y = 0
		if not multiplayer.is_server():
			return
		if key >= KEY_1 and key <= KEY_9:
			switch_level.rpc(key - KEY_1)

@rpc("authority", "call_local", "reliable")
func switch_level(level_index: int):
	if level_index < 0 or level_index >= levels.size():
		return
	if level_index == current_level_index:
		return

	current_level_index = level_index
	camera_focus = Vector3(5, 0, 5)

	for child in course.get_children():
		child.queue_free()

	var new_level = levels[level_index].instantiate()
	new_level.ball_entered_hole.connect(on_ball_entered_hole)
	course.add_child(new_level)

	for id in players:
		players[id].ball.do_reset(get_random_spawn_position())
	strokes = 0

func get_random_spawn_position() -> Vector3:
	var x := randf_range(0.1, 9.0)
	var z := randf_range(0.1, 9.0)
	return Vector3(x, 1, z)

func custom_spawn_ball(id: int) -> Ball:
	var ball: Ball = BALL.instantiate()
	ball.name = str(id)
	ball.position = get_random_spawn_position()
	return ball

func _on_ball_spawned(node: Node) -> void:
	if not node is Ball:
		return
	var ball := node as Ball
	var id = int(ball.name)
	ball.stroke_added.connect(on_stroke_added)
	ball.ball_reset.connect(on_ball_reset)

	players[id] = {
		"ball": ball,
		"position": ball.position,
		"color": ball.color
	}

func on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	spawner.spawn(id)
	switch_level.rpc_id(id, current_level_index)

func on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	if players.has(id):
		players[id].ball.queue_free()
		players.erase(id)

func on_stroke_added():
	strokes += 1

func on_ball_reset(ball: Ball):
	strokes = 0
	if int(ball.name) == multiplayer.get_unique_id():
		camera_focus = ball.rigid_body.global_position
		camera_focus.y = 0

func on_ball_entered_hole(ball: Ball) -> void:
	var player_data = players.get(int(ball.name), null)
	var scorer_id = int(ball.name) if player_data else -1

	if scorer_id == -1:
		return
	
	goal_label.text = "%s scored!" % ball.player_name
	tween_label(goal_label, ball.color)

func tween_label(label: Label, color: Color):
	var font_size = 16
	var duration = 1
	var tw = label.create_tween()

	tw.tween_property(label, "visible", true, 0)
	tw.parallel().tween_property(label, "rotation", 2 * PI, duration).set_trans(Tween.TRANS_EXPO)
	tw.parallel().tween_property(label.label_settings, "font_size", font_size * 5, duration)
	tw.tween_property(label, "modulate", color, 0.5)
	tw.tween_property(label, "rotation", 0, duration)
	tw.parallel().tween_property(label.label_settings, "font_size", font_size * 0.5, duration)
	tw.tween_property(label, "visible", false, 0)

	label.label_settings.font_size = font_size
	label.modulate = Color.WHITE

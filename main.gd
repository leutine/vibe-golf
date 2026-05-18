extends Node3D

const BALL: PackedScene = preload("uid://ball001")

@onready var stroke_label: Label = $StrokeLabel
@onready var goal_label: Label = $GoalLabel
@onready var course: Node3D = $Course
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var players: Dictionary = {}
var strokes := 0:
	set(value):
		strokes = value
		stroke_label.text = "Strokes: %d" % strokes

var levels: Array[PackedScene] = []
var current_level_index := -1

func _ready() -> void:
	goal_label.visible = false

	load_levels()
	spawner.spawn_function = custom_spawn_ball
	$Balls.child_entered_tree.connect(_on_ball_spawned)

	switch_level(0)

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(on_peer_connected)
		multiplayer.peer_disconnected.connect(on_peer_disconnected)
		spawner.spawn(multiplayer.get_unique_id())

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

	if id == multiplayer.get_unique_id():
		$CameraController.set_target(ball)

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

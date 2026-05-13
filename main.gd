extends Node3D

const PLAYER_COLORS := [
	Color(1, 0.2, 0.2),
	Color(0.2, 0.4, 1),
	Color(0.2, 0.8, 0.2),
	Color(1, 0.8, 0.2),
	Color(0.8, 0.2, 1)
]

const BALL: PackedScene = preload("uid://ball001")

# TODO: не убирать, используется внутри ball.gd
@onready var camera: Camera3D = $Camera3D

@onready var stroke_label: Label = $StrokeLabel
@onready var goal_label: Label = $GoalLabel
@onready var course: Node3D = $Course
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var players: Dictionary = {}
var scored_players: Array = []
var strokes := 0:
	set(value):
		strokes = value
		stroke_label.text = "Strokes: %d" % strokes

func _ready() -> void:
	goal_label.visible = false
	Engine.max_fps = 60

	spawner.spawn_function = custom_spawn_ball
	course.ball_entered_hole.connect(on_ball_entered_hole)
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(on_peer_connected)
		multiplayer.peer_disconnected.connect(on_peer_disconnected)
		spawner.spawn(multiplayer.get_unique_id())

func get_random_spawn_position() -> Vector3:
	var x := randf_range(0.1, 9.0)
	var z := randf_range(0.1, 9.0)
	return Vector3(x, 1, z)

func custom_spawn_ball(id: int) -> Ball:
	var pos = get_random_spawn_position()
	var color = PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()]
	var ball: Ball = BALL.instantiate()
	ball.name = str(id)
	ball.color = color
	ball.position = pos
	ball.stroke_added.connect(on_stroke_added)
	ball.ball_reset.connect(on_ball_reset)

	players[id] = {
		"ball": ball,
		"position": pos,
		"color": color
	}
	return ball

func on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	spawner.spawn(id)
	print(players)

func on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	if players.has(id):
		players[id].ball.queue_free()
		players.erase(id)

func on_stroke_added():
	strokes += 1

func on_ball_reset():
	strokes = 0

func on_ball_entered_hole(ball: Ball) -> void:
	var scorer_id := -1
	for id in players:
		if players[id].ball == ball:
			scorer_id = id
			break

	if scorer_id == -1:
		return

	#if not scored_players.has(scorer_id):
		#scored_players.append(scorer_id)
		#goal_label.text = "Player %d scored!" % scorer_id
		#tween_label(goal_label, ball.color)
	goal_label.text = "Player %d scored!" % scorer_id
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

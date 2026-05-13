extends Control

const DEFAULT_PORT := 4567
const MAX_PLAYERS := 5
const BALL = preload("uid://ball001")
const MAIN_SCENE_PATH = "uid://bja62h36dhan5"

@onready var ip_input: LineEdit = $VBox/IPInput
@onready var status_label: Label = $VBox/StatusLabel

var enet_peer := ENetMultiplayerPeer.new()

func _on_host_pressed() -> void:
	var err := enet_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		print("Failed to host: %s" % err)
		return

	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	print("Hosting on port %d..." % DEFAULT_PORT)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	var err := enet_peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		print("Failed to connect: %s" % err)
		return
	
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player) 
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.connected_to_server.connect(on_connected_to_server)
	print("Connecting to %s..." % ip)

func on_connected_to_server():
	add_player(multiplayer.get_unique_id())
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func add_player(peer_id: int):
	#if peer_id == 1:
		#return
	#var new_player = BALL.instantiate()
	#new_player.name = str(peer_id)
	#var rand_x = randf_range(-5.0, 5.0)
	#var rand_z = randf_range(-5.0, 5.0)
	#new_player.position = Vector3(rand_x, 1.0, rand_z)
	pass

func remove_player(peer_id):
	pass
	#if peer_id == 1:
		#leave_server()
	#var players: Array[Node] = get_tree().get_nodes_in_group('Players')
	#var player_to_remove = players.find_custom(func(item): return item.name == str(peer_id))
	#if player_to_remove != -1:
		#players[player_to_remove].queue_free()

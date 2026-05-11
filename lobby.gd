extends Control

const DEFAULT_PORT := 4567
const MAX_PLAYERS := 5

@onready var ip_input: LineEdit = $VBox/IPInput
@onready var status_label: Label = $VBox/StatusLabel

var peer_id: int = 0
var is_host := false

func _ready() -> void:
	ip_input.text = "localhost"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	var server := ENetMultiplayerPeer.new()
	var err := server.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		status_label.text = "Failed to host: %s" % err
		return
	
	multiplayer.multiplayer_peer = server
	peer_id = 1
	is_host = true
	status_label.text = "Hosting on port %d..." % DEFAULT_PORT
	get_tree().change_scene_to_file("res://main.tscn")

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	var client := ENetMultiplayerPeer.new()
	var err := client.create_client(ip, DEFAULT_PORT)
	if err != OK:
		status_label.text = "Failed to connect: %s" % err
		return
	
	multiplayer.multiplayer_peer = client
	is_host = false
	status_label.text = "Connecting to %s..." % ip

func _on_peer_connected(id: int) -> void:
	status_label.text = "Player %d connected" % id

func _on_peer_disconnected(id: int) -> void:
	status_label.text = "Player %d disconnected" % id

func _on_connected_to_server() -> void:
	status_label.text = "Connected!"
	get_tree().change_scene_to_file("res://main.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"

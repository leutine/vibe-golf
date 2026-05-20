extends Control

const DEFAULT_PORT := 4567
const MAX_PLAYERS := 5
const MAIN_SCENE_PATH = "res://main.tscn"

@onready var ip_input: LineEdit = $VBox/IPInput
@onready var name_input: LineEdit = $VBox/NameInput
@onready var color_picker: ColorPickerButton = $VBox/ColorPickerButton
@onready var status_label: Label = $VBox/StatusLabel

var peer := ENetMultiplayerPeer.new()

func _on_host_pressed() -> void:
	PlayerData.my_color = color_picker.color
	PlayerData.my_name = name_input.text

	var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		print("Failed to host: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	print("Hosting on port %d..." % DEFAULT_PORT)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _on_join_pressed() -> void:
	PlayerData.my_color = color_picker.color
	PlayerData.my_name = name_input.text

	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"

	var err := peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		print("Failed to connect: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	print("Connecting to %s..." % ip)

func _on_connected_to_server():
	print("Connected!")
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

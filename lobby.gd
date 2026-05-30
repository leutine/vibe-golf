extends Control

const DEFAULT_PORT := 4567
const MAX_PLAYERS := 5
const MAIN_SCENE_PATH = "res://main.tscn"

@onready var ip_input: LineEdit = $VBox/IPInput
@onready var name_input: LineEdit = $VBox/NameInput
@onready var color_picker: ColorPickerButton = $VBox/ColorPickerButton
@onready var status_label: Label = $VBox/StatusLabel

#var peer := ENetMultiplayerPeer.new()
var peer: SteamMultiplayerPeer
var is_host := false
var is_joining := false
var lobby_id := 0

func _ready() -> void:
	print("Steam Initialized: ", Steam.steamInit(480, true))
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(on_lobby_created)
	Steam.lobby_joined.connect(on_lobby_joined)

func _on_host_pressed() -> void:
	PlayerData.my_color = color_picker.color
	PlayerData.my_name = name_input.text

	is_host = true
	Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)
	#var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	#if err != OK:
		#print("Failed to host: %s" % err)
		#return

	#multiplayer.multiplayer_peer = peer
	#print("Hosting on port %d..." % DEFAULT_PORT)
	#get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func on_lobby_created(result: int, lobby_id: int):
	if result != Steam.Result.RESULT_OK:
		return
	self.lobby_id = lobby_id
	
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_host()
	multiplayer.multiplayer_peer = peer
	
	print("Lobby created: ", lobby_id)
	DisplayServer.clipboard_set(str(lobby_id))

	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _on_join_pressed() -> void:
	PlayerData.my_color = color_picker.color
	PlayerData.my_name = name_input.text

	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	is_joining = true
	Steam.joinLobby(ip.to_int())

	#var err := peer.create_client(ip, DEFAULT_PORT)
	#if err != OK:
		#print("Failed to connect: %s" % err)
		#return
#
	#multiplayer.multiplayer_peer = peer
	#multiplayer.connected_to_server.connect(_on_connected_to_server)
	#print("Connecting to %s..." % ip)

func on_lobby_joined(lobby_id, permissions, locked, response):
	if not is_joining:
		return
	
	self.lobby_id = lobby_id
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_client(Steam.getLobbyOwner(lobby_id))
	multiplayer.multiplayer_peer = peer
	
	is_joining = false
	print("Lobby joined: ", lobby_id)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _on_connected_to_server():
	print("Connected!")
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

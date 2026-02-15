extends Control

@onready var host = $UI/Multiplayer/VBoxContainer/Host
@onready var join = $UI/Multiplayer/VBoxContainer/Join
@onready var start_server = $UI/Multiplayer/VBoxContainer/StartServer
@onready var oi_dinput = %OIDinput
@onready var ui = $UI

const MAX_PLAYER = 2

@export var address = "127.0.0.1"
@export var port = 9999

var peer

func _ready():
	host.pressed.connect(_on_host_pressed)
	join.pressed.connect(_on_join_pressed)
	start_server.pressed.connect(_on_start_server_pressed)
	
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_connected.connect(on_peer_disconnected)
	multiplayer.connected_to_server.connect(on_connected_to_server)
	multiplayer.connection_failed.connect(on_connection_failed)
	
func _on_host_pressed():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error != OK:
		print('cannot host ' + error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("WAITING FOR OTHER PLAYER")
	send_player_info(oi_dinput.text, multiplayer.get_unique_id())

func _on_join_pressed():
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

func _on_start_server_pressed():
	start_game.rpc()

@rpc("any_peer", "call_local")
func start_game():
	var scene = load("res://Scenes/game_battle.tscn").instantiate()
	get_tree().root.add_child(scene)
	hide()
	ui.hide()

func on_peer_connected(id):
	print('player connected ' + str(id))

func on_peer_disconnected(id):
	print('player disconnected ' + str(id))

func on_connected_to_server():
	send_player_info.rpc_id(1, oi_dinput.text, multiplayer.get_unique_id())

func on_connection_failed():
	print('couldnt connect ')

@rpc("any_peer")
func send_player_info(name, id):
	if !GameManager.players.has(id):
		GameManager.players[id] = {
			"name": name,
			"id": id
		}
	
	if multiplayer.is_server():
		for i in GameManager.players:
			send_player_info.rpc(GameManager.players[i].name, i)

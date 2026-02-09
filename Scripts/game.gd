extends Node
class_name Game

@onready var MultiplayerUI = $UI/Multiplayer
@onready var online_id_label = %OnlineID
@onready var oid_input = %OIDinput
@onready var copy_oid_button = $UI/Multiplayer/CopyOID
@onready var background_rect = $TextureRect

const PLAYER = preload("res://player/player.tscn")

var peer = NodeTunnelPeer.new()
var players: Array[Player] = []

func _ready() -> void:
	multiplayer.multiplayer_peer = peer
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	
	await peer.relay_connected
	
	%OnlineID.text = peer.online_id
	$MultiplayerSpawner.spawn_function = add_player

func _on_host_pressed() -> void:
	peer.host()
	
	await peer.hosting
	
	multiplayer.peer_connected.connect(
		func(pid):
			print("Peer " + str(pid) + " has joined the game!")
			$MultiplayerSpawner.spawn(pid)
	)
	
	$MultiplayerSpawner.spawn(multiplayer.get_unique_id())
	MultiplayerUI.hide()

func _on_join_pressed() -> void:
	peer.join(%OIDinput.text)
	
	await peer.joined
	
	MultiplayerUI.hide()

func add_player(pid):
	var player = PLAYER.instantiate()
	player.name = str(pid)
	player.global_position = $TextureRect.get_child(players.size()).global_position
	players.append(player)
	
	return(player)

func _on_copy_oid_pressed() -> void:
	DisplayServer.clipboard_set(peer.online_id)

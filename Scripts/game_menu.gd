extends Node2D

const PORT = 676767
const SERVER_ADRESS = "localhost"

var peer = ENetMultiplayerPeer.new()

@export var player_field_scene: PackedScene
@export var opponent_field_scene: PackedScene

func _on_host_pressed() -> void:
	disable_buttons()
	
	peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	var player_scene = player_field_scene.instantiate()
	add_child(player_scene)

func _on_join_pressed() -> void:
	disable_buttons()
	
	peer.create_client(SERVER_ADRESS, PORT)
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	var player_scene = player_field_scene.instantiate()
	add_child(player_scene)
	
	var opponent_scene = opponent_field_scene.instantiate()
	add_child(opponent_scene)

func _on_peer_connected(peer_id):
	var opponent_scene = opponent_field_scene.instantiate()
	add_child(opponent_scene)

func disable_buttons():
	$UI/Multiplayer/VBoxContainer/Host.disabled = true
	$UI/Multiplayer/VBoxContainer/Host.visible = false
	$UI.visible = false
	$UI/Multiplayer/VBoxContainer/Join.disabled = true
	$UI/Multiplayer/VBoxContainer/Join.visible = false
	$UI.visible = false

extends Node2D

const PORT = 676767
const SERVER_ADRESS = "localhost"

var peer = ENetMultiplayerPeer.new()

@export var player_field_scene: PackedScene
@export var opponent_field_scene: PackedScene

func _on_host_pressed() -> void:
	disable_buttons()
	print("Host pressed - creating server on port ", PORT)
	
	peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var player_scene = player_field_scene.instantiate()
	add_child(player_scene)
	print("Host: Created player scene, my peer id: ", multiplayer.get_unique_id())

func _on_join_pressed() -> void:
	disable_buttons()
	print("Join pressed - connecting to ", SERVER_ADRESS, ":", PORT)
	
	peer.create_client(SERVER_ADRESS, PORT)
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var player_scene = player_field_scene.instantiate()
	add_child(player_scene)
	
	var opponent_scene = opponent_field_scene.instantiate()
	add_child(opponent_scene)
	print("Client: Created player and opponent scenes, my peer id: ", multiplayer.get_unique_id())

func _on_peer_connected(peer_id):
	print("Peer connected: ", peer_id)
	print("Current peers: ", multiplayer.get_peers())
	
	# If we're the host and no opponent scene yet, create it
	if multiplayer.is_server():
		var opponent_scene = opponent_field_scene.instantiate()
		add_child(opponent_scene)
		print("Host created opponent scene for peer: ", peer_id)

func _on_peer_disconnected(peer_id):
	print("Peer disconnected: ", peer_id)
	# Handle cleanup if needed

func disable_buttons():
	$UI/Multiplayer/VBoxContainer/Host.disabled = true
	$UI/Multiplayer/VBoxContainer/Host.visible = false
	$UI.visible = false
	$UI/Multiplayer/VBoxContainer/Join.disabled = true
	$UI/Multiplayer/VBoxContainer/Join.visible = false
	$UI.visible = false

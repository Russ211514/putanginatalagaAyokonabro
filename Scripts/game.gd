extends Node

var multiplayer_peer = ENetMultiplayerPeer.new()

const PORT = 9999
const ADDRESS = "localhost"

var connected_peer_ids = []

func _on_host_pressed() -> void:
	$RoomLabel.text = "SERVER"
	$UI.visible = false
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	$NetworkInfo.text = str(multiplayer.get_unique_id())
	
	add_player_character(1)
	
	multiplayer_peer.peer_connected.connect(
		func(new_peer_id):
			await get_tree().create_timer(1.0).timeout
			rpc("add_newly_connected_player_character", new_peer_id)
			rpc_id(new_peer_id, "add_previously_connected_player_character", connected_peer_ids)
			add_player_character(new_peer_id)
	)

func _on_join_pressed() -> void:
	$RoomLabel.text = "CLIENT"
	$UI.visible = false
	multiplayer_peer.create_client(ADDRESS, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	$NetworkInfo.text = str(multiplayer.get_unique_id())

func add_player_character(peer_id):
	connected_peer_ids.append(peer_id)
	var player_character = preload("res://player/player.tscn").instantiate()
	add_child(player_character)

@rpc	
func add_newly_connected_player_character(new_peer_id):
	add_player_character(new_peer_id)

@rpc	
func add_previously_connected_player_character(peer_ids):
	for peer_id in peer_ids:
		add_player_character(peer_id)

extends Node2D

const PORT = 123

var peer = ENetMultiplayerPeer.new()

@export var player_field_scene: PackedScene

func _on_host_pressed() -> void:
	disable_buttons()
	
	peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = peer
	
	var player_scene = player_field_scene.instantiate()
	add_child(player_scene)

func disable_buttons():
	$UI/Multiplayer/VBoxContainer/Host.disabled = true
	$UI/Multiplayer/VBoxContainer/Host.visible = false
	$UI/Multiplayer/VBoxContainer/Join.disabled = true
	$UI/Multiplayer/VBoxContainer/Join.visible = false

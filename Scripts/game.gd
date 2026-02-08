extends Node
class_name Game

@onready var MultiplayerUI = $UI/Multiplayer
@onready var Title = $Title
@onready var BattleSystem = $BattleLayout

const PLAYER = preload("res://player/html_player.tscn")

var peer = NodeTunnelPeer.new()
var players : Array[Node] = []
var matchmaking = preload("res://Scripts/NodeTunnelMatchmaking.gd").new()
var is_host = false
var players_ready = 0

func _ready() -> void:
	add_child(matchmaking)

	multiplayer.multiplayer_peer = peer
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	await peer.relay_connected
	%OnlineID.text = peer.online_id
	$MultiplayerSpawner.spawn_function = add_player

func _on_host_pressed() -> void:
	is_host = true
	peer.host()
	
	await peer.hosting
	
	multiplayer.peer_connected.connect(
		func(pid):
			print("Peer " + str(pid) + " has joined the game")
			$MultiplayerSpawner.spawn(pid)
			check_start_battle()
	)
	
	$MultiplayerSpawner.spawn(multiplayer.get_unique_id())
	MultiplayerUI.hide()
	Title.hide()

func _on_join_pressed() -> void:
	peer.join(%OIDinput.text)
	
	await peer.joined
	
	$MultiplayerSpawner.spawn(multiplayer.get_unique_id())
	MultiplayerUI.hide()
	Title.hide()
	check_start_battle()

func add_player(pid) -> Node:
	var player = PLAYER.instantiate()
	player.name = str(pid)
	player.global_position = $bg.get_child(players.size()).global_position
	players.append(player)
	
	return player

func check_start_battle() -> void:
	"""Check if both players are ready and start the battle"""
	# Wait a moment for all players to spawn
	await get_tree().create_timer(0.5).timeout
	
	if players.size() >= 2:
		start_battle()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/pvp language selection.tscn")

func start_battle() -> void:
	"""Start the PvP battle when both players are ready"""
	if BattleSystem:
		BattleSystem.start_battle()
		MultiplayerUI.hide()
		Title.hide()

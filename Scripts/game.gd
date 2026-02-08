extends Node
class_name Game

@onready var MultiplayerUI = $UI/Multiplayer
@onready var Title = $Title
@onready var BattleSystem = $BattleLayout
@onready var online_id_label = %OnlineID
@onready var room_name_input = %RoomName
@onready var oid_input = %OIDinput
@onready var copy_oid_button = $UI/Multiplayer/CopyOID
@onready var host_button = $UI/Multiplayer/VBoxContainer/Host
@onready var join_button = $UI/Multiplayer/VBoxContainer/Join

const PLAYER = preload("res://player/html_player.tscn")

var peer = NodeTunnelPeer.new()
var players : Array[Node] = []
var matchmaking = preload("res://Scripts/NodeTunnelMatchmaking.gd").new()
var is_host = false
var room_code = ""
var waiting_for_opponent = false
var connection_timeout = 30.0  # seconds
var timeout_timer = 0.0
var my_player_id = 0
var opponent_player_id = 0

func _ready() -> void:
	add_child(matchmaking)

	multiplayer.multiplayer_peer = peer
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	await peer.relay_connected
	room_code = peer.online_id
	online_id_label.text = "Code: " + room_code
	$MultiplayerSpawner.spawn_function = add_player
	
	# Connect button signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	copy_oid_button.pressed.connect(_on_copy_oid_pressed)
	$UI/Multiplayer/Back.pressed.connect(_on_back_pressed)

func _process(delta: float) -> void:
	"""Handle timeout for waiting opponents"""
	if waiting_for_opponent:
		timeout_timer += delta
		if timeout_timer >= connection_timeout:
			_on_connection_timeout()

func _on_host_pressed() -> void:
	is_host = true
	waiting_for_opponent = true
	timeout_timer = 0.0
	my_player_id = multiplayer.get_unique_id()
	
	# Get custom room name if provided
	var custom_name = room_name_input.text.strip_edges()
	if custom_name.is_empty():
		custom_name = "Room " + room_code.substr(0, 6)
	
	peer.host()
	await peer.hosting
	
	online_id_label.text = "Code: " + room_code
	online_id_label.show()
	
	# Disable join UI
	join_button.disabled = true
	oid_input.editable = false
	room_name_input.editable = false
	
	# Update status
	copy_oid_button.text = "WAITING..."
	copy_oid_button.disabled = true
	
	multiplayer.peer_connected.connect(
		func(pid):
			print("Peer " + str(pid) + " has joined the game")
			opponent_player_id = pid
			_on_peer_connected(pid)
	)
	
	multiplayer.peer_disconnected.connect(
		func(pid):
			print("Peer " + str(pid) + " has disconnected")
			_on_peer_disconnected(pid)
	)
	
	# Spawn self as host
	$MultiplayerSpawner.spawn(my_player_id)

func _on_peer_connected(pid: int) -> void:
	"""Handle when a peer connects"""
	print("Spawning player for peer: " + str(pid))
	$MultiplayerSpawner.spawn(pid)
	
	# Wait for both players to be visible
	await get_tree().create_timer(1.0).timeout
	
	if players.size() >= 2:
		# Tell the joining player to start the battle
		_notify_battle_start.rpc_id(pid)
		_on_match_found()

func _on_peer_disconnected(pid: int) -> void:
	"""Handle when a peer disconnects"""
	print("Peer disconnected: " + str(pid))
	# Remove player from array
	players = players.filter(func(p): return p.name != str(pid))

func _on_join_pressed() -> void:
	"""Join a game using the provided room code"""
	var code = oid_input.text.strip_edges()
	if code.is_empty():
		online_id_label.text = "ERROR: Enter room code"
		return
	
	is_host = false
	waiting_for_opponent = true
	timeout_timer = 0.0
	my_player_id = multiplayer.get_unique_id()
	
	# Disable host UI
	host_button.disabled = true
	room_name_input.editable = false
	copy_oid_button.disabled = true
	oid_input.editable = false
	
	# Update status
	join_button.text = "JOINING..."
	join_button.disabled = true
	
	peer.join(code)
	await peer.joined
	
	print("Successfully joined room: " + code)
	
	multiplayer.peer_disconnected.connect(
		func(pid):
			print("Peer " + str(pid) + " has disconnected")
			_on_peer_disconnected(pid)
	)
	
	# Wait a moment for host to be ready
	await get_tree().create_timer(0.5).timeout
	
	# Spawn self as client
	$MultiplayerSpawner.spawn(my_player_id)
	
	# Wait for both players to be visible
	await get_tree().create_timer(1.5).timeout
	
	if players.size() >= 2:
		# Notify the host that joining player is ready
		_notify_battle_start.rpc_id(1)

@rpc("any_peer", "call_local")
func _notify_battle_start() -> void:
	"""RPC called when both players are ready"""
	# Give a moment for all RPCs to settle
	await get_tree().create_timer(0.5).timeout
	_on_match_found()

func _on_match_found() -> void:
	"""Called when both players are ready"""
	waiting_for_opponent = false
	print("Match found! Starting battle with " + str(players.size()) + " players")
	
	# Hide multiplayer UI and start battle
	MultiplayerUI.hide()
	Title.hide()
	start_battle()

func _on_connection_timeout() -> void:
	"""Handle connection timeout"""
	waiting_for_opponent = false
	online_id_label.text = "CONNECTION TIMEOUT"
	
	# Re-enable buttons for retry
	host_button.disabled = false
	join_button.disabled = false
	join_button.text = "JOIN GAME"
	room_name_input.editable = true
	oid_input.editable = true
	copy_oid_button.disabled = false
	copy_oid_button.text = "COPY CODE"

func add_player(pid) -> Node:
	"""Instantiate a player at the appropriate spawn point"""
	var player = PLAYER.instantiate()
	player.name = str(pid)
	
	var spawn_index = players.size()
	if spawn_index < 2:
		player.global_position = $bg.get_child(spawn_index).global_position
	
	players.append(player)
	print("Player added: " + str(pid) + ". Total players: " + str(players.size()))
	
	return player

func _on_copy_oid_pressed() -> void:
	"""Copy the room code to clipboard"""
	if is_host and not room_code.is_empty():
		DisplayServer.clipboard_set(room_code)
		copy_oid_button.text = "COPIED!"
		await get_tree().create_timer(2.0).timeout
		copy_oid_button.text = "COPY CODE"
	else:
		online_id_label.text = "Not hosting"

func _on_back_pressed() -> void:
	"""Return to language selection"""
	get_tree().change_scene_to_file("res://Scenes/pvp language selection.tscn")

func start_battle() -> void:
	"""Start the PvP battle when both players are ready"""
	if BattleSystem and players.size() >= 2:
		BattleSystem.start_battle()

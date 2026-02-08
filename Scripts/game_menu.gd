extends Node2D
class_name GameMenu

@onready var MultiplayerUI = $UI/Multiplayer
@onready var Title = $Title
@onready var online_id_label = %OnlineID
@onready var room_name_input = %RoomName
@onready var oid_input = %OIDinput
@onready var copy_oid_button = $UI/Multiplayer/CopyOID
@onready var host_button = $UI/Multiplayer/VBoxContainer/Host
@onready var join_button = $UI/Multiplayer/VBoxContainer/Join
@onready var find_match_button = $UI/Multiplayer/Button
@onready var back_button = $UI/Multiplayer/Back
@onready var multiplayer_spawner = $MultiplayerSpawner

const PLAYER = preload("res://player/html_player.tscn")

var network_manager: NetworkManager
var players: Array[Node] = []
var is_hosting = false
var waiting_for_opponent = false
var current_room_code = ""
var opponent_user_id = ""

func _ready() -> void:
	# Create and initialize EOS Manager
	network_manager = NetworkManager.new()
	add_child(network_manager)
	
	# Wait for authentication
	if not network_manager.is_authenticated():
		await network_manager.authenticated
	
	# Initialize UI
	_update_user_id_display()
	_setup_button_connections()
	_setup_network_signals()
	
	print("Using " + network_manager.get_active_backend() + " backend for multiplayer")
	
	# Set up multiplayer spawner
	multiplayer_spawner.spawn_function = add_player

func _setup_button_connections() -> void:
	"""Connect all UI button signals"""
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	find_match_button.pressed.connect(_on_find_match_pressed)
	copy_oid_button.pressed.connect(_on_copy_oid_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _setup_network_signals() -> void:
	"""Connect network manager signals"""
	network_manager.lobby_created.connect(_on_lobby_created)
	network_manager.lobby_joined.connect(_on_lobby_joined)
	network_manager.matchmaking_started.connect(_on_matchmaking_started)
	network_manager.matchmaking_complete.connect(_on_matchmaking_complete)
	network_manager.peer_connected.connect(_on_peer_connected)
	network_manager.error_occurred.connect(_on_network_error)

func _update_user_id_display() -> void:
	"""Update the displayed user ID"""
	var user_id = network_manager.get_local_player_id()
	var display_id = user_id.substr(0, 12) if user_id.length() > 12 else user_id
	online_id_label.text = "ID: " + display_id + "..."

# ============================================================================
# HOST GAME
# ============================================================================

func _on_host_pressed() -> void:
	"""Host a new game - create a lobby"""
	print("Host button pressed")
	
	if is_hosting:
		return
	
	is_hosting = true
	
	# Disable other buttons
	host_button.disabled = true
	join_button.disabled = true
	find_match_button.disabled = true
	
	# Get room name (or use default)
	var room_name = "Game"
	if not room_name_input.text.is_empty():
		room_name = room_name_input.text
	
	# Create lobby via Network Manager
	network_manager.create_lobby(room_name, 2, false)
	
	waiting_for_opponent = true
	_disable_inputs()

func _on_lobby_created(lobby_id: String, room_code: String) -> void:
	"""Called when lobby is successfully created"""
	print("Lobby created: " + lobby_id + " with code: " + room_code)
	
	current_room_code = room_code
	online_id_label.text = "Room: " + room_code
	copy_oid_button.text = "COPY CODE"

# ============================================================================
# JOIN GAME
# ============================================================================

func _on_join_pressed() -> void:
	"""Join a game using room code"""
	print("Join button pressed")
	
	if waiting_for_opponent:
		return
	
	var room_code = oid_input.text.strip_edges().to_upper()
	
	if room_code.is_empty():
		online_id_label.text = "ENTER ROOM CODE"
		return
	
	# Attempt to join via Network Manager
	network_manager.join_lobby_by_code(room_code)
	
	waiting_for_opponent = true
	join_button.disabled = true
	host_button.disabled = true
	find_match_button.disabled = true
	_disable_inputs()

func _on_lobby_joined(lobby_id: String, _owner_id: String = "") -> void:
	"""Called when successfully joined a lobby"""
	print("Lobby joined: " + lobby_id)
	
	online_id_label.text = "Joined"
	
	# Wait a moment for the lobby owner to see us, then both proceed to battle
	await get_tree().create_timer(1.5).timeout
	start_pvp_match()

# ============================================================================
# MATCHMAKING
# ============================================================================

func _on_find_match_pressed() -> void:
	"""Start searching for opponents via matchmaking"""
	print("Find Match button pressed")
	
	find_match_button.disabled = true
	find_match_button.text = "SEARCHING..."
	
	# Start matchmaking through Network Manager
	network_manager.start_matchmaking("pvp")

func _on_matchmaking_started() -> void:
	"""Called when matchmaking starts"""
	print("Matchmaking started")
	waiting_for_opponent = true
	_disable_inputs()

func _on_matchmaking_complete(opponent_id: String) -> void:
	"""Called when opponent is found"""
	print("Matchmaking complete! Opponent: " + opponent_id)
	
	opponent_user_id = opponent_id
	
	await get_tree().create_timer(1.0).timeout
	start_pvp_match()

# ============================================================================
# P2P CONNECTIONS
# ============================================================================

func _on_peer_connected(peer_user_id: String) -> void:
	"""Called when P2P connection with opponent is established"""
	print("Peer connected: " + peer_user_id)
	opponent_user_id = peer_user_id

# ============================================================================
# GAME LOGIC
# ============================================================================

func start_pvp_match() -> void:
	"""Start the PvP battle"""
	if players.size() < 2:
		# Wait for both players to be spawned
		await get_tree().create_timer(1.0).timeout
		if players.size() < 2:
			print("Warning: Not all players spawned, proceeding anyway")
	
	print("Starting PvP match with " + str(players.size()) + " players")
	
	# Hide multiplayer UI
	MultiplayerUI.hide()
	Title.hide()
	
	# Find battle system and start
	if has_node("BattleLayout"):
		var battle_system = $BattleLayout
		if battle_system.has_method("start_pvp_battle"):
			var my_player_id = network_manager.get_local_player_id()
			battle_system.start_pvp_battle(my_player_id, opponent_user_id)

func add_player(pid) -> Node:
	"""Instantiate a player at the appropriate spawn point"""
	var player = PLAYER.instantiate()
	player.name = str(pid)
	
	var spawn_index = players.size()
	var spawn_point = null
	
	# Find spawn points (they're children of TextureRect)
	if has_node("TextureRect"):
		var texture_rect = $TextureRect
		if spawn_index < texture_rect.get_child_count():
			spawn_point = texture_rect.get_child(spawn_index)
			if spawn_point is Marker2D:
				player.global_position = spawn_point.global_position
	
	players.append(player)
	print("Player added: " + str(pid) + ". Total players: " + str(players.size()))
	
	return player

# ============================================================================
# UI UTILITIES
# ============================================================================

func _on_copy_oid_pressed() -> void:
	"""Copy the room code to clipboard"""
	if is_hosting and not current_room_code.is_empty():
		DisplayServer.clipboard_set(current_room_code)
		copy_oid_button.text = "COPIED!"
		await get_tree().create_timer(2.0).timeout
		copy_oid_button.text = "COPY CODE"

func _on_back_pressed() -> void:
	"""Return to previous scene"""
	if waiting_for_opponent:
		# Cancel operations
		network_manager.cancel_matchmaking()
		network_manager.leave_lobby()
		waiting_for_opponent = false
		_reset_ui()
	else:
		get_tree().change_scene_to_file("res://Scenes/Language Selection.tscn")

func _on_network_error(error_code: int, error_message: String) -> void:
	"""Called when a network error occurs"""
	push_error("Network Error " + str(error_code) + ": " + error_message)
	online_id_label.text = "ERROR: " + error_message.substr(0, 20)

func _disable_inputs() -> void:
	"""Disable input fields while waiting"""
	room_name_input.editable = false
	oid_input.editable = false

func _reset_ui() -> void:
	"""Reset UI to initial state"""
	host_button.disabled = false
	join_button.disabled = false
	find_match_button.disabled = false
	find_match_button.text = "FIND MATCH"
	room_name_input.editable = true
	oid_input.editable = true
	_update_user_id_display()

func _process(_delta: float) -> void:
	"""Handle any per-frame logic"""
	# Keep connection alive - check if opponent joined
	if waiting_for_opponent and is_hosting:
		var lobby_info = network_manager.get_current_lobby_info()
		if lobby_info.has("players"):
			if lobby_info.players >= 2:
			# Second player joined
				waiting_for_opponent = false
				start_pvp_match()

func _exit_tree() -> void:
	"""Clean up network resources when scene unloads"""
	if network_manager:
		network_manager.shutdown()

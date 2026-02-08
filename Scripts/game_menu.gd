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
@onready var MultiplayerSpawner = $MultiplayerSpawner

const PLAYER = preload("res://player/html_player.tscn")

var eos_manager: EOSManager
var players: Array[Node] = []
var is_hosting = false
var waiting_for_opponent = false
var current_room_code = ""
var opponent_user_id = ""

func _ready() -> void:
	# Create and initialize EOS Manager
	eos_manager = EOSManager.new()
	add_child(eos_manager)
	
	# Wait for EOS authentication
	if not eos_manager.is_authenticated:
		await eos_manager.authenticated
	
	# Initialize UI
	_update_user_id_display()
	_setup_button_connections()
	_setup_eos_signals()
	
	# Set up multiplayer spawner
	MultiplayerSpawner.spawn_function = add_player

func _setup_button_connections() -> void:
	"""Connect all UI button signals"""
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	find_match_button.pressed.connect(_on_find_match_pressed)
	copy_oid_button.pressed.connect(_on_copy_oid_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _setup_eos_signals() -> void:
	"""Connect EOS manager signals"""
	eos_manager.lobby_created.connect(_on_lobby_created)
	eos_manager.lobby_joined.connect(_on_lobby_joined)
	eos_manager.lobby_search_complete.connect(_on_lobby_search_complete)
	eos_manager.matchmaking_started.connect(_on_matchmaking_started)
	eos_manager.matchmaking_complete.connect(_on_matchmaking_complete)
	eos_manager.peer_connected.connect(_on_peer_connected)
	eos_manager.error_occurred.connect(_on_eos_error)

func _update_user_id_display() -> void:
	"""Update the displayed user ID"""
	var user_id = eos_manager.get_user_id()
	online_id_label.text = "ID: " + user_id

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
	
	# Create lobby via EOS
	var lobby_id = eos_manager.create_lobby(room_name, 2, false)
	
	if lobby_id.is_empty():
		push_error("Failed to create lobby")
		is_hosting = false
		_reset_ui()
		return
	
	waiting_for_opponent = true
	_disable_inputs()

func _on_lobby_created(lobby_id: String) -> void:
	"""Called when lobby is successfully created"""
	print("Lobby created: " + lobby_id)
	
	var lobby_info = eos_manager.get_current_lobby_info()
	current_room_code = lobby_info.room_code
	
	online_id_label.text = "Room Code: " + current_room_code
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
	
	# Attempt to join via EOS
	if not eos_manager.join_lobby_by_code(room_code):
		online_id_label.text = "CODE NOT FOUND"
		return
	
	waiting_for_opponent = true
	join_button.disabled = true
	host_button.disabled = true
	find_match_button.disabled = true
	_disable_inputs()

func _on_lobby_joined(lobby_id: String) -> void:
	"""Called when successfully joined a lobby"""
	print("Lobby joined: " + lobby_id)
	
	var lobby_info = eos_manager.get_current_lobby_info()
	online_id_label.text = "Joined: " + lobby_info.name
	
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
	
	# Start matchmaking through EOS
	eos_manager.start_matchmaking("pvp")

func _on_matchmaking_started() -> void:
	"""Called when matchmaking starts"""
	print("Matchmaking started")
	waiting_for_opponent = true
	_disable_inputs()

func _on_matchmaking_complete(session_id: String) -> void:
	"""Called when opponent is found"""
	print("Matchmaking complete! Session: " + session_id)
	
	# Create instant match lobby
	var lobby_id = eos_manager.create_lobby("Instant Match", 2, true)
	opponent_user_id = "opponent_" + str(randi())  # Placeholder opponent ID
	
	# Initialize P2P session
	eos_manager.start_p2p_session(opponent_user_id)
	
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
			var my_player_id = eos_manager.get_user_id()
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
		eos_manager.cancel_matchmaking()
		eos_manager.leave_lobby()
		waiting_for_opponent = false
		_reset_ui()
	else:
		get_tree().change_scene_to_file("res://Scenes/Language Selection.tscn")

func _on_lobby_search_complete(lobbies: Array) -> void:
	"""Called when lobby search completes"""
	print("Found " + str(lobbies.size()) + " lobbies")
	# You could implement a lobby browser here

func _on_eos_error(error_code: int, error_message: String) -> void:
	"""Called when an EOS error occurs"""
	push_error("EOS Error " + str(error_code) + ": " + error_message)
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

func _process(delta: float) -> void:
	"""Handle any per-frame logic"""
	# Keep connection alive
	if waiting_for_opponent and is_hosting:
		var lobby_info = eos_manager.get_current_lobby_info()
		if lobby_info.players >= 2:
			# Second player joined
			waiting_for_opponent = false
			start_pvp_match()

func _exit_tree() -> void:
	"""Clean up EOS resources when scene unloads"""
	if eos_manager:
		eos_manager.shutdown()

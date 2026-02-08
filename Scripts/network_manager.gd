extends Node
class_name NetworkManager

# Network backend selection
var use_eos: bool = true
var eos_manager: EOSManager
var websocket_manager: WebSocketManager

# Current active backend
var active_backend: Node

# Session state
var local_player_id: String = ""
var opponent_player_id: String = ""
var current_lobby_id: String = ""
var is_host: bool = false

# Signals (proxied from active backend)
signal authenticated(user_id: String)
signal authentication_failed(error: String)
signal lobby_created(lobby_id: String, room_code: String)
signal lobby_joined(lobby_id: String, owner_id: String)
signal lobby_search_complete(lobbies: Array)
signal lobby_member_updated(lobby_id: String, member_count: int)
signal matchmaking_started
signal matchmaking_complete(opponent_id: String)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal message_received(data: Dictionary)
signal error_occurred(error_code: int, error_message: String)

func _ready() -> void:
	# Determine which backend to use
	_initialize_backend()
	
	# Connect to active backend signals
	_connect_backend_signals()

func _initialize_backend() -> void:
	"""Initialize the appropriate networking backend"""
	
	# Check if running in WebGL (browser)
	var is_webgl = OS.get_name() == "Web"
	
	if is_webgl or not Engine.get_version_info().get("is_official", true):
		# Use WebSocket for WebGL/Web exports
		print("Using WebSocket backend for multiplayer")
		use_eos = false
		websocket_manager = WebSocketManager.new()
		add_child(websocket_manager)
		active_backend = websocket_manager
		
		# For testing, use localhost
		var ws_url = "ws://localhost:8080"
		# Check environment variable for WebSocket URL
		var ws_env = OS.get_environment("WS_SERVER_URL")
		if not ws_env.is_empty():
			ws_url = ws_env
		
		websocket_manager.connect_to_server(ws_url)
	else:
		# Use EOS for native platforms (Windows, Mac, Linux)
		print("Using EOS backend for multiplayer")
		use_eos = true
		eos_manager = EOSManager.new()
		add_child(eos_manager)
		active_backend = eos_manager
		
		# Wait for EOS authentication
		if not eos_manager.is_authenticated:
			await eos_manager.authenticated

func _connect_backend_signals() -> void:
	"""Connect signals from the active backend"""
	if not active_backend:
		return
	
	# Authentication signals
	if active_backend.has_signal("authenticated"):
		active_backend.authenticated.connect(func(user_id): 
			local_player_id = user_id
			authenticated.emit(user_id)
		)
	
	if active_backend.has_signal("authentication_failed"):
		active_backend.authentication_failed.connect(func(error):
			authentication_failed.emit(error)
		)
	
	# Lobby signals
	if active_backend.has_signal("lobby_created"):
		active_backend.lobby_created.connect(func(lobby_id, room_code):
			current_lobby_id = lobby_id
			is_host = true
			lobby_created.emit(lobby_id, room_code)
		)
	
	if active_backend.has_signal("lobby_joined"):
		active_backend.lobby_joined.connect(func(lobby_id, owner_id = ""):
			current_lobby_id = lobby_id
			is_host = false
			lobby_joined.emit(lobby_id, owner_id)
		)
	
	if active_backend.has_signal("lobby_search_complete"):
		active_backend.lobby_search_complete.connect(func(lobbies):
			lobby_search_complete.emit(lobbies)
		)
	
	if active_backend.has_signal("lobby_member_updated"):
		active_backend.lobby_member_updated.connect(func(lobby_id, member_count):
			lobby_member_updated.emit(lobby_id, member_count)
		)
	
	# Matchmaking signals
	if active_backend.has_signal("matchmaking_started"):
		active_backend.matchmaking_started.connect(func():
			matchmaking_started.emit()
		)
	
	if active_backend.has_signal("matchmaking_complete"):
		active_backend.matchmaking_complete.connect(func(opponent_id):
			opponent_player_id = opponent_id
			matchmaking_complete.emit(opponent_id)
		)
	
	# P2P signals
	if active_backend.has_signal("peer_connected"):
		active_backend.peer_connected.connect(func(peer_id):
			opponent_player_id = peer_id
			peer_connected.emit(peer_id)
		)
	
	if active_backend.has_signal("peer_disconnected"):
		active_backend.peer_disconnected.connect(func(peer_id):
			peer_disconnected.emit(peer_id)
		)
	
	if active_backend.has_signal("p2p_message_received"):
		active_backend.p2p_message_received.connect(func(_peer_id, data):
			message_received.emit(data)
		)
	
	if active_backend.has_signal("message_received"):
		active_backend.message_received.connect(func(data):
			message_received.emit(data)
		)
	
	# Error signal
	if active_backend.has_signal("error_occurred"):
		active_backend.error_occurred.connect(func(code, message):
			error_occurred.emit(code, message)
		)

# ============================================================================
# LOBBY OPERATIONS
# ============================================================================

func create_lobby(lobby_name: String, max_players: int = 2, is_private: bool = false) -> void:
	"""Create a new lobby"""
	if not active_backend:
		push_error("No active network backend")
		return
	
	active_backend.create_lobby(lobby_name, max_players, is_private)

func search_lobbies(game_mode: String = "pvp") -> void:
	"""Search for available lobbies"""
	if not active_backend:
		push_error("No active network backend")
		return
	
	active_backend.search_lobbies(game_mode)

func join_lobby_by_id(lobby_id: String) -> void:
	"""Join a specific lobby by ID"""
	if not active_backend:
		push_error("No active network backend")
		return
	
	active_backend.join_lobby_by_id(lobby_id)

func join_lobby_by_code(room_code: String) -> void:
	"""Join a lobby using a room code (EOS only)"""
	if use_eos and eos_manager:
		# For EOS, we need to search for the lobby first
		print("Joining by code requires searching lobbies first")
		search_lobbies()
	elif websocket_manager:
		websocket_manager.join_lobby_by_code(room_code)

func leave_lobby() -> void:
	"""Leave the current lobby"""
	if not active_backend:
		return
	
	active_backend.leave_lobby()
	current_lobby_id = ""
	is_host = false

# ============================================================================
# MATCHMAKING
# ============================================================================

func start_matchmaking(game_mode: String = "pvp") -> void:
	"""Start matchmaking"""
	if not active_backend:
		push_error("No active network backend")
		return
	
	active_backend.start_matchmaking(game_mode)

func cancel_matchmaking() -> void:
	"""Cancel active matchmaking"""
	if not active_backend:
		return
	
	active_backend.cancel_matchmaking()

# ============================================================================
# P2P MESSAGING
# ============================================================================

func send_message(opponent_id: String, message: Dictionary) -> bool:
	"""Send a message to an opponent"""
	if not active_backend:
		return false
	
	if use_eos and eos_manager:
		return eos_manager.send_p2p_message(opponent_id, message)
	elif websocket_manager:
		websocket_manager._send_message("game_message", {
			"to_player": opponent_id,
			"data": message
		})
		return true
	
	return false

# ============================================================================
# ACCESSORS
# ============================================================================

func get_local_player_id() -> String:
	"""Get the current player's ID"""
	return local_player_id

func get_opponent_id() -> String:
	"""Get the opponent's player ID"""
	return opponent_player_id

func get_current_lobby_id() -> String:
	"""Get the current lobby ID"""
	return current_lobby_id

func is_lobby_host() -> bool:
	"""Check if current player is the lobby host"""
	return is_host

func get_active_backend() -> String:
	"""Get the name of the active backend"""
	return "EOS" if use_eos else "WebSocket"

func is_using_eos() -> bool:
	"""Check if using EOS backend"""
	return use_eos

func is_authenticated() -> bool:
	"""Check if the user is authenticated"""
	if use_eos and eos_manager:
		return eos_manager.is_authenticated
	elif websocket_manager:
		return websocket_manager.ws_connected
	return false

func get_current_lobby_info() -> Dictionary:
	"""Get information about the current lobby"""
	if not active_backend:
		return {}
	
	return active_backend.get_current_lobby_info()

func get_all_lobbies() -> Array:
	"""Get all searched lobbies"""
	if not active_backend:
		return []
	
	return active_backend.get_all_lobbies()

# ============================================================================
# CLEANUP
# ============================================================================

func shutdown() -> void:
	"""Clean up network resources"""
	if active_backend:
		if active_backend.has_method("shutdown"):
			active_backend.shutdown()
	
	queue_free()

func _exit_tree() -> void:
	"""Clean up on node removal"""
	shutdown()

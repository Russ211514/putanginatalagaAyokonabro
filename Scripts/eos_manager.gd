extends Node
class_name EOSManager

# Load EOS credentials from config
var config = preload("res://Scripts/eos_config.gd").new()

# EOS Configuration - Will be loaded from EOSConfig
var CLIENT_ID = ""
var CLIENT_SECRET = ""
var DEPLOYMENT_ID = ""
var PRODUCT_ID = ""
var SANDBOX_ID = ""

# Session and state
var account_id: String = ""
var user_id: String = ""
var is_authenticated = false
var current_lobby_id: String = ""
var is_lobby_owner = false
var matchmaking_in_progress = false

# Signals
signal authenticated
signal authentication_failed(error: String)
signal lobby_created(lobby_id: String)
signal lobby_joined(lobby_id: String)
signal lobby_search_complete(lobbies: Array)
signal matchmaking_started
signal matchmaking_complete(session_id: String)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal error_occurred(error_code: int, error_message: String)

# Lobby and matchmaking data
var lobbies_found: Array = []
var active_lobbies: Dictionary = {}
var matchmaking_session: Dictionary = {}
var p2p_sessions: Dictionary = {}

func _ready() -> void:
	# Load credentials from config
	var creds = config.get_credentials()
	CLIENT_ID = creds.client_id
	CLIENT_SECRET = creds.client_secret
	DEPLOYMENT_ID = creds.deployment_id
	PRODUCT_ID = creds.product_id
	SANDBOX_ID = creds.sandbox_id
	
	# Initialize EOS SDK
	if not _validate_credentials():
		push_error("EOS credentials not configured")
		authentication_failed.emit("Missing EOS credentials. Please configure EOSConfig.gd with your credentials")
		return
	
	# Start EOS initialization
	await _init_eos()

func _validate_credentials() -> bool:
	"""Validate that all required EOS credentials are configured"""
	return (not CLIENT_ID.is_empty() and 
			not CLIENT_SECRET.is_empty() and 
			not DEPLOYMENT_ID.is_empty() and
			not PRODUCT_ID.is_empty() and
			not SANDBOX_ID.is_empty())

func _init_eos() -> void:
	"""Initialize EOS SDK and authenticate with device credentials"""
	print("Initializing EOS SDK...")
	
	# In development/testing, use device authentication
	# For production, use your preferred authentication method
	await authenticate_device()

func authenticate_device() -> void:
	"""Authenticate using device credentials (development/testing)"""
	print("Authenticating with EOS using device credentials...")
	
	try:
		# Device authentication is typically done through EOS backend
		# This is a placeholder for the actual EOS authentication flow
		is_authenticated = true
		account_id = randi_range(100000, 999999) as String
		user_id = "eos_user_" + account_id
		
		print("Authenticated as: " + user_id)
		authenticated.emit()
		
	except:
		var error = "Failed to authenticate with EOS"
		push_error(error)
		authentication_failed.emit(error)

func authenticate_user(username: String, password: String) -> void:
	"""Authenticate with username and password"""
	print("Authenticating user: " + username)
	
	# Call EOS authentication endpoint
	# var response = await _eos_api_call("/auth/login", {"username": username, "password": password})
	# if response.success:
	#     is_authenticated = true
	#     user_id = response.user_id
	#     authenticated.emit()
	# else:
	#     authentication_failed.emit(response.error)

# ============================================================================
# LOBBY MANAGEMENT
# ============================================================================

func create_lobby(lobby_name: String, max_players: int = 2, is_private: bool = false) -> String:
	"""Create a new lobby for hosting a game"""
	print("Creating lobby: " + lobby_name)
	
	if not is_authenticated:
		push_error("Not authenticated. Cannot create lobby.")
		return ""
	
	var lobby_data = {
		"name": lobby_name,
		"owner_id": user_id,
		"max_players": max_players,
		"current_players": 1,
		"is_private": is_private,
		"created_at": Time.get_ticks_msec(),
		"game_mode": "pvp",
		"room_code": _generate_room_code(),
		"status": "waiting"
	}
	
	# Store lobby locally (in production, this would be stored on EOS backend)
	var lobby_id = "lobby_" + account_id + "_" + str(Time.get_ticks_msec())
	active_lobbies[lobby_id] = lobby_data
	current_lobby_id = lobby_id
	is_lobby_owner = true
	
	print("Lobby created with ID: " + lobby_id)
	print("Room code: " + lobby_data.room_code)
	
	lobby_created.emit(lobby_id)
	return lobby_id

func search_lobbies(search_filter: Dictionary = {}) -> void:
	"""Search for available lobbies to join"""
	print("Searching for lobbies...")
	
	if not is_authenticated:
		push_error("Not authenticated. Cannot search lobbies.")
		return
	
	# In production, this would query EOS Lobbies API
	# For now, we'll search our local lobby list
	lobbies_found.clear()
	
	for lobby_id: String in active_lobbies:
		var lobby = active_lobbies[lobby_id]
		
		# Apply filters
		if "game_mode" in search_filter and lobby.game_mode != search_filter["game_mode"]:
			continue
		if "status" in search_filter and lobby.status != search_filter["status"]:
			continue
		if lobby.current_players >= lobby.max_players:
			continue
		
		lobbies_found.append({
			"id": lobby_id,
			"name": lobby.name,
			"owner": lobby.owner_id,
			"players": str(lobby.current_players) + "/" + str(lobby.max_players),
			"room_code": lobby.room_code
		})
	
	print("Found " + str(lobbies_found.size()) + " lobbies")
	lobby_search_complete.emit(lobbies_found)

func join_lobby_by_code(room_code: String) -> bool:
	"""Join a lobby using its room code"""
	print("Attempting to join lobby with code: " + room_code)
	
	if not is_authenticated:
		push_error("Not authenticated. Cannot join lobby.")
		return false
	
	# Find lobby by room code
	var target_lobby_id = ""
	for lobby_id: String in active_lobbies:
		if active_lobbies[lobby_id].room_code == room_code:
			target_lobby_id = lobby_id
			break
	
	if target_lobby_id.is_empty():
		var error = "Lobby not found with code: " + room_code
		push_error(error)
		return false
	
	# Check if lobby is full
	var lobby = active_lobbies[target_lobby_id]
	if lobby.current_players >= lobby.max_players:
		push_error("Lobby is full")
		return false
	
	# Join the lobby
	current_lobby_id = target_lobby_id
	lobby.current_players += 1
	is_lobby_owner = false
	
	print("Successfully joined lobby: " + target_lobby_id)
	lobby_joined.emit(target_lobby_id)
	
	return true

func join_lobby_by_id(lobby_id: String) -> bool:
	"""Join a lobby by its ID"""
	print("Attempting to join lobby: " + lobby_id)
	
	if not is_authenticated:
		push_error("Not authenticated. Cannot join lobby.")
		return false
	
	if not lobby_id in active_lobbies:
		push_error("Lobby not found: " + lobby_id)
		return false
	
	var lobby = active_lobbies[lobby_id]
	if lobby.current_players >= lobby.max_players:
		push_error("Lobby is full")
		return false
	
	current_lobby_id = lobby_id
	lobby.current_players += 1
	is_lobby_owner = false
	
	lobby_joined.emit(lobby_id)
	return true

func leave_lobby() -> void:
	"""Leave the current lobby"""
	if current_lobby_id.is_empty():
		return
	
	if current_lobby_id in active_lobbies:
		var lobby = active_lobbies[current_lobby_id]
		lobby.current_players = max(0, lobby.current_players - 1)
		
		# If owner left and no players, remove lobby
		if is_lobby_owner and lobby.current_players == 0:
			active_lobbies.erase(current_lobby_id)
	
	current_lobby_id = ""
	is_lobby_owner = false
	print("Left lobby")

# ============================================================================
# MATCHMAKING
# ============================================================================

func start_matchmaking(game_mode: String = "pvp") -> void:
	"""Start searching for opponents via matchmaking"""
	print("Starting matchmaking for game mode: " + game_mode)
	
	if not is_authenticated:
		push_error("Not authenticated. Cannot start matchmaking.")
		return
	
	matchmaking_in_progress = true
	matchmaking_started.emit()
	
	# Simulate matchmaking (in production, this would connect to EOS Matchmaking)
	await get_tree().create_timer(2.0).timeout
	
	# For standalone/testing, create an instant match
	var session_id = _generate_session_id()
	matchmaking_session = {
		"session_id": session_id,
		"game_mode": game_mode,
		"players": [user_id],
		"status": "matched"
	}
	
	matchmaking_in_progress = false
	matchmaking_complete.emit(session_id)
	print("Matchmaking complete! Session ID: " + session_id)

func cancel_matchmaking() -> void:
	"""Cancel active matchmaking"""
	if matchmaking_in_progress:
		matchmaking_in_progress = false
		print("Matchmaking cancelled")

# ============================================================================
# P2P NETWORKING
# ============================================================================

func start_p2p_session(peer_user_id: String) -> void:
	"""Initialize P2P session with another player"""
	print("Starting P2P session with peer: " + peer_user_id)
	
	if not is_authenticated:
		push_error("Not authenticated. Cannot start P2P session.")
		return
	
	# In production, this would use EOS P2P API for NAT traversal
	# For now, we create a session locally
	var session_key = _generate_session_key(user_id, peer_user_id)
	p2p_sessions[session_key] = {
		"peer_id": peer_user_id,
		"status": "active",
		"created_at": Time.get_ticks_msec(),
		"latency_ms": randi_range(10, 100)
	}
	
	peer_connected.emit(peer_user_id)
	print("P2P session established with latency: " + str(p2p_sessions[session_key].latency_ms) + "ms")

func send_p2p_message(peer_user_id: String, message: Dictionary) -> bool:
	"""Send a message through P2P to another player"""
	var session_key = _generate_session_key(user_id, peer_user_id)
	
	if not session_key in p2p_sessions:
		push_error("No P2P session with peer: " + peer_user_id)
		return false
	
	# In production, this would send through EOS P2P API
	print("Sending P2P message to " + peer_user_id + ": " + str(message))
	return true

func close_p2p_session(peer_user_id: String) -> void:
	"""Close P2P session with a peer"""
	var session_key = _generate_session_key(user_id, peer_user_id)
	
	if session_key in p2p_sessions:
		p2p_sessions.erase(session_key)
		peer_disconnected.emit(peer_user_id)
		print("P2P session closed with: " + peer_user_id)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _generate_room_code() -> String:
	"""Generate a unique room code for the lobby"""
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code

func _generate_session_id() -> String:
	"""Generate a unique session ID"""
	return "session_" + str(Time.get_ticks_msec()) + "_" + str(randi())

func _generate_session_key(user1: String, user2: String) -> String:
	"""Generate a consistent session key for two users"""
	var users = [user1, user2]
	users.sort()
	return users[0] + "_" + users[1]

func get_current_lobby_info() -> Dictionary:
	"""Get information about the current lobby"""
	if current_lobby_id.is_empty() or not current_lobby_id in active_lobbies:
		return {}
	
	var lobby = active_lobbies[current_lobby_id]
	return {
		"id": current_lobby_id,
		"name": lobby.name,
		"room_code": lobby.room_code,
		"owner": lobby.owner_id,
		"players": lobby.current_players,
		"max_players": lobby.max_players,
		"is_owner": is_lobby_owner
	}

func get_user_id() -> String:
	"""Get the current user's EOS user ID"""
	return user_id

func get_account_id() -> String:
	"""Get the current user's EOS account ID"""
	return account_id

func is_authenticated_user() -> bool:
	"""Check if user is authenticated"""
	return is_authenticated

func get_all_lobbies() -> Array:
	"""Get all active lobbies"""
	return lobbies_found

# ============================================================================
# API HELPER (for production EOS integration)
# ============================================================================

func _eos_api_call(endpoint: String, data: Dictionary = {}) -> Dictionary:
	"""Helper function for EOS API calls (placeholder for production)"""
	# In production, implement actual HTTP calls to EOS backend
	# using HTTPRequest or similar
	
	# Example structure:
	# var http = HTTPRequest.new()
	# var headers = ["Authorization: Bearer " + access_token]
	# var response = await http.request(eos_url + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	
	return {"success": true, "data": {}}

func shutdown() -> void:
	"""Clean up EOS resources"""
	print("Shutting down EOS Manager")
	
	# Close all P2P sessions
	for session_key in p2p_sessions:
		var session = p2p_sessions[session_key]
		close_p2p_session(session.peer_id)
	
	# Leave current lobby
	leave_lobby()
	
	is_authenticated = false

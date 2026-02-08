extends Node
class_name EOSManager

# State
var local_user_id: String = ""
var is_authenticated: bool = false
var current_lobby_id: String = ""
var is_lobby_owner: bool = false

# Lobbies cache
var lobbies_found: Array = []
var current_lobby_data: Dictionary = {}

# P2P Sessions
var p2p_sessions: Dictionary = {}

# Signals
signal authenticated(user_id: String)
signal authentication_failed(error: String)
signal lobby_created(lobby_id: String, room_code: String)
signal lobby_joined(lobby_id: String, owner_id: String)
signal lobby_search_complete(lobbies: Array)
signal matchmaking_started
signal matchmaking_complete(opponent_id: String)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)
signal p2p_message_received(peer_id: String, data: Dictionary)
signal error_occurred(error_code: int, error_message: String)

func _ready() -> void:
	set_process(true)
	print("EOSManager ready - waiting for EOS authentication from login.gd")

# ============================================================================
# AUTHENTICATION
# ============================================================================

func notify_authentication(user_id: String) -> void:
	"""Called by login.gd when EOS authentication completes"""
	if user_id.is_empty():
		authentication_failed.emit("Authentication failed")
		return
	
	local_user_id = user_id
	is_authenticated = true
	print("EOSManager: Authenticated as " + user_id)
	authenticated.emit(user_id)

# ============================================================================
# LOBBY MANAGEMENT
# ============================================================================

func create_lobby(lobby_name: String, max_players: int = 2, is_private: bool = false) -> void:
	"""Create a new lobby"""
	if not is_authenticated:
		error_occurred.emit(-1, "Not authenticated")
		return
	
	print("Creating lobby: " + lobby_name)
	
	var lobby_id = "eos_lobby_" + str(randi())
	var room_code = _generate_room_code()
	
	current_lobby_id = lobby_id
	is_lobby_owner = true
	
	current_lobby_data = {
		"id": lobby_id,
		"name": lobby_name,
		"room_code": room_code,
		"max_members": max_players,
		"members": [local_user_id],
		"owner": local_user_id,
		"is_private": is_private
	}
	
	print("Lobby created: ID=" + lobby_id + ", Code=" + room_code)
	lobby_created.emit(lobby_id, room_code)

func search_lobbies(_game_mode: String = "pvp") -> void:
	"""Search for available lobbies"""
	if not is_authenticated:
		push_error("Not authenticated")
		return
	
	print("Searching for lobbies...")
	
	# In a real implementation, this would query the EOS backend
	# For now, return existing lobbies from network system
	lobbies_found.clear()
	
	# Emit completion
	await get_tree().process_frame
	lobby_search_complete.emit(lobbies_found)

func join_lobby_by_id(lobby_id: String) -> void:
	"""Join a specific lobby by ID"""
	if not is_authenticated:
		push_error("Not authenticated")
		return
	
	print("Joining lobby: " + lobby_id)
	
	current_lobby_id = lobby_id
	is_lobby_owner = false
	
	# In real implementation, fetch owner ID from EOS
	var owner_id = "eos_user_owner"
	
	lobby_joined.emit(lobby_id, owner_id)

func join_lobby_by_code(room_code: String) -> void:
	"""Join a lobby using room code"""
	if not is_authenticated:
		push_error("Not authenticated")
		return
	
	print("Joining lobby by code: " + room_code)
	
	# Map room code to lobby ID (in real system, query EOS)
	var lobby_id = "eos_lobby_" + room_code
	join_lobby_by_id(lobby_id)

func leave_lobby() -> void:
	"""Leave the current lobby"""
	if current_lobby_id.is_empty():
		return
	
	print("Leaving lobby: " + current_lobby_id)
	current_lobby_id = ""
	is_lobby_owner = false
	current_lobby_data.clear()

# ============================================================================
# P2P NETWORKING
# ============================================================================

func send_p2p_message(peer_user_id: String, _message: Dictionary) -> bool:
	"""Send a message via P2P to another player"""
	if local_user_id.is_empty() or peer_user_id.is_empty():
		return false
	
	# In a real implementation, this would use EOS P2P
	print("Sending P2P message to " + peer_user_id)
	
	# Message would be sent via EOS P2P interface
	# For now, just return success
	return true

func _on_peer_connected(peer_id: String) -> void:
	"""Called when a peer connects"""
	p2p_sessions[peer_id] = {"status": "connected"}
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: String) -> void:
	"""Called when a peer disconnects"""
	if peer_id in p2p_sessions:
		p2p_sessions.erase(peer_id)
	peer_disconnected.emit(peer_id)

# ============================================================================
# MATCHMAKING
# ============================================================================

func start_matchmaking(_game_mode: String = "pvp") -> void:
	"""Start matchmaking"""
	print("Starting matchmaking...")
	matchmaking_started.emit()
	
	# Simulate finding opponent
	await get_tree().create_timer(2.0).timeout
	
	var opponent_id = "eos_opponent_" + str(randi())
	matchmaking_complete.emit(opponent_id)

func cancel_matchmaking() -> void:
	"""Cancel matchmaking"""
	print("Matching cancelled")

# ============================================================================
# PROCESSING
# ============================================================================

func _process(_delta: float) -> void:
	"""Poll for P2P messages and state changes"""
	# In real implementation, process EOS events here
	pass

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _generate_room_code() -> String:
	"""Generate a unique 6-character room code"""
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code

# ============================================================================
# ACCESSORS
# ============================================================================

func get_local_user_id() -> String:
	"""Get the current user's ID"""
	return local_user_id

func get_current_lobby_id() -> String:
	"""Get the current lobby ID"""
	return current_lobby_id

func is_lobby_host() -> bool:
	"""Check if current user is the lobby host"""
	return is_lobby_owner

func get_current_lobby_info() -> Dictionary:
	"""Get information about the current lobby"""
	return current_lobby_data

func get_all_lobbies() -> Array:
	"""Get all searched lobbies"""
	return lobbies_found

func is_authenticated_user() -> bool:
	"""Check if user is authenticated"""
	return is_authenticated

func shutdown() -> void:
	"""Clean up resources"""
	print("Shutting down EOSManager")
	leave_lobby()
	is_authenticated = false

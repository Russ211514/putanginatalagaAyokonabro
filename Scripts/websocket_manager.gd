extends Node
class_name WebSocketManager

# WebSocket client for multiplayer
var websocket_client: WebSocketPeer
var websocket_url: String = "ws://localhost:8080"
var is_connected: bool = false
var reconnect_attempts: int = 0
var max_reconnect_attempts: int = 5
var reconnect_delay: float = 2.0

# Current session
var session_id: String = ""
var player_id: String = ""
var opponent_player_id: String = ""
var current_lobby_id: String = ""
var is_lobby_owner: bool = false

# Lobbies data
var lobbies_found: Array = []
var active_lobbies: Dictionary = {}

# Signals
signal connected
signal disconnected
signal connection_failed(error: String)
signal message_received(data: Dictionary)
signal lobby_created(lobby_id: String, room_code: String)
signal lobby_joined(lobby_id: String)
signal lobby_search_complete(lobbies: Array)
signal matchmaking_started
signal matchmaking_complete(opponent_id: String)
signal peer_connected(peer_id: String)
signal peer_disconnected(peer_id: String)

func _ready() -> void:
	set_process(true)

func connect_to_server(url: String = websocket_url) -> void:
	"""Connect to the WebSocket multiplayer server"""
	print("Connecting to WebSocket server: " + url)
	websocket_url = url
	
	websocket_client = WebSocketPeer.new()
	var error = websocket_client.connect_to_url(url)
	
	if error != OK:
		push_error("Failed to connect to WebSocket: " + str(error))
		connection_failed.emit("Failed to connect to server")
		_attempt_reconnect()

func disconnect_from_server() -> void:
	"""Disconnect from the WebSocket server"""
	if websocket_client and websocket_client.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket_client.close()
		is_connected = false
		disconnected.emit()

func _process(delta: float) -> void:
	"""Handle WebSocket messages"""
	if not websocket_client:
		return
	
	websocket_client.poll()
	var state = websocket_client.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			if not is_connected:
				is_connected = true
				reconnect_attempts = 0
				connected.emit()
				print("Connected to WebSocket server")
			
			# Receive messages
			while websocket_client.get_available_packet_count() > 0:
				var message = websocket_client.get_message()
				if message is String:
					_handle_message(JSON.parse_string(message))
		
		WebSocketPeer.STATE_CLOSING:
			pass
		
		WebSocketPeer.STATE_CLOSED:
			if is_connected:
				is_connected = false
				disconnected.emit()
				_attempt_reconnect()

func _send_message(message_type: String, data: Dictionary = {}) -> void:
	"""Send a message to the server"""
	if not is_connected:
		push_error("Not connected to WebSocket server")
		return
	
	var message = {
		"type": message_type,
		"player_id": player_id,
		"data": data
	}
	
	websocket_client.send_text(JSON.stringify(message))
	print("Sent: " + message_type)

func _handle_message(message: Dictionary) -> void:
	"""Handle incoming WebSocket messages"""
	if not message or not "type" in message:
		return
	
	var msg_type = message.type
	var data = message.get("data", {})
	
	match msg_type:
		"lobby_created":
			current_lobby_id = data.lobby_id
			is_lobby_owner = true
			lobby_created.emit(data.lobby_id, data.room_code)
		
		"lobby_joined":
			current_lobby_id = data.lobby_id
			is_lobby_owner = false
			lobby_joined.emit(data.lobby_id)
		
		"lobbies_found":
			lobbies_found = data.lobbies
			lobby_search_complete.emit(lobbies_found)
		
		"matchmaking_started":
			matchmaking_started.emit()
		
		"match_found":
			opponent_player_id = data.opponent_id
			matchmaking_complete.emit(data.opponent_id)
		
		"peer_connected":
			peer_connected.emit(data.peer_id)
		
		"peer_disconnected":
			peer_disconnected.emit(data.peer_id)
		
		"message":
			message_received.emit(data)

# ============================================================================
# LOBBY MANAGEMENT
# ============================================================================

func create_lobby(lobby_name: String, max_players: int = 2) -> void:
	"""Create a lobby on the server"""
	_send_message("create_lobby", {
		"name": lobby_name,
		"max_players": max_players
	})

func search_lobbies(game_mode: String = "pvp") -> void:
	"""Search for available lobbies"""
	_send_message("search_lobbies", {
		"game_mode": game_mode
	})

func join_lobby_by_code(room_code: String) -> void:
	"""Join a lobby using room code"""
	_send_message("join_lobby_by_code", {
		"room_code": room_code
	})

func leave_lobby() -> void:
	"""Leave the current lobby"""
	if not current_lobby_id.is_empty():
		_send_message("leave_lobby", {
			"lobby_id": current_lobby_id
		})
		current_lobby_id = ""
		is_lobby_owner = false

# ============================================================================
# MATCHMAKING
# ============================================================================

func start_matchmaking(game_mode: String = "pvp") -> void:
	"""Start matchmaking"""
	_send_message("start_matchmaking", {
		"game_mode": game_mode
	})

func cancel_matchmaking() -> void:
	"""Cancel matchmaking"""
	_send_message("cancel_matchmaking", {})

# ============================================================================
# PRIVATE FUNCTIONS
# ============================================================================

func _attempt_reconnect() -> void:
	"""Attempt to reconnect to the server"""
	if reconnect_attempts >= max_reconnect_attempts:
		push_error("Failed to reconnect to WebSocket server after " + str(max_reconnect_attempts) + " attempts")
		connection_failed.emit("Connection lost")
		return
	
	reconnect_attempts += 1
	print("Reconnecting... attempt " + str(reconnect_attempts) + "/" + str(max_reconnect_attempts))
	await get_tree().create_timer(reconnect_delay).timeout
	connect_to_server()

func set_player_id(id: String) -> void:
	"""Set the player ID for this connection"""
	player_id = id

func get_current_lobby_info() -> Dictionary:
	"""Get info about current lobby"""
	return {
		"id": current_lobby_id,
		"is_owner": is_lobby_owner
	}

func shutdown() -> void:
	"""Clean up WebSocket connection"""
	disconnect_from_server()

extends Node
class_name EOSManager

# State
var local_user_id: String = ""
var user_account_id: String = ""
var is_authenticated: bool = false
var current_lobby_id: String = ""
var is_lobby_owner: bool = false
var matchmaking_in_progress: bool = false

# Lobbies cache
var lobbies_found: Array = []
var active_lobbies: Dictionary = {}
var current_lobby_data: Dictionary = {}

# P2P Sessions
var p2p_sessions: Dictionary = {}
var p2p_socket_id: int = 0  # Socket ID for P2P communication

# Signals
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
signal p2p_message_received(peer_id: String, data: Dictionary)
signal error_occurred(error_code: int, error_message: String)

func _ready() -> void:
	# Connect to EOS signals
	IEOS.auth_interface_login_callback.connect(_on_auth_login)
	IEOS.auth_interface_logout_callback.connect(_on_auth_logout)
	IEOS.lobbies_interface_update_received_callback.connect(_on_lobby_update)
	IEOS.lobbies_interface_join_lobby_callback.connect(_on_join_lobby)
	IEOS.lobbies_interface_create_lobby_callback.connect(_on_create_lobby)
	IEOS.lobbies_interface_find_lobbies_callback.connect(_on_find_lobbies)
	IEOS.lobbies_interface_leave_lobby_callback.connect(_on_leave_lobby)
	IEOS.p2p_interface_on_peer_connection_request_callback.connect(_on_peer_connection_request)
	IEOS.p2p_interface_on_peer_connection_closed_callback.connect(_on_peer_connection_closed)
	
	set_process(true)

# ============================================================================
# AUTHENTICATION
# ============================================================================

func login_with_eos() -> void:
	"""Login with EOS using stored credentials"""
	print("Attempting EOS login...")
	
	# Check if already logged in
	if is_authenticated:
		print("Already authenticated")
		authenticated.emit(local_user_id)
		return
	
	# The actual login is handled in login.gd
	# This manager will receive the callback when login completes

func _on_auth_login(data: Dictionary) -> void:
	"""Called when EOS authentication completes"""
	if not data.success:
		print("EOS Login failed: ", data)
		authentication_failed.emit("Login failed")
		return
	
	local_user_id = data.local_user_id
	print("Authenticated with local_user_id: " + str(local_user_id))
	is_authenticated = true
	
	# Get user info
	_get_user_info()
	authenticated.emit(local_user_id)

func _get_user_info() -> void:
	"""Get user information from EOS"""
	if local_user_id.is_empty():
		return
	
	var opts = EOS.UserInfo.CopyUserInfoOptions.new()
	opts.local_user_id = local_user_id
	opts.target_user_id = local_user_id
	
	var user_info = EOS.UserInfo.get_user_info_interface().copy_user_info(opts)
	if user_info:
		print("User: " + user_info.display_name)
		user_account_id = user_info.user_id

func _on_auth_logout(data: Dictionary) -> void:
	"""Called when logged out"""
	print("Logged out from EOS")
	is_authenticated = false

# ============================================================================
# LOBBY MANAGEMENT
# ============================================================================

func create_lobby(lobby_name: String, max_players: int = 2, is_private: bool = false) -> void:
	"""Create a new lobby using EOS Lobbies API"""
	if not is_authenticated or local_user_id.is_empty():
		push_error("Not authenticated. Cannot create lobby.")
		error_occurred.emit(-1, "Not authenticated")
		return
	
	print("Creating lobby: " + lobby_name)
	
	var create_opts = EOS.Lobbies.CreateLobbyOptions.new()
	create_opts.local_user_id = local_user_id
	create_opts.max_members = max_players
	create_opts.permission_level = EOS.Lobbies.LobbyPermissionLevel.Publicaudible if not is_private else EOS.Lobbies.LobbyPermissionLevel.Inviteonly
	create_opts.presence_enabled = true
	create_opts.bucket_id = "pvp_match"
	
	var lobby_data_map = EOS.Lobbies.AttributeDataMap.new()
	lobby_data_map.insert("name", lobby_name)
	lobby_data_map.insert("gamemode", "pvp")
	create_opts.lobby_data = lobby_data_map
	
	EOS.Lobbies.LobbiesInterface.create_lobby(create_opts)

func _on_create_lobby(data: Dictionary) -> void:
	"""Called when lobby creation completes"""
	if not EOS.is_success(data.result_code):
		print("Failed to create lobby: " + EOS.result_str(data.result_code))
		error_occurred.emit(data.result_code, "Failed to create lobby")
		return
	
	var lobby_id = data.lobby_id
	local_user_id = data.local_user_id
	current_lobby_id = lobby_id
	is_lobby_owner = true
	
	print("Lobby created successfully: " + lobby_id)
	
	# Generate room code
	var room_code = _generate_room_code()
	
	# Store lobby info
	current_lobby_data = {
		"id": lobby_id,
		"name": "Game Lobby",
		"room_code": room_code,
		"max_members": 2,
		"members": 1,
		"owner": local_user_id
	}
	
	lobby_created.emit(lobby_id, room_code)

func search_lobbies(game_mode: String = "pvp") -> void:
	"""Search for available lobbies"""
	if not is_authenticated:
		push_error("Not authenticated. Cannot search lobbies.")
		return
	
	print("Searching for lobbies...")
	
	var search_opts = EOS.Lobbies.FindLobbiesOptions.new()
	search_opts.local_user_id = local_user_id
	search_opts.max_results = 10
	
	# Add search criteria
	var search_criteria = EOS.Lobbies.LobbySearchFilter.new()
	search_criteria.comparison = EOS.Lobbies.ComparisonOp.Equal
	search_criteria.attribute.key = "gamemode"
	search_criteria.attribute.asString = game_mode
	
	var params = EOS.Lobbies.LobbySearchParameters.new()
	params.filters = [search_criteria]
	search_opts.search_parameters = params
	
	EOS.Lobbies.LobbiesInterface.find_lobbies(search_opts)

func _on_find_lobbies(data: Dictionary) -> void:
	"""Called when lobby search completes"""
	if not EOS.is_success(data.result_code):
		print("Failed to search lobbies: " + EOS.result_str(data.result_code))
		lobbies_found.clear()
		lobby_search_complete.emit([])
		return
	
	var search_handle = data.search_result_handle
	lobbies_found.clear()
	
	if not search_handle:
		print("No lobbies found")
		lobby_search_complete.emit([])
		return
	
	var count_opts = EOS.Lobbies.GetSearchResultCountOptions.new()
	count_opts.search_handle = search_handle
	var lobby_count = EOS.Lobbies.LobbiesInterface.get_search_result_count(count_opts)
	
	print("Found %d lobbies" % lobby_count)
	
	for i in range(lobby_count):
		var details_opts = EOS.Lobbies.CopyLobbyDetailsHandleOptions.new()
		details_opts.search_handle = search_handle
		details_opts.lobby_index = i
		
		var lobby_details = EOS.Lobbies.LobbiesInterface.copy_lobby_details_handle(details_opts)
		if not lobby_details:
			continue
		
		var lobby_info = _extract_lobby_info(lobby_details)
		if lobby_info:
			lobbies_found.append(lobby_info)
	
	lobby_search_complete.emit(lobbies_found)

func join_lobby_by_id(lobby_id: String) -> void:
	"""Join a specific lobby"""
	if not is_authenticated:
		push_error("Not authenticated")
		return
	
	print("Joining lobby: " + lobby_id)
	
	var join_opts = EOS.Lobbies.JoinLobbyOptions.new()
	join_opts.local_user_id = local_user_id
	join_opts.lobby_id = lobby_id
	join_opts.presence_enabled = true
	
	EOS.Lobbies.LobbiesInterface.join_lobby(join_opts)

func _on_join_lobby(data: Dictionary) -> void:
	"""Called when joining a lobby completes"""
	if not EOS.is_success(data.result_code):
		print("Failed to join lobby: " + EOS.result_str(data.result_code))
		error_occurred.emit(data.result_code, "Failed to join lobby")
		return
	
	var lobby_id = data.lobby_id
	current_lobby_id = lobby_id
	is_lobby_owner = false
	
	print("Successfully joined lobby: " + lobby_id)
	
	# Get owner info
	var owner_id = data.lobby_owner
	
	lobby_joined.emit(lobby_id, owner_id)
	
	# Initialize P2P with owner
	if not owner_id.is_empty():
		_initiate_p2p_connection(owner_id)

func leave_lobby() -> void:
	"""Leave the current lobby"""
	if current_lobby_id.is_empty():
		return
	
	print("Leaving lobby: " + current_lobby_id)
	
	var leave_opts = EOS.Lobbies.LeaveLobbyOptions.new()
	leave_opts.local_user_id = local_user_id
	leave_opts.lobby_id = current_lobby_id
	
	EOS.Lobbies.LobbiesInterface.leave_lobby(leave_opts)

func _on_leave_lobby(data: Dictionary) -> void:
	"""Called when leaving a lobby"""
	print("Left lobby")
	current_lobby_id = ""
	is_lobby_owner = false

func _on_lobby_update(data: Dictionary) -> void:
	"""Called when lobby is updated"""
	var lobby_id = data.lobby_id
	print("Lobby updated: " + lobby_id)
	
	# Get updated member count
	var details_opts = EOS.Lobbies.CopyLobbyDetailsHandleOptions.new()
	details_opts.lobby_id = lobby_id
	details_opts.local_user_id = local_user_id
	
	var lobby_details = EOS.Lobbies.LobbiesInterface.copy_lobby_details_handle(details_opts)
	if lobby_details:
		var member_count_opts = EOS.Lobbies.GetMemberCountOptions.new()
		member_count_opts.lobby_details_handle = lobby_details
		var member_count = EOS.Lobbies.LobbiesInterface.get_member_count(member_count_opts)
		lobby_member_updated.emit(lobby_id, member_count)

# ============================================================================
# P2P NETWORKING
# ============================================================================

func _initiate_p2p_connection(peer_user_id: String) -> void:
	"""Send a P2P connection request"""
	if peer_user_id.is_empty():
		return
	
	print("Initiating P2P connection with: " + peer_user_id)
	
	# EOS P2P connection is established automatically when sending data
	# Just store the peer ID
	var connection_key = _get_connection_key(local_user_id, peer_user_id)
	p2p_sessions[connection_key] = {
		"peer_id": peer_user_id,
		"status": "initiating",
		"created_at": Time.get_ticks_msec()
	}

func send_p2p_message(peer_user_id: String, message: Dictionary) -> bool:
	"""Send a message via P2P to another player"""
	if local_user_id.is_empty() or peer_user_id.is_empty():
		return false
	
	var message_json = JSON.stringify(message)
	var message_bytes = message_json.to_utf8_buffer()
	
	var send_opts = EOS.P2P.SendPacketOptions.new()
	send_opts.local_user_id = local_user_id
	send_opts.remote_user_id = peer_user_id
	send_opts.socket_id = p2p_socket_id
	send_opts.channel = 0
	send_opts.data = message_bytes
	send_opts.reliable = true  # Use UDP with reliability
	
	var result = EOS.P2P.P2PInterface.send_packet(send_opts)
	return EOS.is_success(result)

func _on_peer_connection_request(data: Dictionary) -> void:
	"""Called when receiving a P2P connection request"""
	var remote_user_id = data.remote_user_id
	print("P2P connection request from: " + remote_user_id)
	
	# Accept the connection
	var accept_opts = EOS.P2P.AcceptConnectionOptions.new()
	accept_opts.local_user_id = local_user_id
	accept_opts.remote_user_id = remote_user_id
	accept_opts.socket_id = p2p_socket_id
	
	EOS.P2P.P2PInterface.accept_connection(accept_opts)
	
	var connection_key = _get_connection_key(local_user_id, remote_user_id)
	p2p_sessions[connection_key] = {
		"peer_id": remote_user_id,
		"status": "connected",
		"created_at": Time.get_ticks_msec()
	}
	
	peer_connected.emit(remote_user_id)

func _on_peer_connection_closed(data: Dictionary) -> void:
	"""Called when a P2P connection closes"""
	var remote_user_id = data.remote_user_id
	print("P2P connection closed: " + remote_user_id)
	
	var connection_key = _get_connection_key(local_user_id, remote_user_id)
	if connection_key in p2p_sessions:
		p2p_sessions.erase(connection_key)
	
	peer_disconnected.emit(remote_user_id)

# ============================================================================
# PROCESSING
# ============================================================================

func _process(delta: float) -> void:
	"""Handle P2P messages"""
	if local_user_id.is_empty():
		return
	
	# Receive P2P packets
	var receive_opts = EOS.P2P.ReceivePacketOptions.new()
	receive_opts.local_user_id = local_user_id
	receive_opts.max_data_size = 4096
	receive_opts.socket_id = p2p_socket_id
	
	var packet_data = EOS.P2P.P2PInterface.receive_packet(receive_opts)
	if packet_data:
		var peer_id = packet_data.remote_user_id
		var data_bytes = packet_data.data
		var data_string = data_bytes.get_string_from_utf8()
		
		try:
			var message = JSON.parse_string(data_string)
			if message:
				p2p_message_received.emit(peer_id, message)
		except:
			print("Failed to parse P2P message")

# ============================================================================
# MATCHMAKING (Optional - using Lobbies as foundation)
# ============================================================================

func start_matchmaking(game_mode: String = "pvp") -> void:
	"""Start matchmaking by searching for lobbies"""
	print("Starting matchmaking...")
	matchmaking_in_progress = true
	matchmaking_started.emit()
	
	# Search for lobbies with available slots
	search_lobbies(game_mode)
	
	# If no lobbies found, create one
	await get_tree().create_timer(1.0).timeout
	if lobbies_found.is_empty():
		create_lobby("Auto Match", 2, false)
	else:
		# Join the first available lobby
		var selected_lobby = lobbies_found[0]
		join_lobby_by_id(selected_lobby.id)
	
	matchmaking_in_progress = false

func cancel_matchmaking() -> void:
	"""Cancel active matchmaking"""
	matchmaking_in_progress = false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _extract_lobby_info(lobby_details) -> Dictionary:
	"""Extract lobby information from EOS handle"""
	if not lobby_details:
		return {}
	
	var lobby_info_opts = EOS.Lobbies.LobbyDetailsGetLobbyIdOptions.new()
	lobby_info_opts.lobby_details_handle = lobby_details
	var lobby_id = EOS.Lobbies.LobbiesInterface.lobby_details_get_lobby_id(lobby_info_opts)
	
	var member_count_opts = EOS.Lobbies.GetMemberCountOptions.new()
	member_count_opts.lobby_details_handle = lobby_details
	var member_count = EOS.Lobbies.LobbiesInterface.get_member_count(member_count_opts)
	
	var max_members_opts = EOS.Lobbies.GetMaxMembersOptions.new()
	max_members_opts.lobby_details_handle = lobby_details
	var max_members = EOS.Lobbies.LobbiesInterface.get_max_members(max_members_opts)
	
	var owner_id_opts = EOS.Lobbies.GetLobbyOwnerOptions.new()
	owner_id_opts.lobby_details_handle = lobby_details
	var owner_id = EOS.Lobbies.LobbiesInterface.get_lobby_owner(owner_id_opts)
	
	return {
		"id": lobby_id,
		"members": member_count,
		"max_members": max_members,
		"owner": owner_id,
		"players": str(member_count) + "/" + str(max_members)
	}

func _generate_room_code() -> String:
	"""Generate a unique 6-character room code"""
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code

func _get_connection_key(user1: String, user2: String) -> String:
	"""Generate a consistent key for a P2P connection"""
	var users = [user1, user2]
	users.sort()
	return users[0] + "_" + users[1]

# ============================================================================
# ACCESSORS
# ============================================================================

func get_local_user_id() -> String:
	"""Get the current user's EOS user ID"""
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
	"""Clean up EOS resources"""
	print("Shutting down EOS Manager")
	leave_lobby()
	
	# Close all P2P connections
	for key in p2p_sessions:
		var session = p2p_sessions[key]
		var close_opts = EOS.P2P.CloseConnectionOptions.new()
		close_opts.local_user_id = local_user_id
		close_opts.remote_user_id = session.peer_id
		close_opts.socket_id = p2p_socket_id
		EOS.P2P.P2PInterface.close_connection(close_opts)
	
	is_authenticated = false

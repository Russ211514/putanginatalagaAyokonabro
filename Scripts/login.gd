extends Control

@onready var display = $MessageDisplay
@onready var peer: EOSGMultiplayerPeer = EOSGMultiplayerPeer.new()

@export var game_scene: PackedScene

var local_user_id = ""
var is_server = false
var peer_user_id = 0

var local_lobby: HLobby

func _ready() -> void:
	display.text = "STARTING"
	# Initialize the SDK
	var init_opts = EOS.Platform.InitializeOptions.new()
	init_opts.product_name = EOSCredentials.PRODUCT_NAME
	init_opts.product_version = EOSCredentials.PRODUCT_ID

	var init_results := EOS.Platform.PlatformInterface.initialize(init_opts)
	if init_results != EOS.Result.Success:
		printerr("Failed to initialize EOS SDK: " + EOS.result_str(init_results))
		display.text = "Failed to initialize EOS SDK: " + EOS.result_str(init_results)
		return
	print("Initialized EOS Platform")

	# Create EOS platform
	var create_opts = EOS.Platform.CreateOptions.new()
	create_opts.product_id = EOSCredentials.PRODUCT_ID
	create_opts.sandbox_id = EOSCredentials.SANDBOX_ID
	create_opts.deployment_id = EOSCredentials.DEPLOYMENT_ID
	create_opts.client_id = EOSCredentials.CLIENT_ID
	create_opts.client_secret = EOSCredentials.CLIENT_SECRET
	create_opts.encryption_key = EOSCredentials.ENCRYPTION_KEY
	
	var create_results = 0
	var attempt_count = 0
	create_results = EOS.Platform.PlatformInterface.create(create_opts)
	print("EOS Platform created")
	display.text = "WAITING"
	
	# Setup Logs from EOS
	EOS.get_instance().logging_interface_callback.connect(_on_logging_interface_callback)
	var res := EOS.Logging.set_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Info)
	if res != EOS.Result.Success:
		print("Failed to set log level: " + EOS.result_str(res))
		display.text = "Failed to set log level: " + EOS.result_str(res)
	
	EOS.get_instance().connect_interface_login_callback.connect(_on_connect_login_callback)
	
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	
	await HAuth.login_anonymous_async("User")

func _on_logging_interface_callback(msg) -> void:
	msg = EOS.Logging.LogMessage.from(msg) as EOS.Logging.LogMessage
	print("SDK %s | %s" % [msg.category, msg.message])
	
func _exit_tree() -> void:
	if is_server:
		local_lobby.destroy_async()

func _on_connect_login_callback(data: Dictionary) -> void:
	if not data.success:
		print("Login failed")
		EOS.print_result(data)
		display.text = "Login failed"
		return
	print_rich("[b]Login successful[/b]: local_user_id=", data.local_user_id)
	local_user_id = data.local_user_id
	HAuth.product_user_id = local_user_id
	display.text = "Successful login"
	await get_tree().create_timer(1.0).timeout
	if not await search_lobbies():
		display.text = "Trying again"
		await get_tree().create_timer(randf(0.1, 3)).timeout
		if not await search_lobbies():
			display.text = "Making game"
			await get_tree().create_timer(0.5).timeout
			create_lobby()

func create_lobby():
	var create_opts := EOS.Lobby.CreateLobbyOptions.new()
	create_opts.bucket_id = "Code_Arena"
	create_opts.max_lobby_members = 2
	
	var new_lobby = await HLobbies.create_lobby_async(create_opts)
	if new_lobby == null:
		display.text = "Lobby creation failed"
		return
	
	var result := peer.create_server("cdcodearena")
	if result != OK:
		printerr("Failed to create client: " + EOS.result_str(result))
		return
	multiplayer.multiplayer_peer = peer
	display.text = "Waiting for another player"
	$Timer.start()
	is_server = true
	$Temp.visible = false;
	
	local_lobby = new_lobby

func search_lobbies() -> bool:
	var lobbies = await HLobbies.search_by_bucket_id_async("Code_Arena")
	if not lobbies:
		printerr("No lobbies found")
		display.text = "No lobbies found"
		return false
	
	var lobby: HLobby = lobbies[0]
	await HLobbies.join_by_id_async(lobby.lobby_id)
	
	var result := peer.create_client("cdcodearena", lobby.owner_product_user_id)
	if result != OK:
		printerr("Failed to create client: " + EOS.result_str(result))
		return false
	multiplayer.multiplayer_peer = peer
	$Temp.visible = false
	display.text = "Found lobby"
	return true

func _on_peer_connected(peer_id: int) -> void:
	display.text = "Player %d connected" % peer_id
	print("Player %d connected" % peer_id)
	peer_user_id = peer_id
	$Timer.stop()
	await get_tree().create_timer(1.5).timeout
	start_game()

func _on_peer_disconnected(peer_id: int) -> void:
	display.text = "Player %d disconnected" % peer_id
	print("Player %d disconnected" % peer_id)
	
@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	$Temp.visible = false
	print("Game Started\n-------------")
	var game_instance = game_scene.instantiate()
	game_instance.set("IsServer", is_server)

func _anonymous_login() -> void:
	# Login using Device ID (no user interaction/credentials required)
	print("make dir", DirAccess.make_dir_recursive_absolute("user://eosg-cache"))

	var opts = EOS.Connect.CreateDeviceIdOptions.new()
	opts.device_model = OS.get_name() + " " + OS.get_model_name()
	EOS.Connect.ConnectInterface.create_device_id(opts)
	await EOS.get_instance().connect_interface_create_device_id_callback

	var credentials = EOS.Connect.Credentials.new()
	credentials.token = null
	credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken

	var login_options = EOS.Connect.LoginOptions.new()
	login_options.credentials = credentials
	var user_login_info = EOS.Connect.UserLoginInfo.new()
	user_login_info.display_name = "Anon User"
	login_options.user_login_info = user_login_info
	EOS.Connect.ConnectInterface.login(login_options)
	IEOS.connect_interface_login_callback.connect(_on_auth_interface_login_callback)


func _devauth_login():
	# Login using Dev Auth Tool
	var credentials = EOS.Auth.Credentials.new()
	credentials.type = EOS.Auth.LoginCredentialType.Developer
	credentials.id = "localhost:4545"
	credentials.token = "3ddelano"

	var login_opts = EOS.Auth.LoginOptions.new()
	login_opts.credentials = credentials
	login_opts.scope_flags = EOS.Auth.ScopeFlags.BasicProfile | EOS.Auth.ScopeFlags.FriendsList
	EOS.Auth.AuthInterface.login(login_opts)
	IEOS.auth_interface_login_callback.connect(_on_auth_interface_login_callback)


func _on_auth_interface_login_callback(data: Dictionary) -> void:
	if not data.success:
		print("Login failed")
		EOS.print_result(data)
		return

	print("Login successfull: local_user_id=", data.local_user_id)

extends "res://Scripts/game_battle_base.gd"

# Host-specific initialization and logic

func _ready() -> void:
	my_peer_id = multiplayer.get_unique_id()
	
	# Get opponent peer ID
	var peers = multiplayer.get_peers()
	print("[GameBattle HOST] My peer ID: ", my_peer_id)
	print("[GameBattle HOST] All connected peers: ", peers)
	print("[GameBattle HOST] Am I server? ", multiplayer.is_server())
	
	if peers.size() > 0:
		opponent_peer_id = peers[0]
		print("[GameBattle HOST] Opponent peer ID: ", opponent_peer_id)
	else:
		print("[GameBattle HOST] ERROR: No other peers found!")
		return
	
	# Initialize health bars
	player_health_bar.init_health(150)
	opponent_health_bar.init_health(150)
	player_health = 150
	opponent_health = 150
	
	# Reset battle state
	lose_label.visible = false
	win_label.visible = false
	player_defending = false
	player_timeout_triggered = false
	
	# Connect battle button signals
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	# Connect answer buttons
	if game_controller:
		var html_question = game_controller.get_node_or_null("html_question")
		if html_question:
			for button in html_question.get_children():
				if button is Button:
					button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Spawn players at spawn points
	# Host player on the left (spawn_point_1)
	var host_player = PLAYER_SCENE.instantiate()
	host_player.position = spawn_point_1.global_position
	$Background_Sprite.add_child(host_player)
	
	# Client player on the right (spawn_point_2), flipped horizontally
	var client_player = PLAYER_SCENE.instantiate()
	client_player.position = spawn_point_2.global_position
	# Flip horizontally by scaling the sprite
	var client_sprite = client_player.get_node_or_null("Sprite2D")
	if client_sprite:
		client_sprite.scale.x = -6  # Original is 6, negate it
	$Background_Sprite.add_child(client_player)
	
	# HOST-SPECIFIC: Tell the server this peer is ready
	report_peer_ready.rpc_id(1, my_peer_id)
	
	# HOST-SPECIFIC: Server waits for both peers to be ready
	print("[GameBattle HOST] SERVER: I am the server, waiting for both peers...")
	# Server tracks itself as ready
	peers_ready[my_peer_id] = true
	
	# Wait for other peer to signal ready (max 5 seconds)
	var wait_time = 0.0
	while peers_ready.size() < 2 and wait_time < 5.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	
	if peers_ready.size() >= 2:
		print("[GameBattle HOST] SERVER: Both peers ready! Calling initialize_battle.rpc()")
		initialize_battle.rpc()
	else:
		print("[GameBattle HOST] SERVER: ERROR: Not all peers ready after timeout! Ready: ", peers_ready.size())

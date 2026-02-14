extends Control
class_name GameBattleBase

# Preloads
const PLAYER_SCENE = preload("res://player/player.tscn")

# UI References
@onready var player_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var opponent_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var defend_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel
@onready var player_turn_timer_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel
@onready var battle_info = $BattleLayout/Info
@onready var question_info = $BattleLayout/QuestionInfo
@onready var game_controller = $BattleLayout/Control
@onready var lose_label = $BattleLayout/Lose
@onready var win_label = $BattleLayout/Win
@onready var options_menu = $BattleLayout/Battle/Options/Options
@onready var spawn_point_1 = $Background_Sprite/SpawnPoint
@onready var spawn_point_2 = $Background_Sprite/SpawnPoint2

# Action Buttons
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate

# Network Variables
var my_peer_id: int = 0
var opponent_peer_id: int = 0
var peers_ready: Dictionary = {}  # Track which peers are ready

# Battle State
var player_health: int = 150
var opponent_health: int = 150

var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var player_turn_time: float = 0.0
var player_turn_max_time: float = 35.0
var player_timeout_triggered: bool = false

var current_turn: String = ""  # "player" or "opponent"
var player_defending: bool = false
var current_action: String = ""
var battle_started: bool = false

# ==================== SHARED RPC FUNCTIONS ====================

@rpc("authority")
func report_peer_ready(peer_id: int) -> void:
	# Only server processes this
	peers_ready[peer_id] = true
	print("[GameBattle] SERVER: Peer ", peer_id, " reported ready. Total ready: ", peers_ready.size())

@rpc("authority", "call_local")
func initialize_battle() -> void:
	print("[GameBattle] initialize_battle called on peer: ", my_peer_id)
	battle_started = true
	
	# Host (server) always goes first
	print("[GameBattle] Host always goes first")
	var first_peer = my_peer_id  # Server (host) always starts
	print("[GameBattle] First turn goes to peer: ", first_peer)
	start_turn.rpc(first_peer)
	
	if question_info:
		question_info.hide()
	if battle_info:
		battle_info.show()

@rpc("any_peer", "call_local")
func start_turn(peer_id: int) -> void:
	print("[GameBattle] start_turn called for peer: ", peer_id, " (I am: ", my_peer_id, ")")
	current_turn = "player" if peer_id == my_peer_id else "opponent"
	player_turn_time = 0
	player_timeout_triggered = false
	print("[GameBattle] Current turn is now: ", current_turn)
	
	if current_turn == "player":
		if battle_info:
			battle_info.text = "YOUR TURN"
		if options_menu:
			options_menu.show()
		_options_menu_button_focus(0)
		
		# Set timer
		player_turn_max_time = 35.0
		player_turn_time = player_turn_max_time
		if player_turn_timer_label and player_turn_max_time > 0:
			player_turn_timer_label.show()
		
		if magic_button:
			magic_button.disabled = (magic_cooldown > 0)
		if ultimate_button:
			ultimate_button.disabled = (ultimate_cooldown > 0)
	else:
		if battle_info:
			battle_info.text = "OPPONENT'S TURN"
		if options_menu:
			options_menu.hide()
		if player_turn_timer_label:
			player_turn_timer_label.hide()

@rpc("any_peer", "call_local")
func _perform_action(peer_id: int, action: String, is_defending: bool = false) -> void:
	var damage = 0
	match action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	
	# Apply damage to opponent
	if peer_id == my_peer_id:
		# I'm attacking opponent
		opponent_health -= damage
		opponent_health_bar.health = opponent_health
	else:
		# Opponent is attacking me
		if is_defending:
			damage *= 0.75
		player_health -= damage
		player_health_bar.health = player_health
	
	# Check for victory
	if not await _check_victory():
		_switch_turn()

@rpc("any_peer", "call_local")
func _check_victory() -> bool:
	if player_health <= 0:
		lose_label.visible = true
		battle_started = false
		if options_menu:
			options_menu.hide()
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return true
	elif opponent_health <= 0:
		win_label.visible = true
		battle_started = false
		if options_menu:
			options_menu.hide()
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return true
	return false

# ==================== SHARED HELPER FUNCTIONS ====================

func _process(delta: float) -> void:
	if not battle_started:
		return
	
	# Update cooldowns
	if magic_cooldown > 0:
		magic_cooldown -= delta
		if magic_cooldown_label:
			magic_cooldown_label.text = "Magic: %.1f" % magic_cooldown
			magic_cooldown_label.show()
		if magic_cooldown <= 0:
			magic_cooldown = 0
			if magic_cooldown_label:
				magic_cooldown_label.hide()
			if current_turn == "player" and options_menu and options_menu.visible and magic_button:
				magic_button.disabled = false
	else:
		if magic_cooldown_label:
			magic_cooldown_label.hide()
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		if ultimate_cooldown_label:
			ultimate_cooldown_label.text = "Ult: %.1f" % ultimate_cooldown
			ultimate_cooldown_label.show()
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			if ultimate_cooldown_label:
				ultimate_cooldown_label.hide()
			if current_turn == "player" and options_menu and options_menu.visible and ultimate_button:
				ultimate_button.disabled = false
	else:
		if ultimate_cooldown_label:
			ultimate_cooldown_label.hide()
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		if defend_cooldown_label:
			defend_cooldown_label.text = "Defend: %.1f" % defend_cooldown
			defend_cooldown_label.show()
		if defend_cooldown <= 0:
			defend_cooldown = 0
			if defend_cooldown_label:
				defend_cooldown_label.hide()
			if current_turn == "player" and options_menu and options_menu.visible and defend_button:
				defend_button.disabled = false
	else:
		if defend_cooldown_label:
			defend_cooldown_label.hide()
	
	# Player turn timer
	if player_turn_time > 0 and current_turn == "player":
		player_turn_time -= delta
		if player_turn_timer_label:
			player_turn_timer_label.text = "Time: %.0fs" % max(0, player_turn_time)
			player_turn_timer_label.show()
		if player_turn_time <= 0 and not player_timeout_triggered:
			player_turn_time = 0
			player_timeout_triggered = true
			if player_turn_timer_label:
				player_turn_timer_label.hide()
			if question_info:
				question_info.text = "TIME RAN OUT"
				question_info.show()
			await get_tree().create_timer(2.0).timeout
			if question_info:
				question_info.hide()
			_lose_turn()

func _on_fight_pressed() -> void:
	if current_turn != "player":
		return
	current_action = "fight"
	if options_menu:
		options_menu.hide()
	_start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	if current_turn != "player":
		return
	current_action = "magic"
	if options_menu:
		options_menu.hide()
	_start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	if current_turn != "player":
		return
	current_action = "defend"
	player_defending = true
	defend_cooldown = 15.0
	_perform_action.rpc(my_peer_id, "defend", true)
	_switch_turn()

func _on_ultimate_pressed() -> void:
	if current_turn != "player":
		return
	current_action = "ultimate"
	if options_menu:
		options_menu.hide()
	_start_question(Enum.Difficulty.HARD)

func _start_question(difficulty: Enum.Difficulty) -> void:
	if not game_controller:
		return
	game_controller.load_question(difficulty)
	
	# Enable buttons and reset colors
	var html_question = game_controller.get_node_or_null("html_question")
	if html_question:
		for button in html_question.get_children():
			if button is Button:
				button.disabled = false
				button.modulate = Color.WHITE
	
	game_controller.show()

func _on_answer_button_pressed(button: Button) -> void:
	if current_turn != "player":
		return
	
	if not game_controller:
		return
	
	# Check if the answer is correct
	var current_question = game_controller.current_quiz
	if not current_question:
		return
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons
	var html_question = game_controller.get_node_or_null("html_question")
	if html_question:
		for btn in html_question.get_children():
			if btn is Button:
				btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = game_controller.color_right
	else:
		button.modulate = game_controller.color_wrong
	
	# Wait for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	if game_controller:
		game_controller.hide()
	
	# Handle result
	if is_correct:
		# Set cooldowns
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		# Perform action on all clients
		_perform_action.rpc(my_peer_id, current_action, player_defending)
		player_defending = false
	else:
		# Wrong answer - lose turn
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		_lose_turn()

func _switch_turn() -> void:
	if current_turn == "player":
		current_turn = "opponent"
		player_defending = false
		if options_menu:
			options_menu.hide()
		if battle_info:
			battle_info.text = "OPPONENT'S TURN"
		start_turn.rpc(opponent_peer_id)
	else:
		current_turn = "player"
		player_defending = false
		if options_menu:
			options_menu.show()
		if battle_info:
			battle_info.text = "YOUR TURN"
		start_turn.rpc(my_peer_id)

func _lose_turn() -> void:
	if options_menu:
		options_menu.hide()
	if game_controller:
		game_controller.hide()
	_switch_turn()

func _options_menu_button_focus(index: int) -> void:
	if options_menu and options_menu.get_child_count() > index:
		options_menu.get_child(index).grab_focus()

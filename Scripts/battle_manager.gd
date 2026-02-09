extends Control
class_name BattleManager

# UI References
@onready var player_healthbar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var opponent_healthbar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var turn_label: Label = $BattleLayout/Info
@onready var timer_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel
@onready var lose: Label = $BattleLayout/Lose
@onready var win: Label = $BattleLayout/Win
@onready var questions: Control = $BattleLayout/Control
@onready var question_info: Label = $BattleLayout/QuestionInfo
@onready var options_menu: Menu = $BattleLayout/Battle/Options/Options

# Action Buttons
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate

# Cooldown Labels
@onready var magic_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel

# Combat Stats
var player_health: int = 150
var opponent_health: int = 150
var current_turn_owner: int = 1  # 1 = server, 2+ = clients
var my_peer_id: int = 0
var is_my_turn: bool = false

# Cooldowns
var magic_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var turn_timer: float = 20.0
var turn_time_remaining: float = 20.0

# Defend Status
var player_defend_bars: int = 3
var opponent_defend_bars: int = 3

# Action Damages
const FIGHT_DAMAGE = 10
const MAGIC_DAMAGE = 15
const DEFEND_BARS = 3
const ULTIMATE_DAMAGE = 25

# Cooldown Times
const MAGIC_COOLDOWN_TIME = 20.0
const DEFEND_COOLDOWN_TIME = 15.0
const ULTIMATE_COOLDOWN_TIME = 60.0
const TURN_TIME = 20.0

func _ready() -> void:
	my_peer_id = multiplayer.get_unique_id()
	
	lose.visible = false
	win.visible = false
	questions.hide()
	
	# Initialize UI
	player_healthbar.init_health(150)
	opponent_healthbar.init_health(150)
	
	# Connect buttons
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	
	# Connect question answer buttons
	if questions and questions.html_question:
		for button in questions.html_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Start the game - server decides who goes first
	if multiplayer.is_server():
		var starting_peer_id = 1 if randf() > 0.5 else multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else 1
		sync_turn.rpc(starting_peer_id)
	
	update_turn_display()

func _process(delta: float) -> void:
	# Update cooldowns
	if magic_cooldown > 0:
		magic_cooldown -= delta
		magic_cooldown_label.text = "Magic: %.1f" % magic_cooldown
		magic_cooldown_label.show()
		if magic_cooldown <= 0:
			magic_cooldown = 0
			magic_cooldown_label.hide()
	else:
		magic_cooldown_label.hide()
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		ultimate_cooldown_label.text = "Ult: %.1f" % ultimate_cooldown
		ultimate_cooldown_label.show()
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			ultimate_cooldown_label.hide()
	else:
		ultimate_cooldown_label.hide()
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		defend_cooldown_label.text = "Defend: %.1f" % defend_cooldown
		defend_cooldown_label.show()
		if defend_cooldown <= 0:
			defend_cooldown = 0
			defend_cooldown_label.hide()
	else:
		defend_cooldown_label.hide()
	
	# Update turn timer
	if is_my_turn:
		turn_timer -= delta
		timer_label.text = "Time: %.0fs" % max(0, turn_timer)
		timer_label.show()
		if turn_timer <= 0:
			turn_timer = 0
			timer_label.hide()
			if question_info:
				question_info.text = "TIME RAN OUT"
				question_info.show()
				await get_tree().create_timer(2.0).timeout
				question_info.hide()
			lose_turn()
	else:
		timer_label.hide()

func _on_fight_pressed() -> void:
	if not is_my_turn:
		return
	execute_action.rpc_id(1, my_peer_id, "fight")
	options_menu.hide()
	start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	if not is_my_turn or magic_cooldown > 0:
		return
	execute_action.rpc_id(1, my_peer_id, "magic")
	options_menu.hide()
	start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	if not is_my_turn or defend_cooldown > 0:
		return
	player_defend_bars = DEFEND_BARS
	defend_cooldown = DEFEND_COOLDOWN_TIME
	execute_action.rpc_id(1, my_peer_id, "defend")
	switch_turn()

func _on_ultimate_pressed() -> void:
	if not is_my_turn or ultimate_cooldown > 0:
		return
	execute_action.rpc_id(1, my_peer_id, "ultimate")
	options_menu.hide()
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	"""Load and show a question"""
	questions.load_question(difficulty)
	
	# Enable buttons and reset colors
	if questions and questions.html_question:
		for button in questions.html_question.get_children():
			if button is Button:
				button.disabled = false
				button.modulate = Color.WHITE
	
	questions.show()

func _on_answer_button_pressed(button: Button) -> void:
	"""Handle player's answer"""
	if not is_my_turn or not questions or not questions.current_quiz:
		return
	
	var current_question = questions.current_quiz
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons
	if questions.html_question:
		for btn in questions.html_question.get_children():
			if btn is Button:
				btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = questions.color_right
	else:
		button.modulate = questions.color_wrong
	
	await get_tree().create_timer(1.0).timeout
	
	questions.hide()
	
	# Send answer result to server
	answer_submitted.rpc_id(1, my_peer_id, is_correct)

@rpc("authority", "call_local", "reliable")
func answer_submitted(peer_id: int, is_correct: bool) -> void:
	"""Process answer and apply damage"""
	# Only server processes this
	if not multiplayer.is_server():
		return
	
	var action = get_player_action(peer_id)
	if action == "":
		return
	
	var damage = 0
	if is_correct:
		match action:
			"fight":
				damage = FIGHT_DAMAGE
			"magic":
				magic_cooldown = MAGIC_COOLDOWN_TIME
				damage = MAGIC_DAMAGE
			"ultimate":
				ultimate_cooldown = ULTIMATE_COOLDOWN_TIME
				damage = ULTIMATE_DAMAGE
	
	# Apply defend damage reduction
	if opponent_defend_bars > 0:
		damage = 0
		opponent_defend_bars -= 1
	
	opponent_health -= damage
	sync_health.rpc(player_health, opponent_health)
	
	if not check_victory():
		switch_turn()

@rpc("authority", "call_local", "reliable")
func execute_action(peer_id: int, action: String) -> void:
	"""Execute player action on server"""
	# Only called on server
	if not multiplayer.is_server():
		return

func switch_turn() -> void:
	"""Switch to opponent's turn"""
	var peers = multiplayer.get_peers()
	var next_peer = peers[0] if peers.size() > 0 else 1
	
	if multiplayer.is_server():
		sync_turn.rpc(next_peer)
	
	# Reset defend
	player_defend_bars = 0
	opponent_defend_bars = 0

func lose_turn() -> void:
	"""Player loses turn without action"""
	switch_turn()

@rpc("authority", "call_local", "reliable")
func sync_turn(peer_id: int) -> void:
	"""Sync whose turn it is"""
	current_turn_owner = peer_id
	is_my_turn = (peer_id == my_peer_id)
	turn_timer = TURN_TIME
	
	update_turn_display()
	update_buttons()

@rpc("authority", "call_local", "reliable")
func sync_health(p_health: int, o_health: int) -> void:
	"""Sync health across all players"""
	player_health = p_health
	opponent_health = o_health
	update_health_display()

func update_health_display() -> void:
	"""Update health bars"""
	if player_healthbar:
		player_healthbar.health = player_health
	if opponent_healthbar:
		opponent_healthbar.health = opponent_health

func update_turn_display() -> void:
	"""Update who's turn it is"""
	if is_my_turn:
		turn_label.text = "YOUR TURN"
		options_menu.show()
	else:
		turn_label.text = "OPPONENT'S TURN"
		options_menu.hide()

func update_buttons() -> void:
	"""Enable/disable action buttons"""
	fight_button.disabled = not is_my_turn
	magic_button.disabled = not is_my_turn or magic_cooldown > 0
	defend_button.disabled = not is_my_turn or defend_cooldown > 0
	ultimate_button.disabled = not is_my_turn or ultimate_cooldown > 0

func check_victory() -> bool:
	"""Check if anyone has won"""
	if opponent_health <= 0:
		show_victory()
		return true
	if player_health <= 0:
		show_defeat()
		return true
	return false

func show_victory() -> void:
	"""Show victory"""
	win.visible = true
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

func show_defeat() -> void:
	"""Show defeat"""
	lose.visible = true
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

func get_player_action(peer_id: int) -> String:
	"""Get the last action from a player - implement based on your needs"""
	# This would need to be called from where the action was initiated
	return ""




extends Node
class_name BattleManager

# UI References
@onready var player_health_label = get_node_or_null("PlayerHealthLabel")
@onready var opponent_health_label = get_node_or_null("OpponentHealthLabel")
@onready var player_healthbar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var opponent_healthbar = get_node_or_null("OpponentHealthBar")
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
var current_turn: String = "player"  # "player" or "opponent"
var current_action: String = ""
var is_server: bool = false

# Cooldowns
var magic_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var turn_timer: float = 20.0
var turn_time_remaining: float = 20.0
var player_timeout_triggered: bool = false

# Defend Status (3 bars)
var player_defend_bars: int = 3
var opponent_defend_bars: int = 3
var player_defending = false

# Action Damages
const FIGHT_DAMAGE = 10
const MAGIC_DAMAGE = 15
const DEFEND_BARS = 3
const ULTIMATE_DAMAGE = 25

# Cooldown Times
const MAGIC_COOLDOWN_TIME = 20.0
const DEFEND_COOLDOWN_TIME = 15.0
const ULTIMATE_COOLDOWN_TIME = 60.0

func _ready() -> void:
	# Get network info
	if has_meta("IsServer"):
		is_server = get_meta("IsServer")
	
	lose.visible = false
	win.visible = false
	questions.hide()
	
	# Initialize UI
	update_health_display()
	
	# Connect buttons
	if fight_button:
		fight_button.pressed.connect(_on_fight_pressed)
	if magic_button:
		magic_button.pressed.connect(_on_magic_pressed)
	if defend_button:
		defend_button.pressed.connect(_on_defend_pressed)
	if ultimate_button:
		ultimate_button.pressed.connect(_on_ultimate_pressed)
	
	if questions and questions.html_question:
		for button in questions.html_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Start the game
	if is_server:
		# Server decides who goes first
		var starting_player = "player" if randf() > 0.5 else "opponent"
		sync_game_state.rpc(starting_player)
	
	update_turn_display()

func _process(delta: float) -> void:
	if magic_cooldown > 0:
		magic_cooldown -= delta
		magic_cooldown_label.text = "Magic: %.1f" % magic_cooldown
		magic_cooldown_label.show()
		if magic_cooldown <= 0:
			magic_cooldown = 0
			magic_cooldown_label.hide()
			if current_turn == "player" and options_menu.visible:
				magic_button.disabled = false
	else:
		magic_cooldown_label.hide()
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		ultimate_cooldown_label.text = "Ult: %.1f" % ultimate_cooldown
		ultimate_cooldown_label.show()
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			ultimate_cooldown_label.hide()
			if current_turn == "player" and options_menu.visible:
				ultimate_button.disabled = false
	else:
		ultimate_cooldown_label.hide()
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		defend_cooldown_label.text = "Defend: %.1f" % defend_cooldown
		defend_cooldown_label.show()
		if defend_cooldown <= 0:
			defend_cooldown = 0
			defend_cooldown_label.hide()
			if current_turn == "player" and options_menu.visible:
				defend_button.disabled = false
	else:
		defend_cooldown_label.hide()
	
	if turn_timer > 0 and current_turn == "player":
		turn_timer -= delta
		if turn_timer:
			timer_label.text = "Time: %.0fs" % max(0, turn_timer)
			timer_label.show()
		if turn_timer <= 0 and not player_timeout_triggered:
			turn_timer = 0
			player_timeout_triggered = true
			if turn_timer:
				timer_label.hide()
			# Show timeout message
			if question_info:
				question_info.text = "TIME RAN OUT"
				question_info.show()
				# Wait 2 seconds then lose turn
				await get_tree().create_timer(2.0).timeout
				question_info.hide()
				lose_turn()
	elif current_turn == "enemy":
		if turn_timer:
			timer_label.hide()

func _on_options_button_pressed(button: BaseButton) -> void:
	match button.text:
		"Fight":
			pass

func _on_fight_pressed() -> void:
	current_action = "fight"
	start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	current_action = "magic"
	start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	current_action = "defend"
	player_defending = true
	defend_cooldown = 15.0
	switch_turn()

func _on_ultimate_pressed() -> void:
	current_action = "ultimate"
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	options_menu.hide()
	questions.load_question(difficulty)
	
	# Enable buttons and reset colors
	for button in questions.html_question.get_children():
		if button is Button:
			button.disabled = false
			button.modulate = Color.WHITE
			
	questions.show()


@rpc("any_peer", "call_local", "reliable")
func perform_action():
	var damage = 0
	match current_action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	# Apply damage considering opponent's defend status
	if opponent_defend_bars > 0:
		# Defend reduces damage by 100%
		damage = 0
		opponent_defend_bars -= 1
	
	opponent_health -= damage
	update_health_display()
	check_victory()

func _on_answer_button_pressed(button: Button) -> void:
	# Check if the answer is correct
	var current_question = questions.current_quiz
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons to prevent multiple clicks
	for btn in questions.html_question.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = questions.color_right
	else:
		button.modulate = questions.color_wrong
	
	# Wait a moment for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	questions.hide()
	
	# Handle result
	if is_correct:
		# Set cooldown for magic and ultimate actions
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		if not perform_action():
			switch_turn()
	else:
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		lose_turn()

func switch_turn() -> void:
	"""Switch turn to opponent"""
	if current_turn == "player":
		defend_button.disabled = (defend_cooldown > 0)
		current_turn = "enemy"
		if turn_label:
			turn_label.text = "ENEMY'S TURN"
		if turn_label:
			turn_label.hide()
	else:
		current_turn = "player"
		player_defending = false
		options_menu.show()
		if turn_label:
			turn_label.text = "PLAYER'S TURN"
	
	if is_server:
		sync_game_state.rpc("opponent")
	else:
		sync_game_state.rpc_id(1, "opponent")  # Send to server
	
	# Opponent's turn (will be handled by opponent's instance)
	update_turn_display()

func lose_turn() -> void:
	"""Player loses their turn without taking action"""
	switch_turn()

@rpc("any_peer", "call_local", "reliable")
func sync_game_state(new_turn: String) -> void:
	"""Synchronize game state across all players"""
	current_turn = new_turn
	turn_time_remaining = turn_timer
	update_turn_display()

func update_health_display() -> void:
	"""Update health labels and bars"""
	if player_health_label:
		player_health_label.text = "Player: %d/150" % player_health
	if opponent_health_label:
		opponent_health_label.text = "Opponent: %d/150" % opponent_health
	
	if player_healthbar:
		player_healthbar.value = player_health
		player_healthbar.max_value = 150
	if opponent_healthbar:
		opponent_healthbar.value = opponent_health
		opponent_healthbar.max_value = 150

func update_turn_display() -> void:
	"""Update UI to show whose turn it is"""
	if turn_label:
		if current_turn == "player":
			turn_label.text = "YOUR TURN"
		else:
			turn_label.text = "OPPONENT'S TURN"
			switch_turn()

func update_timer_display() -> void:
	"""Update timer display"""
	if timer_label:
		timer_label.text = "%.1f" % max(0, turn_time_remaining)

func check_victory() -> bool:
	"""Check if either player has won"""
	if opponent_health <= 0:
		show_victory()
		return true
	if player_health <= 0:
		show_defeat()
		return true
	return false

func show_victory() -> void:
	"""Show victory screen"""
	print("You Win!")
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

func show_defeat() -> void:
	"""Show defeat screen"""
	print("You Lose!")
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

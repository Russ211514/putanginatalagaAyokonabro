extends Control

@onready var _options: WindowDefault = $BattleLayout/Battle/Options
@onready var _options_menu: Menu = $BattleLayout/Battle/Options/Options
@onready var _enemy: Menu = $BattleLayout/Battle/Enemies
@onready var player_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var enemy_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var python_game_controller = $BattleLayout/Control
@onready var lose: Label = $BattleLayout/Lose
@onready var win: Label = $BattleLayout/Win
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel
@onready var player_turn_timer_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel
@onready var info: Label = $BattleLayout/Info
@onready var question_info: Label = $BattleLayout/QuestionInfo

@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend

var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var player_turn_time: float = 0.0
var player_turn_max_time: float = 35.0
var player_timeout_triggered: bool = false

var current_turn = "player"
var player_defending = false
var opponent_defending = false
var current_action = ""
var is_server = false

# Network variables
var waiting_for_opponent = false
var opponent_action = ""
var opponent_correct = false

func _ready() -> void:
	# Get network info from game_menu
	if has_meta("IsServer"):
		is_server = get_meta("IsServer")
	
	if question_info:
		question_info.hide()
	if info:
		info.show()
	if player_turn_timer_label:
		player_turn_timer_label.hide()
	lose.visible = false
	win.visible = false
	python_game_controller.visible = false
	
	_options_menu.button_focus(0)
	player_health_bar.init_health(150)
	enemy_health_bar.init_health(150)
	
	# Connect action buttons to display questions
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	# Connect answer buttons
	if python_game_controller and python_game_controller.python_question:
		for button in python_game_controller.python_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Randomize starting turn - server decides
	if is_server:
		var starting_turn = "player" if randf() > 0.5 else "opponent"
		sync_turn.rpc(starting_turn)
	
	# Server starts as player, client starts as opponent
	if is_server:
		current_turn = "player"
		if info:
			info.text = "YOUR TURN"
		player_turn_max_time = 35.0
		player_turn_time = player_turn_max_time
		if player_turn_timer_label:
			player_turn_timer_label.show()
	else:
		current_turn = "opponent"
		if info:
			info.text = "OPPONENT'S TURN"
		_options_menu.hide()

func _process(delta: float) -> void:
	if magic_cooldown > 0:
		magic_cooldown -= delta
		magic_cooldown_label.text = "Magic: %.1f" % magic_cooldown
		magic_cooldown_label.show()
		if magic_cooldown <= 0:
			magic_cooldown = 0
			magic_cooldown_label.hide()
			if current_turn == "player" and _options_menu.visible:
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
			if current_turn == "player" and _options_menu.visible:
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
			if current_turn == "player" and _options_menu.visible:
				defend_button.disabled = false
	else:
		defend_cooldown_label.hide()
	
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
			# Show timeout message
			if question_info:
				question_info.text = "TIME RAN OUT"
				question_info.show()
				# Wait 2 seconds then lose turn
				await get_tree().create_timer(2.0).timeout
				question_info.hide()
				lose_turn()
	elif current_turn == "enemy":
		if player_turn_timer_label:
			player_turn_timer_label.hide()

func _on_options_button_pressed(button: BaseButton) -> void:
	match button.text:
		"Fight":
			_enemy.button_focus()

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
	# Send defend action to opponent
	opponent_action_received.rpc("defend", true)
	switch_turn()

func _on_ultimate_pressed() -> void:
	current_action = "ultimate"
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	_options_menu.hide()
	python_game_controller.load_question(difficulty)
	
	# Enable buttons and reset colors
	for button in python_game_controller.python_question.get_children():
		if button is Button:
			button.disabled = false
			button.modulate = Color.WHITE
			
	python_game_controller.show()

func _on_answer_button_pressed(button: Button) -> void:
	# Check if the answer is correct
	var current_question = python_game_controller.current_quiz
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons to prevent multiple clicks
	for btn in python_game_controller.python_question.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = python_game_controller.color_right
	else:
		button.modulate = python_game_controller.color_wrong
	
	# Wait a moment for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	python_game_controller.hide()
	
	# Handle result and send to opponent
	if is_correct:
		# Set cooldown for magic and ultimate actions
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		# Send correct answer to opponent
		opponent_action_received.rpc(current_action, true)
		if not perform_action():
			switch_turn()
	else:
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		# Send wrong answer to opponent
		opponent_action_received.rpc(current_action, false)
		lose_turn()

func perform_action() -> bool:
	var damage = 0
	match current_action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	
	# Apply defender's reduction
	if opponent_defending:
		damage *= 0.75
	
	enemy_health_bar.health -= damage
	return check_victory()

func perform_opponent_action() -> bool:
	"""Perform opponent's action"""
	var damage = 0
	match opponent_action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	
	# Apply defender's reduction
	if player_defending:
		damage *= 0.75
	
	player_health_bar.health -= damage
	return check_victory()

@rpc("any_peer", "call_local", "reliable")
func opponent_action_received(action: String, is_correct: bool) -> void:
	"""Receive opponent's action and update game state"""
	opponent_action = action
	opponent_correct = is_correct
	opponent_defending = (action == "defend" and is_correct)
	
	if is_correct:
		if not perform_opponent_action():
			switch_turn()
	else:
		switch_turn()

func check_victory() -> bool:
	if player_health_bar.health <= 0:
		lose.visible = true
		# Handle lose
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().change_scene_to_file("res://Scenes/offline selection.tscn"))
		return true
	elif enemy_health_bar.health <= 0:
		win.visible = true
		# Handle win
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().change_scene_to_file("res://Scenes/offline selection.tscn"))
		return true
	return false

func switch_turn() -> void:
	"""Switch turn between players"""
	if current_turn == "player":
		current_turn = "opponent"
		defend_button.disabled = (defend_cooldown > 0)
		sync_turn.rpc("opponent")
	else:
		current_turn = "player"
		player_defending = false
		sync_turn.rpc("player")

@rpc("any_peer", "call_local", "reliable")
func sync_turn(turn: String) -> void:
	"""Synchronize whose turn it is across all players"""
	current_turn = turn
	
	if current_turn == "player":
		if info:
			info.text = "YOUR TURN"
		_options_menu.show()
		player_defending = false
		
		# Reset cooldowns display
		magic_button.disabled = (magic_cooldown > 0)
		ultimate_button.disabled = (ultimate_cooldown > 0)
		
		# Start player turn timer
		player_timeout_triggered = false
		player_turn_max_time = 35.0
		player_turn_time = player_turn_max_time
		if player_turn_timer_label:
			player_turn_timer_label.show()
		
		_options_menu.button_focus(0)
	else:
		if info:
			info.text = "OPPONENT'S TURN"
		_options_menu.hide()
		if player_turn_timer_label:
			player_turn_timer_label.hide()

func lose_turn() -> void:
	"""Player loses their turn without taking action"""
	_options_menu.hide()
	python_game_controller.hide()
	# Switch to opponent's turn
	switch_turn()

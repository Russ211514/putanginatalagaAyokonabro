extends Control

@onready var _options: WindowDefault = $BattleLayout/Battle/Options
@onready var _options_menu: Menu = $BattleLayout/Battle/Options/Options
@onready var _enemy: Menu = $BattleLayout/Battle/Enemies
@onready var player_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var enemy_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var html_game_controller = $BattleLayout/Control
@onready var lose: Label = $BattleLayout/Lose
@onready var win: Label = $BattleLayout/Win
@onready var defend_cooldown_label: = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel
@onready var info: Label = $BattleLayout/Info

@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend

var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0

var current_turn = "player"
var player_defending = false
var current_action = ""
var bot_difficulty: int = 1  # 0 = easy, 1 = normal, 2 = hard

func _ready() -> void:
	# Capture bot difficulty from parent scene
	if has_meta("BotDifficulty"):
		bot_difficulty = get_meta("BotDifficulty")
	
	lose.visible = false
	win.visible = false
	html_game_controller.visible = false
	
	_options_menu.button_focus(0)
	player_health_bar.init_health(150)
	enemy_health_bar.init_health(150)
	
	# Connect action buttons to display questions
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	# Connect answer buttons
	if html_game_controller and html_game_controller.html_question:
		for button in html_game_controller.html_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))

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
	switch_turn()

func _on_ultimate_pressed() -> void:
	current_action = "ultimate"
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	_options_menu.hide()
	html_game_controller.load_question(difficulty)
	
	# Enable buttons and reset colors
	for button in html_game_controller.html_question.get_children():
		if button is Button:
			button.disabled = false
			button.modulate = Color.WHITE
			
	html_game_controller.show()

func _on_answer_button_pressed(button: Button) -> void:
	# Check if the answer is correct
	var current_question = html_game_controller.current_quiz
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons to prevent multiple clicks
	for btn in html_game_controller.html_question.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = html_game_controller.color_right
	else:
		button.modulate = html_game_controller.color_wrong
	
	# Wait a moment for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	html_game_controller.hide()
	
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

func perform_action() -> bool:
	var damage = 0
	match current_action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	if current_turn == "player":
		enemy_health_bar.health -= damage
	else:
		player_health_bar.health -= damage
	return check_victory()

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
	if current_turn == "player":
		defend_button.disabled = (defend_cooldown > 0)
		current_turn = "enemy"
		info.text = "ENEMY'S TURN"
		enemy_turn()
	else:
		current_turn = "player"
		player_defending = false
		_options_menu.show()
		info.text = "PLAYER'S TURN"
		
		magic_button.disabled = (magic_cooldown > 0)
		ultimate_button.disabled = (ultimate_cooldown > 0)
		
		_options_menu.button_focus(0)

func enemy_turn() -> void:
	if not is_inside_tree(): return
	# Wait 2 seconds before attacking
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree(): return
	
	# Enemy chooses an action based on difficulty
	var enemy_action = "fight"
	if randf() > 0.5:
		enemy_action = "magic"
	
	# Enemy answers question with accuracy based on difficulty
	var is_correct = _enemy_answer_correct(bot_difficulty, enemy_action)
	
	# Display result in info label
	if is_correct:
		info.text = "ENEMY GOT IT RIGHT"
	else:
		info.text = "ENEMY GOT IT WRONG"
	
	var damage = 0
	if is_correct:
		match enemy_action:
			"fight":
				damage = 10
			"magic":
				damage = 15
	else:
		# Enemy gets question wrong, minimal/no damage
		damage = 0
	
	if player_defending:
		damage *= 0.75
	
	player_health_bar.health -= damage
	if not check_victory():
		switch_turn()

func _enemy_answer_correct(difficulty: int, action: String) -> bool:
	# Based on difficulty, determine if enemy answers correctly
	# 0 = easy (often wrong), 1 = normal (occasionally wrong), 2 = hard (never wrong)
	match difficulty:
		0:  # Easy - enemy gets it wrong 70% of the time
			return randf() > 0.6
		1:  # Normal - enemy gets it wrong 40% of the time
			return randf() > 0.4
		2:  # Hard - enemy never gets it wrong
			return true
		_:  # Default to normal
			return randf() > 0.4

func lose_turn() -> void:
	# Player loses their turn without taking action
	_options_menu.hide()
	html_game_controller.hide()
	# Enemy still gets their turn
	switch_turn()

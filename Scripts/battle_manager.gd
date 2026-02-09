extends Node
class_name BattleManager

# UI References
@onready var player_health_label = get_node_or_null("PlayerHealthLabel")
@onready var opponent_health_label = get_node_or_null("OpponentHealthLabel")
@onready var player_healthbar = get_node_or_null("PlayerHealthBar")
@onready var opponent_healthbar = get_node_or_null("OpponentHealthBar")
@onready var turn_label = get_node_or_null("TurnLabel")
@onready var timer_label = get_node_or_null("TimerLabel")

# Action Buttons
@onready var fight_button = get_node_or_null("Actions/FightButton")
@onready var magic_button = get_node_or_null("Actions/MagicButton")
@onready var defend_button = get_node_or_null("Actions/DefendButton")
@onready var ultimate_button = get_node_or_null("Actions/UltimateButton")

# Cooldown Labels
@onready var magic_cooldown_label = get_node_or_null("Cooldowns/MagicCooldown")
@onready var defend_cooldown_label = get_node_or_null("Cooldowns/DefendCooldown")
@onready var ultimate_cooldown_label = get_node_or_null("Cooldowns/UltimateCooldown")

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

# Defend Status (3 bars)
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

func _ready() -> void:
	# Get network info
	if has_meta("IsServer"):
		is_server = get_meta("IsServer")
	
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
	
	# Start the game
	if is_server:
		# Server decides who goes first
		var starting_player = "player" if randf() > 0.5 else "opponent"
		sync_game_state.rpc(starting_player)
	
	update_turn_display()

func _process(delta: float) -> void:
	# Update cooldowns
	if magic_cooldown > 0:
		magic_cooldown -= delta
		if magic_cooldown <= 0:
			magic_cooldown = 0
		update_cooldown_display()
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		if defend_cooldown <= 0:
			defend_cooldown = 0
		update_cooldown_display()
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
		update_cooldown_display()
	
	# Update turn timer
	if current_turn == "player":
		turn_time_remaining -= delta
		if turn_time_remaining <= 0:
			turn_time_remaining = 0
			# Time ran out, lose turn
			lose_turn()
		update_timer_display()

func _on_fight_pressed() -> void:
	if current_turn != "player":
		return
	current_action = "fight"
	execute_player_action.rpc("fight", true)
	if not check_victory():
		switch_turn()

func _on_magic_pressed() -> void:
	if current_turn != "player":
		return
	if magic_cooldown > 0:
		print("Magic is on cooldown")
		return
	current_action = "magic"
	magic_cooldown = MAGIC_COOLDOWN_TIME
	execute_player_action.rpc("magic", true)
	if not check_victory():
		switch_turn()

func _on_defend_pressed() -> void:
	if current_turn != "player":
		return
	if defend_cooldown > 0:
		print("Defend is on cooldown")
		return
	current_action = "defend"
	player_defend_bars = DEFEND_BARS
	defend_cooldown = DEFEND_COOLDOWN_TIME
	
	# Send action to opponent immediately (no question for defend)
	execute_player_action.rpc("defend", true)
	switch_turn()

func _on_ultimate_pressed() -> void:
	if current_turn != "player":
		return
	if ultimate_cooldown > 0:
		print("Ultimate is on cooldown")
		return
	current_action = "ultimate"
	ultimate_cooldown = ULTIMATE_COOLDOWN_TIME
	execute_player_action.rpc("ultimate", true)
	if not check_victory():
		switch_turn()

@rpc("any_peer", "call_local", "reliable")
func execute_player_action(action: String, is_correct: bool) -> void:
	"""Execute the player's action and apply damage"""
	var damage = 0
	
	match action:
		"fight":
			damage = FIGHT_DAMAGE
		"magic":
			damage = MAGIC_DAMAGE
		"ultimate":
			damage = ULTIMATE_DAMAGE
	
	# Apply damage considering opponent's defend status
	if opponent_defend_bars > 0:
		# Defend reduces damage by 100%
		damage = 0
		opponent_defend_bars -= 1
	
	opponent_health -= damage
	update_health_display()
	check_victory()

func switch_turn() -> void:
	"""Switch turn to opponent"""
	current_turn = "opponent"
	turn_time_remaining = turn_timer
	player_defend_bars = 0  # Reset defend status when turn changes
	
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
	update_buttons()

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
	
	update_buttons()

func update_timer_display() -> void:
	"""Update timer display"""
	if timer_label:
		timer_label.text = "%.1f" % max(0, turn_time_remaining)

func update_cooldown_display() -> void:
	"""Update cooldown displays"""
	if magic_cooldown_label:
		if magic_cooldown > 0:
			magic_cooldown_label.text = "Magic: %.1f" % magic_cooldown
			magic_cooldown_label.visible = true
		else:
			magic_cooldown_label.visible = false
	
	if defend_cooldown_label:
		if defend_cooldown > 0:
			defend_cooldown_label.text = "Defend: %.1f" % defend_cooldown
			defend_cooldown_label.visible = true
		else:
			defend_cooldown_label.visible = false
	
	if ultimate_cooldown_label:
		if ultimate_cooldown > 0:
			ultimate_cooldown_label.text = "Ultimate: %.1f" % ultimate_cooldown
			ultimate_cooldown_label.visible = true
		else:
			ultimate_cooldown_label.visible = false

func update_buttons() -> void:
	"""Enable/disable buttons based on game state"""
	var buttons_enabled = (current_turn == "player")
	
	if fight_button:
		fight_button.disabled = not buttons_enabled
	if magic_button:
		magic_button.disabled = not buttons_enabled or magic_cooldown > 0
	if defend_button:
		defend_button.disabled = not buttons_enabled or defend_cooldown > 0
	if ultimate_button:
		ultimate_button.disabled = not buttons_enabled or ultimate_cooldown > 0

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
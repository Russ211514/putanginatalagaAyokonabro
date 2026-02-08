extends CanvasLayer
class_name GamePvP

# Battle UI References
@onready var player1_health_bar = $Battle/Bottom/Player1/MarginContainer/VBoxContainer/HealthBar
@onready var player2_health_bar = $Battle/Bottom/Player2/MarginContainer/VBoxContainer/HealthBar
@onready var info: Label = $Battle/Info
@onready var action_info: Label = $ActionInfo
@onready var fight_button = $Battle/Options/OptionsVBox/Fight
@onready var magic_button = $Battle/Options/OptionsVBox/Magic
@onready var defend_button = $Battle/Options/OptionsVBox/Defend
@onready var ultimate_button = $Battle/Options/OptionsVBox/Ultimate
@onready var options_container = $Battle/Options

# Question UI References (for future integration)
var question_controller = null

# Battle State
var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var player_turn_time: float = 0.0
var player_turn_max_time: float = 35.0
var player_timeout_triggered: bool = false

var current_turn: int = 1  # Player 1 or Player 2
var player1_defending: bool = false
var player2_defending: bool = false
var current_action: String = ""
var my_player_number: int = 0  # 1 or 2

const MAX_HEALTH = 150.0
const TURN_TIME = 35.0

var my_peer_id: int = 0
var opponent_peer_id: int = 0

func _ready() -> void:
	visible = false
	player1_health_bar.init_health(MAX_HEALTH)
	player2_health_bar.init_health(MAX_HEALTH)
	
	# Connect action buttons
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)

func start_pvp_battle(my_id: int, opponent_id: int) -> void:
	"""Initialize PvP battle with player and opponent IDs"""
	visible = true
	my_peer_id = my_id
	opponent_peer_id = opponent_id
	
	# Determine player number (lower ID is player 1)
	if my_id < opponent_id:
		my_player_number = 1
	else:
		my_player_number = 2
	
	# Reset battle state
	player1_health_bar.init_health(MAX_HEALTH)
	player2_health_bar.init_health(MAX_HEALTH)
	player1_defending = false
	player2_defending = false
	magic_cooldown = 0.0
	ultimate_cooldown = 0.0
	defend_cooldown = 0.0
	
	# Randomize starting turn
	current_turn = randi() % 2 + 1
	player_timeout_triggered = false
	player_turn_time = TURN_TIME
	
	update_turn_display()
	_start_turn()

func _process(delta: float) -> void:
	if not visible:
		return
	
	# Update cooldowns
	if magic_cooldown > 0:
		magic_cooldown -= delta
		if magic_cooldown <= 0:
			magic_cooldown = 0
			if current_turn == my_player_number and options_container.visible:
				magic_button.disabled = false
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			if current_turn == my_player_number and options_container.visible:
				ultimate_button.disabled = false
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		if defend_cooldown <= 0:
			defend_cooldown = 0
			if current_turn == my_player_number and options_container.visible:
				defend_button.disabled = false
	
	# Player turn timer
	if player_turn_time > 0 and current_turn == my_player_number:
		player_turn_time -= delta
		if player_turn_time <= 0 and not player_timeout_triggered:
			player_turn_time = 0
			player_timeout_triggered = true
			action_info.text = "TIME RAN OUT"
			_lose_turn()

func _on_fight_pressed() -> void:
	"""Handle fight action"""
	if current_turn != my_player_number:
		return
	current_action = "fight"
	execute_action.rpc("fight", my_player_number)

func _on_magic_pressed() -> void:
	"""Handle magic action"""
	if current_turn != my_player_number:
		return
	current_action = "magic"
	magic_cooldown = 20.0
	magic_button.disabled = true
	execute_action.rpc("magic", my_player_number)

func _on_defend_pressed() -> void:
	"""Handle defend action"""
	if current_turn != my_player_number:
		return
	current_action = "defend"
	defend_cooldown = 15.0
	defend_button.disabled = true
	
	if my_player_number == 1:
		player1_defending = true
	else:
		player2_defending = true
	
	action_info.text = "DEFENDING!"
	options_container.hide()
	await get_tree().create_timer(1.5).timeout
	switch_turn.rpc()

func _on_ultimate_pressed() -> void:
	"""Handle ultimate action"""
	if current_turn != my_player_number:
		return
	current_action = "ultimate"
	ultimate_cooldown = 40.0
	ultimate_button.disabled = true
	execute_action.rpc("ultimate", my_player_number)

@rpc("any_peer", "call_local")
func execute_action(action: String, attacker: int) -> void:
	"""Execute action and apply damage"""
	var damage = 0
	match action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	
	# Apply damage
	if attacker == 1:
		var final_damage = damage
		if player2_defending:
			final_damage = int(damage * 0.75)
			action_info.text = "PLAYER 1 HIT FOR %d DAMAGE (DEFENDED)" % final_damage
		else:
			action_info.text = "PLAYER 1 HIT FOR %d DAMAGE" % final_damage
		player2_health_bar.health -= final_damage
	else:
		var final_damage = damage
		if player1_defending:
			final_damage = int(damage * 0.75)
			action_info.text = "PLAYER 2 HIT FOR %d DAMAGE (DEFENDED)" % final_damage
		else:
			action_info.text = "PLAYER 2 HIT FOR %d DAMAGE" % final_damage
		player1_health_bar.health -= final_damage
	
	options_container.hide()
	await get_tree().create_timer(2.0).timeout
	action_info.text = ""
	
	# Check for victory
	if await check_victory():
		return
	
	switch_turn.rpc()

@rpc("any_peer", "call_local")
func check_victory() -> bool:
	"""Check if someone won"""
	if player1_health_bar.health <= 0:
		action_info.text = "PLAYER 2 WINS!"
		await get_tree().create_timer(3.0).timeout
		end_battle(2)
		return true
	elif player2_health_bar.health <= 0:
		action_info.text = "PLAYER 1 WINS!"
		await get_tree().create_timer(3.0).timeout
		end_battle(1)
		return true
	return false

@rpc("any_peer", "call_local")
func switch_turn() -> void:
	"""Switch to next player's turn"""
	if current_turn == 1:
		player1_defending = false
		current_turn = 2
	else:
		player2_defending = false
		current_turn = 1
	
	player_timeout_triggered = false
	player_turn_time = TURN_TIME
	update_turn_display()
	_start_turn()

func _start_turn() -> void:
	"""Start a player's turn"""
	if current_turn == my_player_number:
		options_container.show()
		magic_button.disabled = (magic_cooldown > 0)
		ultimate_button.disabled = (ultimate_cooldown > 0)
		defend_button.disabled = (defend_cooldown > 0)
	else:
		options_container.hide()
	
	action_info.text = ""

func update_turn_display() -> void:
	"""Update turn indicator"""
	if current_turn == 1:
		info.text = "PLAYER 1'S TURN"
	else:
		info.text = "PLAYER 2'S TURN"

@rpc("any_peer", "call_local")
func _lose_turn() -> void:
	"""Lose current turn without taking action"""
	options_container.hide()
	action_info.text = ""
	switch_turn.rpc()

func end_battle(winner: int) -> void:
	"""End the battle"""
	visible = false
	player1_defending = false
	player2_defending = false
	print("Battle ended. Player " + str(winner) + " wins!")

func get_player1_health() -> float:
	return player1_health_bar.health

func get_player2_health() -> float:
	return player2_health_bar.health

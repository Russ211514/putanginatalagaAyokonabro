extends CanvasLayer
class_name BattlePvP

@onready var player1_health_bar = $Battle/Bottom/Player1/MarginContainer/VBoxContainer/HealthBar
@onready var player2_health_bar = $Battle/Bottom/Player2/MarginContainer/VBoxContainer/HealthBar
@onready var info: Label = $Battle/Info
@onready var action_info: Label = $ActionInfo
@onready var fight_button = $Battle/Options/OptionsVBox/Fight
@onready var magic_button = $Battle/Options/OptionsVBox/Magic
@onready var defend_button = $Battle/Options/OptionsVBox/Defend
@onready var ultimate_button = $Battle/Options/OptionsVBox/Ultimate
@onready var options_container = $Battle/Options

var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0

var current_turn: int = 1  # Player 1 or Player 2
var player1_defending: bool = false
var player2_defending: bool = false
var current_action: String = ""

const MAX_HEALTH = 150.0
const TURN_TIME = 30.0
var turn_time: float = TURN_TIME

func _ready() -> void:
	visible = false
	player1_health_bar.init_health(MAX_HEALTH)
	player2_health_bar.init_health(MAX_HEALTH)
	
	# Connect action buttons
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	
	# Randomize starting turn
	if randf() > 0.5:
		current_turn = 1
	else:
		current_turn = 2

func start_battle() -> void:
	visible = true
	player1_health_bar.init_health(MAX_HEALTH)
	player2_health_bar.init_health(MAX_HEALTH)
	player1_defending = false
	player2_defending = false
	current_turn = 1 if randf() > 0.5 else 2
	turn_time = TURN_TIME
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
			if current_turn == multiplayer.get_unique_id():
				magic_button.disabled = false
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			if current_turn == multiplayer.get_unique_id():
				ultimate_button.disabled = false
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		if defend_cooldown <= 0:
			defend_cooldown = 0
			if current_turn == multiplayer.get_unique_id():
				defend_button.disabled = false

func _on_fight_pressed() -> void:
	current_action = "fight"
	execute_action("fight")

func _on_magic_pressed() -> void:
	current_action = "magic"
	magic_cooldown = 15.0
	magic_button.disabled = true
	execute_action("magic")

func _on_defend_pressed() -> void:
	current_action = "defend"
	defend_cooldown = 15.0
	defend_button.disabled = true
	if current_turn == 1:
		player1_defending = true
	else:
		player2_defending = true
	action_info.text = "DEFENDING!"
	options_container.hide()
	await get_tree().create_timer(1.5).timeout
	switch_turn()

func _on_ultimate_pressed() -> void:
	current_action = "ultimate"
	ultimate_cooldown = 40.0
	ultimate_button.disabled = true
	execute_action("ultimate")

func execute_action(action: String) -> void:
	var damage = 0
	match action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	
	# Apply damage
	if current_turn == 1:
		var final_damage = damage
		if player2_defending:
			final_damage = int(damage * 0.75)
			action_info.text = "HIT FOR %d DAMAGE (DEFENDED)" % final_damage
		else:
			action_info.text = "HIT FOR %d DAMAGE" % final_damage
		player2_health_bar.health -= final_damage
	else:
		var final_damage = damage
		if player1_defending:
			final_damage = int(damage * 0.75)
			action_info.text = "HIT FOR %d DAMAGE (DEFENDED)" % final_damage
		else:
			action_info.text = "HIT FOR %d DAMAGE" % final_damage
		player1_health_bar.health -= final_damage
	
	options_container.hide()
	await get_tree().create_timer(2.0).timeout
	action_info.text = ""
	
	# Check for victory
	if check_victory():
		return
	
	switch_turn()

func check_victory() -> bool:
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

func switch_turn() -> void:
	if current_turn == 1:
		player1_defending = false
		current_turn = 2
	else:
		player2_defending = false
		current_turn = 1
	
	turn_time = TURN_TIME
	update_turn_display()
	_start_turn()

func _start_turn() -> void:
	options_container.show()
	action_info.text = ""

func update_turn_display() -> void:
	if current_turn == 1:
		info.text = "PLAYER 1'S TURN"
	else:
		info.text = "PLAYER 2'S TURN"

func end_battle(winner: int) -> void:
	visible = false
	player1_defending = false
	player2_defending = false

func get_player1_health() -> float:
	return player1_health_bar.health

func get_player2_health() -> float:
	return player2_health_bar.health

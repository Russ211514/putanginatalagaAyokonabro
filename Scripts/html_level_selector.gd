extends Control

@onready var level1: TextureButton = $CanvasLayer/HBoxContainer/level1
@onready var level2: TextureButton = $CanvasLayer/HBoxContainer/level2
@onready var level3: TextureButton = $CanvasLayer/HBoxContainer/level3

func _ready() -> void:
	update_level_buttons()
	
	# Connect level buttons
	if level1:
		level1.pressed.connect(_on_level_pressed.bind(1))
	if level2:
		level2.pressed.connect(_on_level_pressed.bind(2))
	if level3:
		level3.pressed.connect(_on_level_pressed.bind(3))

func update_level_buttons() -> void:
	# Level 1 is always available
	if level1:
		level1.disabled = false
	
	# Level 2 unlocks after completing the html quiz part 2
	if level2:
		level2.disabled = not LevelCore.lvl1_completed
	
	# Level 3 unlocks after level 2 is completed
	if level3:
		level3.disabled = not LevelCore.lvl2_completed

func _on_level_pressed(level_number: int) -> void:
	match level_number:
		1:
			get_tree().change_scene_to_file("res://Html Scenes/html tutorial start.tscn")
		2:
			get_tree().change_scene_to_file("res://Html Scenes/html tutorial start2.tscn")
		3:
			get_tree().change_scene_to_file("res://Html Scenes/html_battle.tscn")

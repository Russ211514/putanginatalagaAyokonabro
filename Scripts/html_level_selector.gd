extends Control

@onready var level1: TextureButton = $CanvasLayer/HBoxContainer/level1
@onready var level2: TextureButton = $CanvasLayer/HBoxContainer/level2
@onready var level3: TextureButton = $CanvasLayer/HBoxContainer/level3
@onready var level4: TextureButton = $CanvasLayer/HBoxContainer/level4

func _ready() -> void:
	update_level_buttons()
	
	# Connect level buttons
	if level1:
		level1.pressed.connect(_on_level_pressed.bind(1))
	if level2:
		level2.pressed.connect(_on_level_pressed.bind(2))
	if level3:
		level3.pressed.connect(_on_level_pressed.bind(3))
	if level4:
		level4.pressed.connect(_on_level_pressed.bind(4))

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
	
	# Level 4 (Final Quiz) unlocks after level 3 is completed
	if level4:
		level4.disabled = not LevelCore.lvl3_completed

func _on_level_pressed(level_number: int) -> void:
	match level_number:
		1:
			# Level 1 progression
			if LevelCore.lvl1_completed:
				# User has completed both mini quiz and part 2, go to start3
				get_tree().change_scene_to_file("res://Html Scenes/html tutorial start3.tscn")
			elif LevelCore.html_mini_quiz_completed:
				# User completed mini quiz, go to part 2
				get_tree().change_scene_to_file("res://Html Scenes/html tutorial start2.tscn")
			elif LevelCore.lvl1_completed:
				# Start from the beginning
				get_tree().change_scene_to_file("res://Html Scenes/final_level_html.tscn")
			else:
				get_tree().change_scene_to_file("res://Html Scenes/html tutorial start.tscn")
		2:
			get_tree().change_scene_to_file("res://Html Scenes/html_question.tscn")
		3:
			get_tree().change_scene_to_file("res://Html Scenes/html_battle.tscn")
		4:
			get_tree().change_scene_to_file("res://Html Scenes/final_level_html_quiz.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Language Selection.tscn")

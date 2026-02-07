extends Node

@export var quiz: QuizTheme
@export var color_right: Color
@export var color_wrong: Color

@onready var RestartButton = $Restart
@onready var question_texts: Label = $Question/QuestionText

var buttons: Array[Button]
var index: int
var correct_question: int

var currenct_quiz: QuizQuestion:
	get: return quiz.theme[index]

func _ready() -> void:
	correct_question = 0
	
	for button in $QuestionHolder.get_children():
		buttons.append(button)
	
	randomize_array(quiz.theme)
	load_quiz()

func load_quiz() -> void:
	if index >= quiz.theme.size():
		game_over()
		return
	
	question_texts.text = currenct_quiz.Question_Info
	
	var options = randomize_array(currenct_quiz.options)
	for i in buttons.size():
		buttons[i].text = options[i]
		buttons[i].pressed.connect(buttons_answer.bind(buttons[i]))
	
func buttons_answer(button) -> void:
	if currenct_quiz.correct == button.text:
		button.modulate = color_right
		correct_question += 1
	else:
		button.modulate = color_wrong
	
	next_question()

func next_question():
	for bt in buttons:
		bt.pressed.disconnect(buttons_answer)
	
	await get_tree().create_timer(1).timeout
	
	for bt in buttons:
		bt.modulate = Color.WHITE
		
	index += 1
	load_quiz()

func randomize_array(array: Array) -> Array:
	var array_temp = array
	array_temp.shuffle()
	return array_temp

func game_over() -> void:
	if correct_question != quiz.theme.size():
		$GameOver/Score.text = str("You got ", correct_question, "/", quiz.theme.size())
		$GameOver/Restart.show()
	else:
		$GameOver/Score.text = str("Congrats you got ", correct_question, "/", quiz.theme.size())
		$GameOver/Restart.hide()
	$GameOver.show()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/html tutorial start.tscn")

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

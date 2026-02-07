extends Resource
class_name BattleQuestion

@export var Question_Info: String
@export var type: Enum.QuestionType
@export var options: Array[String]
@export var correct: String
@export var difficulty: Enum.Difficulty

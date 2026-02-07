extends Control

@onready var explanation: Panel = $Explanation
@onready var question: Label = $Question
@onready var understand: Button = $Understand
@onready var next: Button = $Next
@onready var canvas_layer: CanvasLayer = $CanvasLayer

func _ready() -> void:
	canvas_layer.visible = false
	
	explanation.visible = false
	question.visible = true
	understand.visible = true
	next.visible = true

func _on_understand_pressed() -> void:
	explanation.visible = true
	question.visible = false
	understand.visible = false
	next.visible = false

func _on_x_button_pressed() -> void:
	_ready()

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html quiz part3.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_level_selector.tscn")


func _on_yes_pressed() -> void:
	canvas_layer.visible = true

func _on_no_pressed() -> void:
	pass # Replace with function body.

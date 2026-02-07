extends Control

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Selection Scene.tscn")

func _on_python_pressed() -> void:
	get_tree().change_scene_to_file("res://Python Scenes/python_difficulty_selection.tscn")

func _on_html_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/difficulty_selection.tscn")

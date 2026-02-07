extends Control

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Selection Scene.tscn")

func _on_python_pressed() -> void:
	get_tree().change_scene_to_file("res://Python Scenes/battle_scene.tscn")

func _on_html_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_battle.tscn")

extends Control

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_html_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Html tutorial.tscn")

func _on_java_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/java tutorial.tscn")

func _on_python_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/python tutorial.tscn")

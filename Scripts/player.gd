extends CharacterBody2D
class_name Player

func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))

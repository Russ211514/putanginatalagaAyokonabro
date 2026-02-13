extends Node
class_name Game

func _on_host_pressed() -> void:
	print("Become host pressed")
	%Multiplayer.hide()
	MultiplayerManager.become_host()

func _on_join_pressed() -> void:
	
	%Multiplayer.hide()

#func _on_copy_oid_pressed() -> void:
	#DisplayServer.clipboard_set(peer.online_id)

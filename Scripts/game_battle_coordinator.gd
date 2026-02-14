extends Control

# Coordinator script - determines which role this peer is (host or client) 
# and attaches the appropriate script

func _ready() -> void:
	var my_peer_id = multiplayer.get_unique_id()
	print("[GameBattle Coordinator] Scene loaded. My peer ID: ", my_peer_id)
	print("[GameBattle Coordinator] Am I server? ", multiplayer.is_server())
	
	# Remove this coordinator script and add the appropriate role script
	if multiplayer.is_server():
		print("[GameBattle Coordinator] I am SERVER - Loading HOST script")
		# Remove this script and add the host script
		set_script(load("res://Scripts/game_battle_host.gd"))
	else:
		print("[GameBattle Coordinator] I am CLIENT - Loading CLIENT script")
		# Remove this script and add the client script
		set_script(load("res://Scripts/game_battle_client.gd"))
	
	# The appropriate script's _ready() will now be called

extends Sprite2D

var backgrounds = [
	preload("res://Art Assets/backgrounds/bground.png"),
	preload("res://Art Assets/backgrounds/bg1.png"),
	preload("res://Art Assets/backgrounds/bg2.png"),
	preload("res://Art Assets/backgrounds/bg3.png"),
]

func _ready():
	# Wait for multiplayer battle to set the background
	pass

@rpc("any_peer", "call_local", "reliable")
func set_background(index: int) -> void:
	"""Set background by index - synced across all players"""
	if index >= 0 and index < backgrounds.size():
		self.texture = backgrounds[index]
		print("[BackgroundSprite] Set background to index: ", index)

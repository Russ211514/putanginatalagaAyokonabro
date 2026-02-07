extends Sprite2D

var backgrounds = [
	preload("res://Art Assets/backgrounds/bground.png"),
	preload("res://Art Assets/backgrounds/bg1.png"),
	preload("res://Art Assets/backgrounds/bg2.png"),
	preload("res://Art Assets/backgrounds/bg3.png"),
]

func _ready():
	# Generate random index
	var random_index = randi() % backgrounds.size()
	# Set the texture
	self.texture = backgrounds[random_index]

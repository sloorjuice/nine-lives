extends Label

@onready var player: CharacterBody2D

func _ready():
	# Find the player in the scene
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Connect to the player's lives_changed signal
		player.lives_changed.connect(_on_player_lives_changed)
		# Set initial text from GameManager
		var game_manager = get_node("/root/GameManager")
		_on_player_lives_changed(game_manager.get_lives())
	else:
		text = "Lives: ?"
		print("Warning: Player not found for lives UI")

func _on_player_lives_changed(new_lives: int):
	text = str(new_lives)

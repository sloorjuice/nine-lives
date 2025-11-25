extends Label

@onready var player: CharacterBody2D

func _ready():
	print("[LivesCounter] Finding player...")
	# Find the player in the scene
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("[LivesCounter] Player found!")
		# Connect to the player's lives_changed signal
		player.lives_changed.connect(_on_player_lives_changed)
		# Set initial text from GameManager
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			_on_player_lives_changed(game_manager.get_lives())
		else:
			push_error("[LivesCounter] GameManager not found!")
			text = "?"
	else:
		text = "?"
		push_error("[LivesCounter] CRITICAL: Player not found!")

func _on_player_lives_changed(new_lives: int):
	text = str(new_lives)

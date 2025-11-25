extends ProgressBar

@onready var player: CharacterBody2D

func _ready():
	# Find the player in the scene
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Connect to the player's health_changed signal
		player.health_changed.connect(_on_player_health_changed)
		# Set initial values
		_on_player_health_changed(player.health, player.max_health)
	else:
		print("Warning: Player not found for health bar")

func _on_player_health_changed(new_health: float, maximum_health: int):
	max_value = maximum_health
	value = new_health

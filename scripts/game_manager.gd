extends Node

# Reference to the current scene name for easy resetting
var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

# --- GLOBAL LIVES SYSTEM ---
const MAX_LIVES = 9
var current_lives := MAX_LIVES
signal global_lives_changed(new_lives: int)

# Function to lose a life (called by player when they die)
func lose_life() -> bool:
	current_lives -= 1
	global_lives_changed.emit(current_lives)
	return current_lives > 0  # Returns true if player still has lives

# Function to reset lives (e.g., when starting a new game)
func reset_lives():
	current_lives = MAX_LIVES
	global_lives_changed.emit(current_lives)

# Function to get current lives count
func get_lives() -> int:
	return current_lives

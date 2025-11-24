extends Node

# Reference to the current scene name for easy resetting
var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

# --- GLOBAL LIVES SYSTEM ---
const MAX_LIVES = 9
var current_lives := MAX_LIVES
signal global_lives_changed(new_lives: int)

# Called automatically when the Node is instantiated (when the game starts)
func _ready():
	# Set up input for the reset action (ui_cancel is ESC/Controller Option button)
	# NOTE: Ensure "ui_cancel" is mapped in Project Settings -> Input Map
	set_process_input(true)

# Handle the Reset Input
func _input(event):
	# When ESC or the controller's Option/Start button is pressed, reset the scene.
	if event.is_action_pressed("pause"):
		reset_scene()

# Function to reset the current level
func reset_scene():
	# 1. Crucial step: Ensure the game is unpaused before reloading
	# This prevents the reloaded scene from starting in a paused state.
	get_tree().paused = false
	
	# Reset lives when going back to main menu
	current_lives = MAX_LIVES
	global_lives_changed.emit(current_lives)
		
	# 3. Reload the scene
	get_tree().change_scene_to_file(main_menu_scene_path)
	print("Scene reset and reloaded.")

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

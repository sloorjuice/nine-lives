extends Node

# Reference to the current scene name for easy resetting
var current_scene_path: String = ""

# Called automatically when the Node is instantiated (when the game starts)
func _ready():
	# Store the path of the current main scene when the game starts
	# This uses the correct property to get the path of the currently running scene.
	if get_tree().current_scene:
		current_scene_path = get_tree().current_scene.scene_file_path

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
	
	# 2. Check if a scene path was successfully recorded
	if current_scene_path.is_empty():
		print("ERROR: Cannot reset scene. current_scene_path is empty. Check Autoload setup.")
		return
		
	# 3. Reload the scene
	get_tree().reload_current_scene()
	print("Scene reset and reloaded.")

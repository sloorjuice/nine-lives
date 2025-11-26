extends CanvasLayer

@onready var stage = get_parent()
@onready var game_manager = get_node("/root/GameManager")
@onready var resume_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/RestartButton
@onready var return_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/ReturnButton


func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event):
	# If controller is used, set focus to resume button ONLY if nothing is focused
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		if not get_viewport().gui_get_focus_owner():
			resume_button.grab_focus()

func open_menu():
	visible = true
	resume_button.grab_focus() # Focus for controller navigation

func close_menu():
	visible = false

func on_resume_up() -> void:
	if stage.has_method("set_game_paused"):
		stage.set_game_paused(false)

func on_restart_up() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_return_up() -> void:
	# Save before returning to menu
	var stage = get_parent()
	if game_manager.current_slot > 0:
		SaveManager.save(
			game_manager.current_slot,
			get_tree().current_scene.scene_file_path,
			game_manager.get_lives(),
			game_manager.current_stage_index
	 )
	get_tree().paused = false
	get_tree().change_scene_to_file(game_manager.main_menu_scene_path)

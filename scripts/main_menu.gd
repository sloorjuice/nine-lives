class_name MainMenu
extends Control

@onready var slot_buttons := [
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 1 Row/Slot1Button",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 2 Row/Slot2Button",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 3 Row/Slot3Button"
]
@onready var slot_labels := [
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 1 Row/Slot1Label",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 2 Row/Slot2Label",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 3 Row/Slot3Label"
]
@onready var slot_icons := [
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 1 Row/Slot1Icon",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 2 Row/Slot2Icon",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 3 Row/Slot3Icon"
]
@onready var slot_delete_buttons := [
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 1 Row/Slot1DeleteButton",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 2 Row/Slot2DeleteButton",
	$"MarginContainer/HBoxContainer/VBoxContainer2/Slot 3 Row/Slot3DeleteButton"
]
@onready var quit_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/QuitButton
@onready var play_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/PlayButton
@onready var vbox_play: VBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer
@onready var vbox_slots: VBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer2

@export var start_level: PackedScene = preload("res://scenes/stages/stage_one.tscn")

@onready var cancel_button: Button = $MarginContainer/HBoxContainer/VBoxContainer2/CancelButton

var using_controller := false

func _ready():
	vbox_play.visible = true
	vbox_slots.visible = false
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(on_quit_up)
	cancel_button.pressed.connect(_on_back_pressed)
	# One-time signal connections
	for i in range(slot_buttons.size()):
		var slot = i + 1
		# FIX: Use bind to pass the correct slot value.
		# The anonymous func() was capturing the loop variable incorrectly.
		if not slot_buttons[i].pressed.is_connected(_on_slot_pressed):
			slot_buttons[i].pressed.connect(_on_slot_pressed.bind(slot))
		if not slot_delete_buttons[i].pressed.is_connected(_on_delete_slot_pressed):
			slot_delete_buttons[i].pressed.connect(_on_delete_slot_pressed.bind(slot))
	
	_setup_focus_navigation()
	_refresh_slots()
	_debug_list_files()
	
	# Initial controller check
	if Input.get_connected_joypads().size() > 0:
		using_controller = true
		_on_controller_detected()

func _setup_focus_navigation():
	# Main menu buttons
	play_button.focus_neighbor_bottom = play_button.get_path_to(quit_button)
	quit_button.focus_neighbor_top = quit_button.get_path_to(play_button)
	
	# Link play button to the first slot button
	play_button.focus_neighbor_right = play_button.get_path_to(slot_buttons[0])

	# Slot and Delete buttons
	for i in range(slot_buttons.size()):
		# Link slot button to its delete button
		slot_buttons[i].focus_neighbor_right = slot_buttons[i].get_path_to(slot_delete_buttons[i])
		slot_delete_buttons[i].focus_neighbor_left = slot_delete_buttons[i].get_path_to(slot_buttons[i])
		
		# Link back to the main play button from the first slot
		if i == 0:
			slot_buttons[i].focus_neighbor_left = slot_buttons[i].get_path_to(play_button)

		# Vertical navigation for slot buttons
		if i > 0:
			slot_buttons[i].focus_neighbor_top = slot_buttons[i].get_path_to(slot_buttons[i-1])
		if i < slot_buttons.size() - 1:
			slot_buttons[i].focus_neighbor_bottom = slot_buttons[i].get_path_to(slot_buttons[i+1])
			
		# Vertical navigation for delete buttons
		if i > 0:
			slot_delete_buttons[i].focus_neighbor_top = slot_delete_buttons[i].get_path_to(slot_delete_buttons[i-1])
		if i < slot_delete_buttons.size() - 1:
			slot_delete_buttons[i].focus_neighbor_bottom = slot_delete_buttons[i].get_path_to(slot_delete_buttons[i+1])

func _refresh_slots():
	for i in range(3):
		var slot = i + 1
		var save = SaveManager.load(slot)
		var used = SaveManager.has_save(slot) and save.has("stage") and save.has("lives")
		slot_delete_buttons[i].visible = used
		if used:
			var stage_path: String = save.get("stage", "")
			var lives_val = save.get("lives", 0)
			# Validate data before using
			if stage_path.is_empty() or not FileAccess.file_exists(stage_path):
				# Corrupted save - treat as empty
				slot_labels[i].text = "Empty (Corrupted)"
				slot_icons[i].visible = false
				slot_buttons[i].text = "New Game"
				slot_delete_buttons[i].visible = true # Show delete for corrupted saves
			else:
				var stage_name = stage_path.get_file().get_basename()
				slot_labels[i].text = "%d | %s" % [int(lives_val), stage_name]
				slot_icons[i].visible = true
				slot_buttons[i].text = "Continue"
		else:
			slot_labels[i].text = "Empty"
			slot_icons[i].visible = false
			slot_buttons[i].text = "New Game"

	# Music bus lowpass off
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index >= 0 and AudioServer.get_bus_effect_count(music_bus_index) > 0:
		AudioServer.set_bus_effect_enabled(music_bus_index, 0, false)

func _on_slot_pressed(slot: int):
	print("[MainMenu] =================================")
	print("[MainMenu] Slot pressed:", slot)
	
	# 1. Disable buttons
	for btn in slot_buttons:
		btn.disabled = true
	for btn in slot_delete_buttons:
		btn.disabled = true
	
	# 2. SET SLOT IMMEDIATELY
	GameManager.set_slot(slot)
	
	# 3. Verify it was set
	await get_tree().process_frame
	print("[MainMenu] VERIFICATION: GameManager.current_slot is now: ", GameManager.current_slot)
	
	# 4. Now handle save/load logic
	var save = SaveManager.load(slot)
	var target_path = ""
	
	if save.has("stage") and save.has("lives"):
		var saved_lives: int = save.get("lives", 0)
		var stage_path: String = save.get("stage", "")
		
		# If save has 0 or fewer lives, treat it as a new game (shouldn't happen, but safety check)
		if saved_lives <= 0:
			print("[MainMenu] Save has 0 lives - starting new game")
			SaveManager.delete(slot)
			GameManager.reset_lives()
			target_path = start_level.resource_path
			SaveManager.save(slot, target_path, GameManager.get_lives())
		elif stage_path.is_empty() or not FileAccess.file_exists(stage_path):
			GameManager.current_lives = saved_lives
			target_path = start_level.resource_path
			SaveManager.save(slot, target_path, GameManager.get_lives())
		else:
			# Valid save - load it
			GameManager.current_lives = saved_lives
			target_path = stage_path
	else:
		print("[MainMenu] New game")
		SaveManager.delete(slot)
		GameManager.reset_lives()
		target_path = start_level.resource_path
		SaveManager.save(slot, target_path, GameManager.get_lives())
	
	print("[MainMenu] Final check - slot before scene change: ", GameManager.current_slot)
	print("[MainMenu] Changing to: ", target_path)
	
	# 5. Change scene
	get_tree().call_deferred("change_scene_to_file", target_path)


func _on_delete_slot_pressed(slot: int):
	print("[MainMenu] Delete requested for slot", slot)
	SaveManager.delete(slot)
	_refresh_slots()
	
	# After deleting, the button is hidden, and focus is lost.
	# If using a controller, we must manually re-focus the corresponding slot button.
	if using_controller:
		var button_index = slot - 1
		if button_index >= 0 and button_index < slot_buttons.size():
			slot_buttons[button_index].grab_focus()

func on_quit_up() -> void:
	get_tree().quit()

func _unhandled_input(event):
	# Handle back button press on controller
	if vbox_slots.visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_tree().get_root().set_input_as_handled()
		return

	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if not using_controller:
			using_controller = true
			_on_controller_detected()
	elif event is InputEventMouseMotion:
		if using_controller:
			using_controller = false
			get_viewport().gui_release_focus()

func _on_controller_detected():
	# Focus first interactive button
	if vbox_play.visible:
		play_button.grab_focus()
	elif vbox_slots.visible:
		slot_buttons[0].grab_focus()

func _on_play_pressed():
	vbox_play.visible = false
	vbox_slots.visible = true
	_refresh_slots()
	# Wait one frame for the UI to update before grabbing focus
	await get_tree().process_frame
	if using_controller:
		slot_buttons[0].grab_focus()

func _on_back_pressed():
	vbox_slots.visible = false
	vbox_play.visible = true
	if using_controller:
		play_button.grab_focus()

func _debug_list_files():
	SaveManager.debug_list()

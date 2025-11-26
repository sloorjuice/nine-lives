extends Node

signal current_yarn_changed(new_amount: int)
signal slot_changed(slot: int)

const STARTING_LIVES = 9
var current_lives := STARTING_LIVES
var current_yarn := 0
var current_slot := 0
var main_menu_scene_path: String = "res://scenes/menus/main_menu.tscn"

func _ready():
	# CRITICAL: Mark as always processing so it never gets unloaded
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- FIX STARTS HERE ---
	# Check if another GameManager already exists.
	var existing_gms = get_tree().get_nodes_in_group("game_manager")
	for gm in existing_gms:
		# If we find another one that isn't us, it's the old one. Get rid of it.
		if gm != self:
			print("[GameManager] Found and removing old GameManager instance.")
			gm.queue_free()
	
	# Now, add this (the new) instance to the group.
	if not is_in_group("game_manager"):
		add_to_group("game_manager")
	# --- FIX ENDS HERE ---
	
	print("[GameManager] READY - Initialized with slot: ", current_slot)

func reset_current_yarn() -> void:
	current_yarn = 0
	current_yarn_changed.emit(current_yarn)
	print("[GameManager] Session yarn reset to 0.")

func add_current_yarn(amount: int) -> void:
	current_yarn += max(0, amount)
	current_yarn_changed.emit(current_yarn)

func get_current_yarn() -> int:
	return current_yarn

func set_slot(slot: int) -> void:
	print("[GameManager] Setting slot from ", current_slot, " to ", slot)
	current_slot = slot
	slot_changed.emit(current_slot)
	print("[GameManager] Slot is now: ", current_slot)

func get_lives() -> int:
	return current_lives

func reset_lives() -> void:
	current_lives = STARTING_LIVES
	print("[GameManager] Lives reset to ", STARTING_LIVES)

# Returns true if player can continue playing, false if game over
func lose_life() -> bool:
	current_lives -= 1
	print("[GameManager] Lost a life. Remaining: ", current_lives)

	if current_lives < 0:
		current_lives = 0

	if current_lives <= 0:
		if current_slot > 0:
			print("[GameManager] GAME OVER - Deleting save for slot ", current_slot)
			SaveManager.delete(current_slot)
		return false

	if current_slot > 0 and _can_save_current_scene():
		SaveManager.save(current_slot, get_tree().current_scene.scene_file_path, current_lives)

	return true

func _can_save_current_scene() -> bool:
	var sc = get_tree().current_scene
	if sc == null:
		return false
	var path: String = sc.scene_file_path
	if path.is_empty():
		return false
	return path.begins_with("res://scenes/stage_") or path.begins_with("res://scenes/test") or path.begins_with("res://scenes/base_stage")

func _notification(what):
	if what == NOTIFICATION_CRASH: # Rarely called; fallback: use global script error print
		print("[GameManager] NOTIFICATION_CRASH")

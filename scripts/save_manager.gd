extends Node

const SAVE_FILE_PATH = "user://global_save_data.save"

# Helper to load the master dictionary from the single file
func _load_all_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return {}
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for reading.")
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: Save file corrupted (not a dictionary). Resetting.")
		return {}
	# Defensive: remove any non-int keys
	for k in data.keys():
		if typeof(k) != TYPE_INT:
			data.erase(k)
	return data

# Helper to save the master dictionary to the single file
func _save_all_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open save file for writing.")
		return
	
	file.store_var(data)
	file.close()

# Save data format: { "stage": String, "lives": int }
func save(slot: int, stage: String, lives: int) -> void:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] Reject save: invalid slot " + str(slot))
		return
	var all_data = _load_all_data()
	all_data[slot] = {"stage": stage, "lives": lives}
	_save_all_data(all_data)
	print("[SaveManager] Saved slot %d -> %s | lives=%d" % [slot, stage, lives])

func load(slot: int) -> Dictionary:
	var all_data = _load_all_data()
	
	if all_data.has(slot):
		var slot_data = all_data[slot]
		print("[SaveManager] Loaded slot %d -> %s" % [slot, str(slot_data)])
		return slot_data
	
	print("[SaveManager] load: no data for slot %d" % slot)
	return {}

func delete(slot: int) -> void:
	var all_data = _load_all_data()
	
	if all_data.has(slot):
		all_data.erase(slot)
		_save_all_data(all_data)
		print("[SaveManager] Deleted slot %d" % slot)
	else:
		print("[SaveManager] delete: slot %d empty, nothing to delete" % slot)

func has_save(slot: int) -> bool:
	var all_data = _load_all_data()
	return all_data.has(slot)

func debug_list():
	var all_data = _load_all_data()
	print("[SaveManager] Current Global Save Data:")
	print(all_data)

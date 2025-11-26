extends Node

signal yarn_total_changed(slot: int, total: int)
signal bones_total_changed(slot: int, total: int)
signal monster_bits_total_changed(slot: int, total: int)

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
func save(slot: int, stage: String, lives: int, stage_index: int = 0) -> void:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] Reject save: invalid slot " + str(slot))
		return
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	var yarn_count: int = slot_data.get("yarn_count", 0) 
	var bones_count: int = slot_data.get("bones_count", 0)
	var monster_bits_count: int = slot_data.get("monster_bits_count", 0)
	all_data[slot] = {
		"stage": stage, 
		"lives": lives, 
		"stage_index": stage_index,
		"yarn_count": yarn_count,
		"bones_count": bones_count,
		"monster_bits_count": monster_bits_count
	}
	_save_all_data(all_data)
	print("[SaveManager] Saved slot %d -> %s | lives=%d | yarn=%d | bones=%d | bits=%d" % [slot, stage, lives, yarn_count, bones_count, monster_bits_count])

func get_yarn_count(slot: int) -> int:
	var all_data = _load_all_data()
	if all_data.has(slot):
		return int(all_data[slot].get("yarn_count", 0))
	return 0

func set_yarn_count(slot: int, count: int) -> void:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] set_yarn_count: invalid slot " + str(slot))
		return
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	slot_data["yarn_count"] = max(0, count)
	all_data[slot] = slot_data
	_save_all_data(all_data)
	print("[SaveManager] Set yarn_count for slot %d to %d" % [slot, count])
	yarn_total_changed.emit(slot, slot_data["yarn_count"])

func add_yarn(slot: int, amount: int = 1) -> int:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] add_yarn: invalid slot " + str(slot))
		return 0
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	var current = int(slot_data.get("yarn_count", 0))
	current += max(0, amount)
	slot_data["yarn_count"] = current
	all_data[slot] = slot_data
	_save_all_data(all_data)
	print("[SaveManager] Slot %d yarn_count += %d -> %d" % [slot, amount, current])
	yarn_total_changed.emit(slot, current)
	return current

func get_bones_count(slot: int) -> int:
	var all_data = _load_all_data()
	if all_data.has(slot):
		return int(all_data[slot].get("bones_count", 0))
	return 0

func set_bones_count(slot: int, count: int) -> void:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] set_bones_count: invalid slot " + str(slot))
		return
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	slot_data["bones_count"] = max(0, count)
	all_data[slot] = slot_data
	_save_all_data(all_data)
	print("[SaveManager] Set bones_count for slot %d to %d" % [slot, count])
	bones_total_changed.emit(slot, slot_data["bones_count"])
	
func add_bones(slot: int, amount: int = 1) -> int:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] add_bones: invalid slot " + str(slot))
		return 0
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	var current = int(slot_data.get("bones_count", 0))
	current += max(0, amount)
	slot_data["bones_count"] = current
	all_data[slot] = slot_data
	_save_all_data(all_data)
	print("[SaveManager] Slot %d bones_count += %d -> %d" % [slot, amount, current])
	bones_total_changed.emit(slot, current)
	return current

func get_monster_bits_count(slot: int) -> int:
	var all_data = _load_all_data()
	if all_data.has(slot):
		return int(all_data[slot].get("monster_bits_count", 0))
	return 0

func set_monster_bits_count(slot: int, count: int) -> void:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] set_monster_bits_count: invalid slot " + str(slot))
		return
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	slot_data["monster_bits_count"] = max(0, count)
	all_data[slot] = slot_data
	_save_all_data(all_data)
	print("[SaveManager] Set monster_bits_count for slot %d to %d" % [slot, count])
	monster_bits_total_changed.emit(slot, slot_data["monster_bits_count"])

func add_monster_bits(slot: int, amount: int = 1) -> int:
	if slot < 1 or slot > 3:
		push_error("[SaveManager] add_monster_bits: invalid slot " + str(slot))
		return 0
	var all_data = _load_all_data()
	var slot_data: Dictionary = all_data.get(slot, {})
	var current = int(slot_data.get("monster_bits_count", 0))
	current += max(0, amount)
	slot_data["monster_bits_count"] = current
	all_data[slot] = slot_data
	_save_all_data(all_data)
	print("[SaveManager] Slot %d monster_bits_count += %d -> %d" % [slot, amount, current])
	monster_bits_total_changed.emit(slot, current)
	return current

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

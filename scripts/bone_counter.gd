extends Label

@onready var gm = get_node_or_null("/root/GameManager")

func _ready() -> void:
	if gm:
		if not gm.current_bones_changed.is_connected(_on_current_bones_changed):
			gm.current_bones_changed.connect(_on_current_bones_changed)
		if not gm.slot_changed.is_connected(_on_slot_changed):
			gm.slot_changed.connect(_on_slot_changed)
	if not SaveManager.bones_total_changed.is_connected(_on_bone_total_changed):
		SaveManager.bones_total_changed.connect(_on_bone_total_changed)
	_update_text()

func _update_text():
	if gm == null:
		text = "Bones: ?"
		return
	var slot: int = int(gm.current_slot)
	var saved: int = SaveManager.get_bones_count(slot) if slot > 0 else 0
	var level: int = int(gm.get_current_bones())
	text = "%d" % [saved + level]


func _on_current_bones_changed(_new_amount: int) -> void:
	_update_text()

func _on_bone_total_changed(slot: int, _total: int) -> void:
	if gm and slot == gm.current_slot:
		_update_text()

func _on_slot_changed(_slot: int) -> void:
	_update_text()

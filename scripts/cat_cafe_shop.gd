extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var gm = get_node("/root/GameManager")
	if gm.current_slot > 0:
		SaveManager.save(gm.current_slot, get_tree().current_scene.scene_file_path, gm.get_lives(), gm.current_stage_index)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends Area2D

var player_in_area := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("dash"):
		var gm = get_node("/root/GameManager")
		# FIX: Load the current stage instead of the next one
		var current_stage = gm.stages[gm.current_stage_index]
		if current_stage != "":
			get_tree().change_scene_to_file(current_stage)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = false

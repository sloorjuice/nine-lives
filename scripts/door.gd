extends Area2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_shape: CollisionShape2D = $InteractionShape2D
@onready var player_collision_shape: CollisionShape2D = $PlayerCollisionShape2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var NEXT_SCENE_PATH = "res://scenes/thanks_for_playing.tscn"
@export var REQUIRED_MONSTER_KILLS = 10

var is_locked: bool = true
var player_can_interact: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio_stream_player_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("exit_door")
	
	# Wait for all nodes to be ready before connecting
	await get_tree().process_frame
	
	var counter_node = get_tree().get_first_node_in_group("enemy_counter")
	if counter_node:
		counter_node.connect("all_enemies_dead", Callable(self, "_on_all_enemies_dead"))
	else:
		print("DOOR WARNING: Could not find enemy_counter!")
	
	body_entered.connect(Callable(self, "_on_body_entered"))
	body_exited.connect(Callable(self, "_on_body_exited"))
	
	animated_sprite_2d.play("closed")
	interaction_shape.set_deferred("disabled", true)
	player_collision_shape.set_deferred("disabled", false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_locked:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var player_node = get_tree().get_first_node_in_group("player")
			if not player_node:
				return
			
			var player_distance = global_position.distance_to(player_node.global_position)
			if player_distance < 100:
				go_to_next_level()
		
		if event.is_action_pressed("move_up") and player_can_interact:
			go_to_next_level()
				
func _on_all_enemies_dead():
	is_locked = false
	
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		_finish_cinematic()
		return
	
	# Stop the music for cinematic
	var stage = get_tree().current_scene
	var music_player = stage.get_node_or_null("BGM_Player")
	if music_player:
		music_player.stream_paused = true
	
	get_tree().paused = true # Pause the game for the cinematic
	
	await get_tree().create_timer(0.3, true, false, true).timeout
	
	# Freeze player
	player_node.set_physics_process(false)
	player_node.set_process_input(false)
	player_node.velocity = Vector2.ZERO
	
	var cam: Camera2D = player_node.get_node("Camera2D")
	if not cam or not is_instance_valid(cam):
		print("DOOR ERROR: No Camera2D on player! Skipping cinematic.")
		_finish_cinematic(player_node)
		return
	
	# Temporary cinematic camera (do not touch limits of player cam)
	var world = get_tree().current_scene
	var cine_cam := Camera2D.new()
	cine_cam.name = "CinematicCamera"
	cine_cam.global_position = cam.global_position
	cine_cam.position_smoothing_enabled = false
	world.add_child(cine_cam)
	cine_cam.make_current()  # Activate cinematic camera
	
	# Tween to door
	var tween_to_door = create_tween()
	tween_to_door.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_to_door.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var door_target = global_position + Vector2(0, -80)
	tween_to_door.tween_property(cine_cam, "global_position", door_target, 1.8)
	await tween_to_door.finished
	
	await get_tree().create_timer(0.4, true, false, true).timeout
	
	# Open door with shake
	player_collision_shape.set_deferred("disabled", true)
	Input.start_joy_vibration(0, 1.0, 1.0, 1.0)
	animated_sprite_2d.play("opening")
	audio_stream_player_2d.play()
	
	var shake_tween = create_tween()
	shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(3):
		var shake_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		shake_tween.tween_property(cine_cam, "offset", shake_offset, 0.05)
		shake_tween.tween_property(cine_cam, "offset", Vector2.ZERO, 0.05)
	
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("opened")
	
	await get_tree().create_timer(0.5, true, false, true).timeout
	
	# Pan back to player
	var tween_back = create_tween()
	tween_back.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_back.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_back.tween_property(cine_cam, "global_position", player_node.global_position, 1.5)
	await tween_back.finished
	
	# Restore player camera
	cam.global_position = cine_cam.global_position
	cam.make_current()
	cine_cam.queue_free()
	
	_finish_cinematic(player_node)
	
func _finish_cinematic(player_node: Node = null):
	interaction_shape.set_deferred("disabled", false)

	# Wait for physics to register the enabled shape (Godot quirk)
	await get_tree().physics_frame

	# Manually detect current overlaps
	player_can_interact = false
	var overlapping_bodies = get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			player_can_interact = true
			break

	# Unpause the game
	get_tree().paused = false
	
	# Resume the music after cinematic
	var stage = get_tree().current_scene
	var music_player = stage.get_node_or_null("BGM_Player")
	if music_player:
		music_player.stream_paused = false

	# Unfreeze player
	if player_node:
		player_node.set_physics_process(true)
		player_node.set_process_input(true)
	
	add_to_group("exit_door")	
	
	if player_can_interact:
		print("DOOR: Unlocked! Click or press UP to continue.")
	else:
		print("DOOR: Unlocked! Approach the door to continue.")

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_can_interact = true
		print("DOOR: Player entered interaction zone. Press UP to	 exit.")

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_can_interact = false
		print("DOOR: Player exited interaction zone.")

func go_to_next_level():
	print("DOOR: Changing scene to shop")
	var gm = get_node("/root/GameManager")
	var slot = gm.current_slot

	# Persist yarn
	var session_yarn = gm.get_current_yarn()
	if slot > 0 and session_yarn > 0:
		SaveManager.add_yarn(slot, session_yarn)
		gm.reset_current_yarn()

	# Persist bones
	var session_bones = gm.get_current_bones()
	if slot > 0 and session_bones > 0:
		SaveManager.add_bones(slot, session_bones)
		gm.reset_current_bones()

	# Persist monster bits
	var session_bits = gm.get_current_monster_bits()
	if slot > 0 and session_bits > 0:
		SaveManager.add_monster_bits(slot, session_bits)
		gm.reset_current_monster_bits()

	# --- FIX: Advance the stage index ---
	gm.advance_stage()

	get_tree().change_scene_to_file(gm.shop_scene_path)

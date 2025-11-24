extends Area2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_shape: CollisionShape2D = $InteractionShape2D
@onready var player_collision_shape: CollisionShape2D = $PlayerCollisionShape2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var NEXT_SCENE_PATH = "res://scenes/thanks_for_playing.tscn"

var is_locked: bool = true
var player_can_interact: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var counter_node = get_tree().get_first_node_in_group("enemy_counter")
	if counter_node:
		counter_node.connect("all_enemies_dead", Callable(self, "_on_all_enemies_dead"))
	
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
	
	# Brief pause before cinematic starts
	await get_tree().create_timer(0.3, true, false, true).timeout
	
	# Freeze player completely
	player_node.set_physics_process(false)
	player_node.set_process_input(false)
	player_node.velocity = Vector2.ZERO
	
	var cam: Camera2D = player_node.get_node("Camera2D")
	print("Player: ", player_node)
	print("Cam: ", player_node.get_node("Camera2D") if player_node else null)
	if not cam or not is_instance_valid(cam):
		print("DOOR ERROR: No Camera2D on player! Skipping cinematic.")
		_finish_cinematic(player_node)
		return
	
	# Save camera settings
	var orig_smoothing = cam.position_smoothing_enabled
	var orig_smoothing_speed = cam.position_smoothing_speed
	var orig_limit_smoothed = cam.limit_smoothed
	var orig_limits = {
		"left": cam.limit_left, "right": cam.limit_right,
		"top": cam.limit_top, "bottom": cam.limit_bottom
	}
	
	# Make camera independent and always process
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.position_smoothing_enabled = false
	cam.limit_smoothed = false
	cam.limit_left = -10000000
	cam.limit_right = 10000000
	cam.limit_top = -10000000
	cam.limit_bottom = 10000000
	
	# Reparent camera to world
	var world = get_tree().current_scene
	var cam_start_pos = cam.global_position
	cam.reparent(world)
	cam.global_position = cam_start_pos
	
	# Smooth pan to door with easing
	var tween_to_door = create_tween()
	tween_to_door.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_to_door.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	var door_target = global_position + Vector2(0, -80)
	tween_to_door.tween_property(cam, "global_position", door_target, 1.8)
	
	await tween_to_door.finished
	
	# Small delay to let player see the door
	await get_tree().create_timer(0.4, true, false, true).timeout
	
	# Open door with subtle camera shake
	player_collision_shape.set_deferred("disabled", true)
	animated_sprite_2d.play("opening")
	audio_stream_player_2d.play()
	
	# Camera shake during door opening
	var shake_tween = create_tween()
	shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	for i in range(3):
		var shake_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		shake_tween.tween_property(cam, "offset", shake_offset, 0.05)
		shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)
	
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("opened")
	
	# Hold on open door
	await get_tree().create_timer(0.5, true, false, true).timeout
	
	# Smooth pan back to player
	var tween_back = create_tween()
	tween_back.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_back.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_back.tween_property(cam, "global_position", player_node.global_position, 1.5)
	
	await tween_back.finished
	
	# CRITICAL FIX: Reset offset and position BEFORE reparenting
	cam.offset = Vector2.ZERO
	cam.global_position = player_node.global_position
	
	# Reparent camera back to player
	cam.reparent(player_node)
	cam.position = Vector2.ZERO  # Local position to player
	
	# Wait one frame for the reparenting to settle
	await get_tree().process_frame
	
	# NOW restore camera settings
	cam.position_smoothing_enabled = orig_smoothing
	cam.position_smoothing_speed = orig_smoothing_speed
	cam.limit_smoothed = orig_limit_smoothed
	cam.limit_left = orig_limits.left
	cam.limit_right = orig_limits.right
	cam.limit_top = orig_limits.top
	cam.limit_bottom = orig_limits.bottom
	cam.process_mode = Node.PROCESS_MODE_INHERIT
	
	_finish_cinematic(player_node)
	
func _finish_cinematic(player_node: Node = null):
	interaction_shape.set_deferred("disabled", false)

	# Wait for physics to register the enabled shape (Godot quirk)
	await get_tree().physics_frame  # Or process_frame if picky

	# Manually detect current overlaps (fixes enable-no-signal bug)
	player_can_interact = false  # Reset first
	var overlapping_bodies = get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			player_can_interact = true
			break

	# Unpause the game
	get_tree().paused = false

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
		print("DOOR: Player entered interaction zone. Press UP to exit.")

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_can_interact = false
		print("DOOR: Player exited interaction zone.")

func go_to_next_level():
	print("DOOR: Changing scene to %s" % NEXT_SCENE_PATH)
	get_tree().change_scene_to_file(NEXT_SCENE_PATH)

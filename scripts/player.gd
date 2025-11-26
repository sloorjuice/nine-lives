extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = $Camera2D
@onready var hitbox: Area2D = $Hitbox
@onready var sfx_jump: AudioStreamPlayer2D = $SFX_Jump
@onready var sfx_attack: AudioStreamPlayer2D = $SFX_Attack
@onready var sfx_dash: AudioStreamPlayer2D = $SFX_Dash
@onready var sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death
@onready var sfx_meow: AudioStreamPlayer2D = $SFX_Meow

@onready var combo_counter: Label = $"../GUI/ComboCounter"
@onready var combo_timer_bar: ProgressBar = $"../GUI/ComboTimer"
@onready var dash_cooldown_bar: ProgressBar = $"../GUI/DashCooldownBar"

@onready var detection_area: Area2D = $DetectionArea

# NEW: Reference to the Regeneration Delay Progress Bar
@onready var regen_timer_bar: ProgressBar = $"../GUI/RegenTimerBar"

# NEW: Preload your meow sounds
var meow_sounds = [
	preload("res://assets/audio/SFX/player/cat_sounds/meow1.mp3"),
	preload("res://assets/audio/SFX/player/cat_sounds/meow2.mp3"),
	preload("res://assets/audio/SFX/player/cat_sounds/meow3.mp3")
]

const SPEED = 240.0
const JUMP_VELOCITY = -380.0
const HOP_VELOCITY = -200.0
const GROUND_ACCELERATION = 1100.0
const AIR_ACCELERATION = 1350.0
const GROUND_FRICTION = 800.0
const AIR_FRICTION = 100.0
const COYOTE_TIME = 0.15
const JUMP_BUFFER_TIME = 0.1
const JUMP_CUT_MULTIPLIER = 0.3
const DASH_SPEED = 250.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 1.2
const ROLL_SPEED = 300.0
const ROLL_DURATION = 0.4
const ROLL_COOLDOWN = 0.2
const WALL_CLIMB_SPEED = 150.0
const WALL_CLIMB_DOWN_SPEED = 80.0
const WALL_SLIDE_SPEED = 50.0
const WALL_JUMP_VELOCITY = Vector2(300, -280)

const COMBO_TIMEOUT = 5.0

@export var death_threshold: float = 500.0
@export var kill_threshold: float = 530.0
@export var death_animation_duration: float = 0.5

const DAMAGE_NORMAL = 1
const DAMAGE_HEAVY = 3

# --- LIVES SYSTEM ---
# Lives are now managed globally by GameManager
signal lives_changed(new_lives: int)
signal health_changed(new_health: float, max_health: int)

# --- INPUT HANDLING ---
enum InputType { KEYBOARD_MOUSE, CONTROLLER }
var input_type := InputType.KEYBOARD_MOUSE

# NEW: Variables for managing the mouse aim lock
const MOUSE_AIM_LOCK_DURATION = 0.5
var mouse_aim_lock_timer = 0.0

# NEW: Track previous frame's floor state for landing detection
var was_on_floor := false

var spawn_point: Node2D
var is_dying = false
var is_game_over = false

var can_double_jump = true
var double_jumping = false
var is_wall_sliding = false
var is_wall_clinging = false
var is_jumping = false
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = 1
var is_rolling = false
var roll_timer = 0.0
var roll_cooldown_timer = 0.0
var roll_direction = 1
var facing_direction := 1
var _default_hitbox_scale_x := 1.0

var max_health := 5.0
var health := 5.0

var regen_rate := 2.5
const REGEN_DELAY_TIME = 5.2
var regen_delay_timer = 0.0
var platform_drop_timer = 0.0
var combo_count := 0
var combo_timer := 0.0

var invincible := false
var invincibility_time := 0.6

var hit_stun_time := 0.3
var hit_stun_timer := 0.0

var is_attacking = false
var is_hurt := false  # NEW

func _ready():
	add_to_group("player")
	spawn_point = get_tree().get_first_node_in_group("spawn_point")
	if spawn_point:
		global_position = spawn_point.global_position

	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	_default_hitbox_scale_x = abs(hitbox.scale.x)
	
	# Emit current lives from GameManager
	var game_manager = get_node("/root/GameManager")
	lives_changed.emit(game_manager.get_lives())
	was_on_floor = is_on_floor()
	
	# Change these from false to true if you want them always showing:
	combo_counter.visible = false  # Changed from false
	combo_timer_bar.visible = false # Changed from false
	
	combo_timer_bar.max_value = COMBO_TIMEOUT
	combo_timer_bar.visible = false
	
	if regen_timer_bar:
		regen_timer_bar.max_value = REGEN_DELAY_TIME
		regen_timer_bar.value = REGEN_DELAY_TIME
		regen_timer_bar.visible = false

func _input(event: InputEvent) -> void:
	if get_tree().paused and not event.is_action_pressed("pause"):
		return
	
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		input_type = InputType.CONTROLLER
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		input_type = InputType.KEYBOARD_MOUSE

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	
	if Input.is_action_just_pressed("meow"):
		play_random_meow()
		
	# Update combo timer
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer_bar:
			combo_timer_bar.value = combo_timer
		if combo_timer <= 0:
			reset_combo()
		
	# NEW: Health Regen Delay Logic
	if regen_delay_timer > 0.0:
		regen_delay_timer -= delta
		
		# Update and show the progress bar
		if regen_timer_bar:
			regen_timer_bar.value = regen_delay_timer
			if not regen_timer_bar.visible:
				regen_timer_bar.visible = true
	
	if regen_delay_timer <= 0.0:
		# Hide the progress bar once regeneration starts
		if regen_timer_bar and regen_timer_bar.visible:
			regen_timer_bar.visible = false
			
		var old_health = health
		health = min(max_health, health + regen_rate * delta)
		if health != old_health:
			health_changed.emit(health, max_health)

	if mouse_aim_lock_timer > 0.0:
		mouse_aim_lock_timer -= delta

	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		return
	
	if is_game_over:
		velocity = Vector2.ZERO
		return
		
	if global_position.y > death_threshold and not is_dying:
		start_death()
		return
	if global_position.y > kill_threshold:
		respawn()
		return
	if is_dying:
		velocity = Vector2.ZERO
		return

	# NEW: Check for directional attack inputs (right stick)
	if not is_attacking and not is_dashing and not is_rolling and not is_wall_clinging:
		if Input.is_action_just_pressed("attack_up"):
			perform_directional_attack(-1.0) # Up
		elif Input.is_action_just_pressed("attack_down"):
			perform_directional_attack(1.0) # Down
		elif Input.is_action_just_pressed("attack_left"):
			perform_directional_attack(0.0, -1)# Left
		elif Input.is_action_just_pressed("attack_right"):
			perform_directional_attack(0.0, 1) # Right
		elif Input.is_action_just_pressed("attack"):
			perform_attack("attack")
		elif Input.is_action_just_pressed("attack_heavy") and is_on_floor():
			var vertical_input = Input.get_axis("move_up", "move_down")
			if abs(vertical_input) < 0.5:
				perform_attack("attack_heavy")

	is_wall_sliding = false
	is_wall_clinging = false

	if is_on_wall() and not is_on_floor() and not is_attacking:
		if Input.is_action_pressed("wall_cling"):
			is_wall_clinging = true
			can_double_jump = true
			var vertical_input = Input.get_axis("move_up", "move_down")
			# Also check WASD keys directly for keyboard/mouse
			if vertical_input == 0.0 and input_type == InputType.KEYBOARD_MOUSE:
				if Input.is_action_pressed("move_up"):
					vertical_input = -1.0
				elif Input.is_action_pressed("move_down"):
					vertical_input = 1.0
			if vertical_input < 0:
				velocity.y = -WALL_CLIMB_SPEED
			elif vertical_input > 0:
				velocity.y = WALL_CLIMB_DOWN_SPEED
			else:
				velocity.y = 0
		elif velocity.y > 0:
			is_wall_sliding = true
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
			can_double_jump = true

	if is_wall_clinging:
		var vertical_input = Input.get_axis("move_up", "move_down")
		if vertical_input < 0:
			var space_state = get_world_2d().direct_space_state
			var wall_normal = get_wall_normal()
			
			var check_offset_1 = Vector2(-wall_normal.x * 10, -15)
			var check_offset_2 = Vector2(-wall_normal.x * 15, -25)
			var check_offset_3 = Vector2(-wall_normal.x * 5, -30)
			
			var query_1 = PhysicsRayQueryParameters2D.create(global_position, global_position + check_offset_1)
			var query_2 = PhysicsRayQueryParameters2D.create(global_position, global_position + check_offset_2)
			var query_3 = PhysicsRayQueryParameters2D.create(global_position, global_position + check_offset_3)
			
			var result_1 = space_state.intersect_ray(query_1)
			var result_2 = space_state.intersect_ray(query_2)
			var result_3 = space_state.intersect_ray(query_3)
			
			if not result_1 and not result_2 and not result_3:
				var wall_direction = 1 if animated_sprite_2d.flip_h else -1
				velocity.x = -wall_direction * 150
				velocity.y = -200
				is_wall_clinging = false

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
		double_jumping = false
	else:
		coyote_timer -= delta
	
	if jump_buffer_timer > 0: 
		jump_buffer_timer -= delta
	if dash_cooldown_timer > 0: 
		dash_cooldown_timer -= delta
		if dash_cooldown_bar:
			dash_cooldown_bar.max_value = DASH_COOLDOWN
			dash_cooldown_bar.value = dash_cooldown_timer  # Changed: now shows remaining time
			if not dash_cooldown_bar.visible:
				dash_cooldown_bar.visible = true
	else:
		# Hide the bar when dash is ready
		if dash_cooldown_bar and dash_cooldown_bar.visible:
			dash_cooldown_bar.visible = false
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0: 
			is_dashing = false
			rotation = 0.0 
	
	# FIXED: Only vibrate if dash actually starts
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and not is_rolling and not is_attacking:
		sfx_dash.play()
		Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		
		var dash_input_dir := Input.get_axis("move_left", "move_right")
		var vertical_input := Input.get_axis("move_up", "move_down")
		var intended_dir = facing_direction
		var dash_angle := 0.0
		
		# Handle mouse/keyboard input differently from controller
		if input_type == InputType.KEYBOARD_MOUSE:
			# Dash toward mouse cursor
			var mouse_pos = get_global_mouse_position()
			var direction_to_mouse = (mouse_pos - global_position).normalized()
			
			# Determine if dash is more vertical or horizontal
			if abs(direction_to_mouse.y) > abs(direction_to_mouse.x):
				# Vertical dash (up or down)
				if direction_to_mouse.y > 0:
					# Dash down
					dash_angle = PI / 2.0
					if animated_sprite_2d.flip_h:
						dash_angle = -PI / 2.0
					dash_direction = 2  # Special flag for down
				else:
					# Dash up
					dash_angle = -PI / 2.0
					if animated_sprite_2d.flip_h:
						dash_angle = PI / 2.0
					dash_direction = 3  # Special flag for up
			else:
				# Horizontal dash
				intended_dir = 1 if direction_to_mouse.x > 0 else -1
				dash_direction = intended_dir
				facing_direction = intended_dir
				animated_sprite_2d.flip_h = facing_direction < 0
		else:
			# Controller input - use original logic
			# Determine dash direction and rotation
			if abs(vertical_input) > 0.5:
				# Vertical dash (up or down)
				if vertical_input > 0:
					# Dash down
					dash_angle = PI / 2.0
					if animated_sprite_2d.flip_h:
						dash_angle = -PI / 2.0
					dash_direction = 2  # Special flag for down
				else:
					# Dash up
					dash_angle = -PI / 2.0
					if animated_sprite_2d.flip_h:
						dash_angle = PI / 2.0
					dash_direction = 3  # Special flag for up
			else:
				# Horizontal dash
				if abs(dash_input_dir) > 0.1:
					intended_dir = 1 if dash_input_dir > 0 else -1
				elif abs(velocity.x) > 10:
					intended_dir = 1 if velocity.x > 0 else -1
			
				dash_direction = intended_dir
				facing_direction = intended_dir
				animated_sprite_2d.flip_h = facing_direction < 0
		
		rotation = dash_angle
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		can_double_jump = true
	
	if roll_cooldown_timer > 0: roll_cooldown_timer -= delta
	if roll_timer > 0:
		roll_timer -= delta
		if roll_timer <= 0: is_rolling = false
	
	# FIXED: Only vibrate if roll actually starts
	if Input.is_action_just_pressed("roll") and roll_cooldown_timer <= 0 and is_on_floor() and not is_attacking:
		sfx_dash.play()
		Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		
		var roll_input_dir := Input.get_axis("move_left", "move_right")
		var intended_dir := facing_direction

		if abs(roll_input_dir) > 0.1:
			intended_dir = 1 if roll_input_dir > 0 else -1
		elif abs(velocity.x) > 10:
			intended_dir = 1 if velocity.x > 0 else -1

		roll_direction = intended_dir
		facing_direction = intended_dir
		animated_sprite_2d.flip_h = facing_direction < 0
		
		is_rolling = true
		roll_timer = ROLL_DURATION
		roll_cooldown_timer = ROLL_COOLDOWN
	
	if not is_on_floor() and not is_dashing:
		if is_attacking:
			velocity.y = 0
			velocity.x = 0
		elif is_wall_clinging:
			pass
		elif is_wall_sliding:
			velocity += get_gravity() * delta * 0.3
		else:
			velocity += get_gravity() * delta
	
	# FIXED: Jump vibration only when jump actually happens
	if Input.is_action_just_pressed("jump") and not is_attacking:
		jump_buffer_timer = JUMP_BUFFER_TIME

	var jump_executed = false # Track if jump actually happens
	
	if jump_buffer_timer > 0 and not is_attacking:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0
			jump_buffer_timer = 0
			is_jumping = true
			sfx_jump.play()
			jump_executed = true
		elif is_wall_sliding or is_wall_clinging:
			var wall_normal = get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
			velocity.y = WALL_JUMP_VELOCITY.y
			can_double_jump = true
			jump_buffer_timer = 0
			is_jumping = true
			is_wall_clinging = false
			sfx_jump.play()
			jump_executed = true
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			double_jumping = true
			can_double_jump = false
			jump_buffer_timer = 0
			is_jumping = true
			sfx_jump.play()
			jump_executed = true
	
	# Only vibrate if jump was actually executed
	if jump_executed:
		Input.start_joy_vibration(0, 0.05, 0.1, 0.05)
	
	if Input.is_action_just_released("jump"):
		if velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER

	if velocity.y >= 0 or is_on_floor():
		is_jumping = false
	
	var move_input := Input.get_axis("move_left", "move_right")
	# Don't update facing direction while wall clinging
	if not is_wall_clinging and (input_type == InputType.CONTROLLER or mouse_aim_lock_timer <= 0.0):
		if move_input > 0.1:
			facing_direction = 1
		elif move_input < -0.1:
			facing_direction = -1

	if is_attacking:
		velocity.x = 0
	elif is_dashing:
		if dash_direction == 2:  # Down dash
			velocity.x = 0
			velocity.y = DASH_SPEED
		elif dash_direction == 3:  # Up dash
			velocity.x = 0
			velocity.y = -DASH_SPEED
		else:  # Horizontal dash
			velocity.x = dash_direction * DASH_SPEED
			velocity.y = 0
	elif is_rolling:
		velocity.x = roll_direction * ROLL_SPEED
	elif is_wall_clinging:
		velocity.x = 0
	else:
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			var accel = GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
			velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		else:
			var friction = GROUND_FRICTION if is_on_floor() else AIR_FRICTION
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			
	# Store velocity before move_and_slide resets it
	var velocity_before_collision = velocity.y
	
	# Handle platform drop timer
	if platform_drop_timer > 0:
		platform_drop_timer -= delta
		set_collision_mask_value(6, false) # Keep collision disabled
		if platform_drop_timer <= 0:
			set_collision_mask_value(6, true) # Re-enable collision

	# Allow dropping through one-way platforms
	if is_on_floor() and Input.is_action_just_pressed("move_down"):
		# Check if we're standing on a one-way platform
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.name == "OneWayPlatforms":
				platform_drop_timer = 0.3 # Disable collision for 0.3 seconds
				set_collision_mask_value(6, false)
				break

	move_and_slide()
		
	# NEW: Ground collision vibration (landing detection)
	# Check if we just landed (wasn't on floor, now on floor) with significant downward velocity
	if is_on_floor() and not was_on_floor and velocity_before_collision > 100:
		# Scale vibration intensity based on fall speed (lighter than before)
		var intensity = clamp(velocity_before_collision / 1200.0, 0.08, 0.25)
		Input.start_joy_vibration(0, intensity, intensity * 1.1, 0.08)
	
	# Update floor state for next frame
	was_on_floor = is_on_floor()
	
	# MOVED: Call update_animations() from _process instead (see below)

# NEW: Add this to keep animations updating even when physics is paused
func _process(delta: float) -> void:
	if not is_dying:  # Don't override animations while dying
		update_animations()  # Ensures sprite animates during cinematic (e.g., idle)

func play_random_meow():
	if meow_sounds.size() > 0:
		var random_index = randi() % meow_sounds.size()
		sfx_meow.stream = meow_sounds[random_index]
		sfx_meow.play()

# NEW: Simplified directional attack function for right stick inputs
func perform_directional_attack(vertical_dir: float, horizontal_dir: int = 0):
	is_attacking = true
	var attack_rotation = 0.0
	var desired_dir := facing_direction
	
	# For horizontal attacks (left/right), set facing direction
	if horizontal_dir != 0:
		desired_dir = horizontal_dir
		facing_direction = desired_dir
		animated_sprite_2d.flip_h = facing_direction < 0
		hitbox.scale.x = _default_hitbox_scale_x * facing_direction
	else:
		# For vertical attacks, maintain current facing
		animated_sprite_2d.flip_h = facing_direction < 0
		hitbox.scale.x = _default_hitbox_scale_x * facing_direction
	
	# Always perform directional attack (with hop if on ground)
	if is_on_floor():
		velocity.y = HOP_VELOCITY
	
	# Determine rotation based on direction
	if abs(vertical_dir) > 0.1:
		# Vertical attack (up or down)
		if vertical_dir > 0:
			# Down attack
			attack_rotation = PI / 2.0
			if animated_sprite_2d.flip_h:
				attack_rotation = -PI / 2.0
		else:
			# Up attack
			attack_rotation = -PI / 2.0
			if animated_sprite_2d.flip_h:
				attack_rotation = PI / 2.0
	# else: horizontal attack - no rotation needed
	
	rotation = attack_rotation
	animated_sprite_2d.play("jump_attack")
	Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
	sfx_attack.play()
	
	await get_tree().create_timer(0.2).timeout
	
	if is_attacking:
		check_hitbox_collision("attack")

func perform_attack(anim_name: String):
	is_attacking = true
	var attack_rotation = 0.0
	var desired_dir := facing_direction
	
	var vertical_input = 0.0
	const MOUSE_VERTICAL_THRESHOLD = 50.0

	if input_type == InputType.KEYBOARD_MOUSE:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = mouse_pos - global_position
		
		desired_dir = 1 if direction_to_mouse.x >= 0 else -1
		
		if direction_to_mouse.y < -MOUSE_VERTICAL_THRESHOLD:
			vertical_input = -1.0
		elif direction_to_mouse.y > MOUSE_VERTICAL_THRESHOLD:
			vertical_input = 1.0
		
		mouse_aim_lock_timer = MOUSE_AIM_LOCK_DURATION

	else:
		var input_dir := Input.get_axis("move_left", "move_right")
		vertical_input = Input.get_axis("move_up", "move_down")

		if abs(input_dir) > 0.1:
			desired_dir = 1 if input_dir > 0 else -1
		else:
			if velocity.x > 10:
				desired_dir = 1
			elif velocity.x < -10:
				desired_dir = -1
	
	facing_direction = desired_dir
	animated_sprite_2d.flip_h = facing_direction < 0
	hitbox.scale.x = _default_hitbox_scale_x * facing_direction
	
	var is_directional_attack = not is_on_floor() or (is_on_floor() and abs(vertical_input) > 0.5)

	if is_directional_attack:
		if is_on_floor():
			velocity.y = HOP_VELOCITY
			
		if vertical_input > 0.5:
			attack_rotation = PI / 2.0
			if animated_sprite_2d.flip_h:
				attack_rotation = -PI / 2.0
		elif vertical_input < -0.5:
			attack_rotation = -PI / 2.0
			if animated_sprite_2d.flip_h:
				attack_rotation = PI / 2.0
				
		rotation = attack_rotation
		animated_sprite_2d.play("jump_attack")
		Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		sfx_attack.play()
		
	else:
		animated_sprite_2d.play(anim_name)
		
		if anim_name == "attack_heavy":
			sfx_attack.play()
			Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
			
			await get_tree().create_timer(0.6).timeout
			sfx_attack.play()
			Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		else:
			sfx_attack.play()
			Input.start_joy_vibration(0, 0.2, 0.4, 0.1)

	await get_tree().create_timer(0.2).timeout

	if is_attacking:
		check_hitbox_collision(anim_name)

func check_hitbox_collision(anim_type):
	var damage = DAMAGE_NORMAL
	if anim_type == "attack_heavy":
		damage = DAMAGE_HEAVY
	
	var bodies = hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage") and body != self:
			body.take_damage(damage, global_position)
			
			# Increment combo
			combo_count += 1
			combo_timer = COMBO_TIMEOUT
			update_combo_display()
			
			print("Hit enemy for ", damage, " damage! Combo: ", combo_count)
	
	# NEW: Check for projectiles (bones)
	var areas = hitbox.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("bone"):  # Or check area.name.contains("bone")
			area.queue_free()  # Destroy the bone
			# Optionally increment combo
			combo_count += 1
			combo_timer = COMBO_TIMEOUT
			update_combo_display()

func start_death():
	is_dying = true
	velocity = Vector2.ZERO
	rotation = 0.0  # Reset rotation in case player died while dashing/attacking
	is_attacking = false
	is_dashing = false
	is_rolling = false
	
	sfx_death.play()
	Input.start_joy_vibration(0, 1.0, 1.0, 1.0)
	animated_sprite_2d.play("death")
	
	await get_tree().create_timer(death_animation_duration).timeout
	respawn()

func _on_animation_finished():
	if is_dying and animated_sprite_2d.animation == "death":
		respawn()
	if animated_sprite_2d.animation == "take_damage":
		is_hurt = false  # NEW: release hurt state
	if is_attacking:
		is_attacking = false
		rotation = 0.0
	if is_dashing and animated_sprite_2d.animation == "dash":
		rotation = 0.0

func respawn():
	if is_game_over:
		lives_changed.emit(get_node("/root/GameManager").get_lives())
		return
	
	# Use GameManager's global lives system
	var game_manager = get_node("/root/GameManager")
	var has_lives_remaining = game_manager.lose_life()
	lives_changed.emit(game_manager.get_lives())
	
	if not has_lives_remaining:
		is_game_over = true
		velocity = Vector2.ZERO
		var timer = get_tree().create_timer(2.0)
		timer.pause_mode = Node.PROCESS_MODE_WHEN_PAUSED
		await timer.timeout
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
		return
	
	is_dying = false
	is_attacking = false
	health = max_health
	health_changed.emit(health, max_health)
	rotation = 0.0
	if spawn_point:
		global_position = spawn_point.global_position
		velocity = Vector2.ZERO
		is_dashing = false
		is_rolling = false
		is_wall_sliding = false
		is_wall_clinging = false
		is_jumping = false
		double_jumping = false
		can_double_jump = true
		dash_timer = 0.0
		dash_cooldown_timer = 0.0
		roll_timer = 0.0
		roll_cooldown_timer = 0.0
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		mouse_aim_lock_timer = 0.0
		was_on_floor = true

func update_animations():
	if is_dying:
		return
	if is_hurt:  # NEW: do not override hurt animation
		return

	if not is_dashing and not is_rolling and not is_attacking:
		if is_wall_clinging:
			var wall_normal = get_wall_normal()
			var vertical_input = Input.get_axis("move_up", "move_down")
			if vertical_input > 0:
				animated_sprite_2d.flip_h = wall_normal.x < 0
			else:
				animated_sprite_2d.flip_h = wall_normal.x > 0
		elif is_wall_sliding:
			var wall_normal = get_wall_normal()
			animated_sprite_2d.flip_h = wall_normal.x < 0
		elif input_type == InputType.CONTROLLER or mouse_aim_lock_timer <= 0.0:
			if velocity.x > 0:
				animated_sprite_2d.flip_h = false
			elif velocity.x < 0:
				animated_sprite_2d.flip_h = true

	if is_attacking:
		return

	if not is_attacking:
		hitbox.scale.x = _default_hitbox_scale_x * (-1 if animated_sprite_2d.flip_h else 1)

	if is_dashing:
		animated_sprite_2d.play("dash")
	elif is_rolling:
		animated_sprite_2d.play("roll")
	elif is_wall_clinging:
		var vertical_input = Input.get_axis("move_up", "move_down")
		if vertical_input < 0:
			animated_sprite_2d.play("ledge_grab_land")
		elif vertical_input > 0:
			animated_sprite_2d.play("wall_slide")
		else:
			animated_sprite_2d.play("ledge_grab_idle")
	elif is_wall_sliding:
		animated_sprite_2d.play("wall_slide")
	elif not is_on_floor():
		if double_jumping:
			animated_sprite_2d.play("double_jump")
		elif velocity.y < 0:
			animated_sprite_2d.play("jump")
		else:
			animated_sprite_2d.play("fall")
	else:
		if abs(velocity.x) < 10:
			animated_sprite_2d.play("idle")
		else:
			animated_sprite_2d.play("run")

func apply_knockback(knockback_velocity: Vector2):
	"""Apply knockback force to the player"""
	if is_dashing or is_rolling:
		# Reduce knockback during dash/roll
		velocity = knockback_velocity * 0.3
	else:
		velocity = knockback_velocity
		# Add slight upward force if on ground
		if is_on_floor():
			velocity.y = min(velocity.y, -100)

func take_damage(amount: int):
	if invincible or is_dying or is_dashing or is_rolling:
		return
	sfx_hurt.play()
	Input.start_joy_vibration(0, 0.5, 0.8, 0.3)
	health -= amount
	reset_combo()
	health = max(health, 0)
	health_changed.emit(health, max_health)
	regen_delay_timer = REGEN_DELAY_TIME
	if regen_timer_bar:
		regen_timer_bar.value = REGEN_DELAY_TIME
		regen_timer_bar.visible = true
	if health <= 0:
		start_death()
		return
	hit_stun_timer = hit_stun_time
	invincible = true
	is_hurt = true
	animated_sprite_2d.play("take_damage")
	velocity.x = -facing_direction * 150
	if not is_on_floor():
		velocity.y = 200
	await get_tree().create_timer(invincibility_time).timeout
	invincible = false
	# Allow animation to finish before clearing hurt (handled in _on_animation_finished)

func update_combo_display():
	if not combo_counter:
		return
	
	if combo_count > 0:
		combo_counter.text = str(combo_count) + "x"
		combo_counter.visible = true
		if combo_timer_bar:
			combo_timer_bar.visible = true
			combo_timer_bar.value = combo_timer
	else:
		combo_counter.visible = false
		if combo_timer_bar:
			combo_timer_bar.visible = false

func reset_combo():
	combo_count = 0
	combo_timer = 0.0
	update_combo_display()

func _on_hitbox_body_entered(body):
	pass

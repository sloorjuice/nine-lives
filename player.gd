extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = $Camera2D
@onready var hitbox: Area2D = $Hitbox
@onready var sfx_jump: AudioStreamPlayer2D = $SFX_Jump
@onready var sfx_attack: AudioStreamPlayer2D = $SFX_Attack
@onready var sfx_dash: AudioStreamPlayer2D = $SFX_Dash
@onready var sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt
@onready var sfx_death: AudioStreamPlayer2D = $SFX_Death

const SPEED = 240.0
const JUMP_VELOCITY = -380.0
const HOP_VELOCITY = -200.0 # New constant for the short hop during directional ground attack
const GROUND_ACCELERATION = 1200.0
const AIR_ACCELERATION = 1350.0
const GROUND_FRICTION = 500.0
const AIR_FRICTION = 400.0
const COYOTE_TIME = 0.15
const JUMP_BUFFER_TIME = 0.1
const JUMP_CUT_MULTIPLIER = 0.3
const DASH_SPEED = 250.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 1.5
const ROLL_SPEED = 300.0
const ROLL_DURATION = 0.4
const ROLL_COOLDOWN = 0.2
const WALL_CLIMB_SPEED = 100.0
const WALL_CLIMB_DOWN_SPEED = 80.0
const WALL_SLIDE_SPEED = 50.0
const WALL_JUMP_VELOCITY = Vector2(300, -280)

@export var death_threshold: float = 280.0
@export var kill_threshold: float = 400.0
@export var death_animation_duration: float = 0.5

const DAMAGE_NORMAL = 1
const DAMAGE_HEAVY = 3

# --- LIVES SYSTEM ---
const MAX_LIVES = 9
var lives := MAX_LIVES
signal lives_changed(new_lives: int)
signal health_changed(new_health: float, max_health: int)

# --- INPUT HANDLING ---
enum InputType { KEYBOARD_MOUSE, CONTROLLER }
var input_type := InputType.KEYBOARD_MOUSE # Default to KB/M

# NEW: Variables for managing the mouse aim lock
const MOUSE_AIM_LOCK_DURATION = 0.5 # Time (seconds) to lock facing direction after mouse-aimed attack
var mouse_aim_lock_timer = 0.0

var spawn_point: Node2D
var is_dying = false
var is_game_over = false # Prevent multiple game overs

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

var regen_rate := 0.2
# New constant for the 7-second delay
const REGEN_DELAY_TIME = 7.0
# New timer variable
var regen_delay_timer = 0.0

var invincible := false
var invincibility_time := 0.6

var hit_stun_time := 0.3
var hit_stun_timer := 0.0

var is_attacking = false

func _ready():
	add_to_group("player")
	spawn_point = get_tree().get_first_node_in_group("spawn_point")
	if spawn_point:
		global_position = spawn_point.global_position
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	_default_hitbox_scale_x = abs(hitbox.scale.x)
	
	# --- Emit initial lives count ---
	lives_changed.emit(lives)

# Listen for non-physics events to detect input type
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Controller input detected
		input_type = InputType.CONTROLLER
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		# Keyboard/Mouse input detected
		input_type = InputType.KEYBOARD_MOUSE

func _physics_process(delta: float) -> void:
	if regen_delay_timer > 0.0:
		regen_delay_timer -= delta
	
	# ONLY perform regeneration if the delay timer is finished (<= 0.0)
	if regen_delay_timer <= 0.0:
		# 1. Store the health value BEFORE regeneration
		var old_health = health
		
		# 2. Calculate the regenerated health once, ensuring it doesn't exceed max_health
		health = min(max_health, health + regen_rate * delta)
		
		# 3. Check if the health value actually changed
		if health != old_health:
			# If it changed, emit the signal to update the UI (Health Bar)
			health_changed.emit(health, max_health)

	# NEW: Decrement the aim lock timer
	if mouse_aim_lock_timer > 0.0:
		mouse_aim_lock_timer -= delta

	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		return
	
	# NEW: Stop all processing if game over
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

	if not is_attacking and not is_dashing and not is_rolling and not is_wall_clinging:
		if Input.is_action_just_pressed("attack"):
			perform_attack("attack")
		elif Input.is_action_just_pressed("attack_heavy") and is_on_floor():
			var vertical_input = Input.get_axis("move_up", "move_down")
			# Only allow heavy attack if there is no significant vertical input (up/down)
			if abs(vertical_input) < 0.5:
				perform_attack("attack_heavy")

	is_wall_sliding = false
	is_wall_clinging = false

	if is_on_wall() and not is_on_floor() and not is_attacking:
		if Input.is_action_pressed("wall_cling"):
			is_wall_clinging = true
			can_double_jump = true
			var vertical_input = Input.get_axis("move_up", "move_down")
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
			var check_offset = Vector2(-wall_normal.x * 10, -20)
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + check_offset)
			var result = space_state.intersect_ray(query)
			if not result:
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
	
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if dash_cooldown_timer > 0: dash_cooldown_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0: is_dashing = false
	
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and not is_rolling and not is_attacking:
		sfx_dash.play()
		Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		
		# --- Calculate Dash Direction based on current input/velocity ---
		var dash_input_dir := Input.get_axis("move_left", "move_right")
		var intended_dir := facing_direction 

		if abs(dash_input_dir) > 0.1:
			# 1. Prioritize directional input
			intended_dir = 1 if dash_input_dir > 0 else -1
		elif abs(velocity.x) > 10:
			# 2. Fallback to current movement direction
			intended_dir = 1 if velocity.x > 0 else -1
		# 3. If standing still, use current facing_direction (default)

		dash_direction = intended_dir
		# Update visual facing direction immediately
		facing_direction = intended_dir
		animated_sprite_2d.flip_h = facing_direction < 0
		# --- END DASH DIRECTION ---
		
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
	
	if roll_cooldown_timer > 0: roll_cooldown_timer -= delta
	if roll_timer > 0:
		roll_timer -= delta
		if roll_timer <= 0: is_rolling = false
			
	if Input.is_action_just_pressed("roll") and roll_cooldown_timer <= 0 and not is_rolling and is_on_floor() and not is_attacking:
		sfx_dash.play()
		Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		
		# --- Calculate Roll Direction based on current input/velocity ---
		var roll_input_dir := Input.get_axis("move_left", "move_right")
		var intended_dir := facing_direction 

		if abs(roll_input_dir) > 0.1:
			# 1. Prioritize directional input
			intended_dir = 1 if roll_input_dir > 0 else -1
		elif abs(velocity.x) > 10:
			# 2. Fallback to current movement direction
			intended_dir = 1 if velocity.x > 0 else -1
		# 3. If standing still, use current facing_direction (default)

		roll_direction = intended_dir
		# Update visual facing direction immediately
		facing_direction = intended_dir
		animated_sprite_2d.flip_h = facing_direction < 0
		# --- END ROLL DIRECTION ---
		
		is_rolling = true
		roll_timer = ROLL_DURATION
		roll_cooldown_timer = ROLL_COOLDOWN
	
	if not is_on_floor() and not is_dashing:
		if is_attacking:
			# Lock velocity in place during air attack animation
			velocity.y = 0
			velocity.x = 0
		elif is_wall_clinging:
			pass
		elif is_wall_sliding:
			velocity += get_gravity() * delta * 0.3
		else:
			velocity += get_gravity() * delta
			
	if Input.is_action_just_pressed("jump") and not is_attacking:
		Input.start_joy_vibration(0,0.05,0.1,0.05)
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0 and not is_attacking:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0
			jump_buffer_timer = 0
			is_jumping = true
			sfx_jump.play()
		elif is_wall_sliding or is_wall_clinging:
			var wall_normal = get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
			velocity.y = WALL_JUMP_VELOCITY.y
			can_double_jump = true
			jump_buffer_timer = 0
			is_jumping = true
			is_wall_clinging = false
			sfx_jump.play()
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			double_jumping = true
			can_double_jump = false
			jump_buffer_timer = 0
			is_jumping = true
			sfx_jump.play()
	
	if Input.is_action_just_released("jump"):
		if velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER

	if velocity.y >= 0 or is_on_floor():
		is_jumping = false
	
	# Only update facing_direction based on movement input if we are on a controller
	# OR if the mouse aim lock has expired (allowing movement to change direction)
	var move_input := Input.get_axis("move_left", "move_right")
	if input_type == InputType.CONTROLLER or mouse_aim_lock_timer <= 0.0: # UPDATED CONDITION
		if move_input > 0.1:
			facing_direction = 1
		elif move_input < -0.1:
			facing_direction = -1
	
	# When mouse aim lock is active, we prevent movement input from flipping the sprite.

	if is_attacking:
		velocity.x = 0
	elif is_dashing:
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
			
	move_and_slide()
	update_animations()

func perform_attack(anim_name: String):
	is_attacking = true
	var attack_rotation = 0.0 # Default rotation
	var desired_dir := facing_direction
	
	# Variable to hold the vertical input/direction, initialized to 0 (neutral)
	var vertical_input = 0.0
	# Vertical distance required for the mouse to trigger an up/down attack, preventing accidental input
	const MOUSE_VERTICAL_THRESHOLD = 50.0

	# --- 1. Determine Attack Direction (Mouse/KB vs. Controller) ---
	if input_type == InputType.KEYBOARD_MOUSE:
		# Calculate direction based on mouse position relative to player
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = mouse_pos - global_position
		
		# Horizontal direction (left/right flip)
		desired_dir = 1 if direction_to_mouse.x >= 0 else -1
		
		# Vertical direction (up/down attack)
		if direction_to_mouse.y < -MOUSE_VERTICAL_THRESHOLD:
			# Mouse is significantly above the player (Up attack)
			vertical_input = -1.0
		elif direction_to_mouse.y > MOUSE_VERTICAL_THRESHOLD:
			# Mouse is significantly below the player (Down attack)
			vertical_input = 1.0
		# Else: vertical_input remains 0.0 (horizontal attack)
		
		# NEW: Activate the aim lock timer
		mouse_aim_lock_timer = MOUSE_AIM_LOCK_DURATION

	else: # InputType.CONTROLLER
		# Use controller's directional input for both horizontal (for facing) and vertical (for directional attack)
		var input_dir := Input.get_axis("move_left", "move_right")
		vertical_input = Input.get_axis("move_up", "move_down") # Get vertical input from controller

		if abs(input_dir) > 0.1:
			desired_dir = 1 if input_dir > 0 else -1
		else:
			if velocity.x > 10:
				desired_dir = 1
			elif velocity.x < -10:
				desired_dir = -1
			# Fallback to facing_direction if static
	
	# --- 2. Apply Determined Direction ---
	facing_direction = desired_dir
	animated_sprite_2d.flip_h = facing_direction < 0
	hitbox.scale.x = _default_hitbox_scale_x * facing_direction
	
	# --- 3. Check for Directional Attack (Air or Ground) ---
	# Now, vertical_input is determined by either mouse position (KB/M) or joystick axis (Controller)
	var is_directional_attack = not is_on_floor() or (is_on_floor() and abs(vertical_input) > 0.5)

	if is_directional_attack:
		# 3a. If on ground, perform a small hop
		if is_on_floor():
			velocity.y = HOP_VELOCITY
			
		# 3b. Determine Rotation based on vertical input
		if vertical_input > 0.5:
			# Downward attack (spin/dive)
			attack_rotation = PI / 2.0
			if animated_sprite_2d.flip_h:
				attack_rotation = -PI / 2.0
		elif vertical_input < -0.5:
			# Upward attack (aerial spike)
			attack_rotation = -PI / 2.0
			if animated_sprite_2d.flip_h:
				attack_rotation = PI / 2.0
				
		# 3c. Apply rotation and play jump attack animation
		rotation = attack_rotation
		
		animated_sprite_2d.play("jump_attack")
		Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		sfx_attack.play()
		
	else:
		# 4. Standard Ground Attack (Horizontal or Heavy)
		animated_sprite_2d.play(anim_name)
		
		if anim_name == "attack_heavy":
			sfx_attack.play() # First sound
			Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
			
			# Wait a very short time and play again
			await get_tree().create_timer(0.6).timeout
			sfx_attack.play() # Second sound
			Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
		else:
			sfx_attack.play() # Single sound for normal attack
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
			# Damage calculation is simplified for directional attacks since they use the base damage type
			body.take_damage(damage, global_position)
			print("Hit enemy for ", damage, " damage!")

func start_death():
	is_dying = true
	velocity = Vector2.ZERO
	sfx_death.play()
	# Strong, sustained rumble for 1.0 seconds
	Input.start_joy_vibration(0, 1.0, 1.0, 1.0)
	animated_sprite_2d.play("death")
	await get_tree().create_timer(death_animation_duration).timeout
	respawn()

func _on_animation_finished():
	if is_dying and animated_sprite_2d.animation == "death":
		respawn()
	
	if is_attacking:
		is_attacking = false
		# Reset player rotation after the attack finishes
		rotation = 0.0

func respawn():
	# NEW: Prevent multiple game overs
	if is_game_over:
		return
	
	# --- LIVES LOGIC FIRST ---
	lives -= 1
	lives_changed.emit(lives)
	
	if lives <= 0:
		# Game Over - Wait 2 seconds before resetting the scene
		is_game_over = true
		velocity = Vector2.ZERO
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()
		return
	
	# Still have lives left - respawn normally
	is_dying = false
	is_attacking = false
	health = max_health
	health_changed.emit(health, max_health)
	# Reset rotation on respawn for safety
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
		# Reset the aim lock timer on respawn
		mouse_aim_lock_timer = 0.0

func update_animations():
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
		# Only allow movement velocity to flip the sprite if the mouse aim lock has expired
		elif input_type == InputType.CONTROLLER or mouse_aim_lock_timer <= 0.0: # UPDATED CONDITION
			if velocity.x > 0:
				animated_sprite_2d.flip_h = false
			elif velocity.x < 0:
				animated_sprite_2d.flip_h = true
		# Otherwise (Mouse aim lock is active), let the sprite direction be maintained by attack logic
		# based on the last mouse position.

	if is_attacking:
		return

	if not is_attacking:
		# Keep hitbox aligned with character facing direction when not attacking/rotating
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

func take_damage(amount: int):
	if invincible or is_dashing or is_rolling:
		return

	sfx_hurt.play()
	
	# Sharp, medium rumble for 0.3 seconds
	Input.start_joy_vibration(0, 0.5, 0.8, 0.3)
	
	health -= amount
	health = max(health, 0)

	health_changed.emit(health, max_health)
	
	regen_delay_timer = REGEN_DELAY_TIME

	if health <= 0:
		start_death()
		return

	hit_stun_timer = hit_stun_time
	invincible = true
	animated_sprite_2d.play("take_damage")

	velocity.x = -facing_direction * 150

	if not is_on_floor():
		velocity.y = 200

	await get_tree().create_timer(invincibility_time).timeout
	invincible = false


func _on_hitbox_body_entered(body):
	pass

extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = $Camera2D
# NEW: Reference the hitbox
@onready var hitbox: Area2D = $Hitbox

const SPEED = 240.0
const JUMP_VELOCITY = -380.0
const GROUND_ACCELERATION = 1200.0
const AIR_ACCELERATION = 1350.0
const GROUND_FRICTION = 500.0
const AIR_FRICTION = 400.0
const COYOTE_TIME = 0.15
const JUMP_BUFFER_TIME = 0.1
const JUMP_CUT_MULTIPLIER = 0.3
# Dash settings
const DASH_SPEED = 250.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 1.5
# Roll settings
const ROLL_SPEED = 300.0
const ROLL_DURATION = 0.4
const ROLL_COOLDOWN = 0.2
# Wall climb settings
const WALL_CLIMB_SPEED = 100.0
const WALL_CLIMB_DOWN_SPEED = 80.0
# Wall slide settings
const WALL_SLIDE_SPEED = 50.0
const WALL_JUMP_VELOCITY = Vector2(300, -280)

@export var death_threshold: float = 280.0
@export var kill_threshold: float = 400.0
@export var death_animation_duration: float = 0.5

# --- NEW COMBAT SETTINGS ---
const DAMAGE_NORMAL = 1
const DAMAGE_HEAVY = 3

var spawn_point: Node2D
var is_dying = false

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
var facing_direction := 1  # 1 = right, -1 = left
var _default_hitbox_scale_x := 1.0

var max_health := 5
var health := 5

var regen_rate := 0.2 # HP per second
var invincible := false
var invincibility_time := 0.6

var hit_stun_time := 0.3
var hit_stun_timer := 0.0

# --- NEW COMBAT STATE ---
var is_attacking = false

func _ready():
	add_to_group("player")
	spawn_point = get_tree().get_first_node_in_group("spawn_point")
	if spawn_point:
		global_position = spawn_point.global_position
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	# Record default hitbox X scale so flips are consistent regardless of current scale
	_default_hitbox_scale_x = abs(hitbox.scale.x)

func _physics_process(delta: float) -> void:
	# Passive healing
	health = min(max_health, health + regen_rate * delta)

	# Hit stun: player can’t act
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
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

	# --- NEW: ATTACK INPUT HANDLING ---
	# Attacking overrides walking
	if not is_attacking and not is_dashing and not is_rolling and not is_wall_clinging:

		# Light attack ALWAYS allowed
		if Input.is_action_just_pressed("attack"):
			perform_attack("attack")

		# Heavy attack ONLY allowed on the ground
		elif Input.is_action_just_pressed("attack_heavy") and is_on_floor():
			perform_attack("attack_heavy")


	# Wall sliding/clinging (Only if not attacking)
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

	# Ledge climb (unchanged)
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

	# Timers (unchanged)
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
	
	# Dash Input (Cannot dash while attacking)
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and not is_rolling and not is_attacking:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_direction = -1 if animated_sprite_2d.flip_h else 1
	
	if roll_cooldown_timer > 0: roll_cooldown_timer -= delta
	if roll_timer > 0:
		roll_timer -= delta
		if roll_timer <= 0: is_rolling = false
			
	# Roll Input (Cannot roll while attacking)
	if Input.is_action_just_pressed("roll") and roll_cooldown_timer <= 0 and not is_rolling and is_on_floor() and not is_attacking:
		is_rolling = true
		roll_timer = ROLL_DURATION
		roll_cooldown_timer = ROLL_COOLDOWN
		roll_direction = -1 if animated_sprite_2d.flip_h else 1
	
	# --- NEW: GRAVITY SUSPENSION ---
	# If we are attacking in the air, DO NOT apply gravity
	if not is_on_floor() and not is_dashing:
		if is_attacking:
			velocity.y = 0 # Freeze vertical movement
			velocity.x = 0 # Freeze horizontal movement
		elif is_wall_clinging:
			pass
		elif is_wall_sliding:
			velocity += get_gravity() * delta * 0.3
		else:
			velocity += get_gravity() * delta
			
	# Jump Logic (Cannot jump while attacking)
	if Input.is_action_just_pressed("jump") and not is_attacking:
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0 and not is_attacking:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0
			jump_buffer_timer = 0
			is_jumping = true
		elif is_wall_sliding or is_wall_clinging:
			var wall_normal = get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
			velocity.y = WALL_JUMP_VELOCITY.y
			can_double_jump = true
			jump_buffer_timer = 0
			is_jumping = true
			is_wall_clinging = false
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			double_jumping = true
			can_double_jump = false
			jump_buffer_timer = 0
			is_jumping = true
	
	if Input.is_action_just_released("jump"):
		if velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER

	if velocity.y >= 0 or is_on_floor():
		is_jumping = false
	
	var move_input := Input.get_axis("move_left", "move_right")
	# Update facing_direction robustly: prefer explicit input (with small deadzone),
	# otherwise keep previous facing_direction (or use velocity fallback below in perform_attack).
	if move_input > 0.1:
		facing_direction = 1
	elif move_input < -0.1:
		facing_direction = -1
	# else: do not change facing_direction here (we'll resolve final facing in perform_attack)

	
	# Movement Logic
	if is_attacking:
		# Stop moving while attacking (unless you want sliding attacks)
		velocity.x = 0
		# Velocity.y is already handled in gravity section
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

# --- NEW: ATTACK FUNCTIONS ---
func perform_attack(anim_name: String):
	is_attacking = true

	# --- determine desired attack direction (robust) ---
	# Prefer current player input, then velocity, then fall back to last facing_direction
	var input_dir := Input.get_axis("move_left", "move_right")
	var desired_dir := facing_direction

	if input_dir > 0.1:
		desired_dir = 1
	elif input_dir < -0.1:
		desired_dir = -1
	else:
		# if no input, use movement velocity as hint (use small threshold)
		if velocity.x > 10:
			desired_dir = 1
		elif velocity.x < -10:
			desired_dir = -1
		# else keep previous facing_direction

	# Apply final direction
	facing_direction = desired_dir
	animated_sprite_2d.flip_h = facing_direction < 0
	# Use recorded default hitbox scale to reliably flip the hitbox
	hitbox.scale.x = _default_hitbox_scale_x * facing_direction

	# Play proper attack animation
	if not is_on_floor():
		animated_sprite_2d.play("jump_attack")
	else:
		animated_sprite_2d.play(anim_name)

	# optional: small hitstop or slight delay can be added here
	await get_tree().create_timer(0.2).timeout

	# Ensure still attacking before dealing damage
	if is_attacking:
		check_hitbox_collision(anim_name)


func check_hitbox_collision(anim_type):
	var damage = DAMAGE_NORMAL
	if anim_type == "attack_heavy":
		damage = DAMAGE_HEAVY
	
	var bodies = hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage") and body != self:
			# --- CHANGE IS HERE ---
			# Pass 'global_position' so the skeleton knows where the hit came from
			body.take_damage(damage, global_position) 
			print("Hit enemy for ", damage, " damage!")

func start_death():
	is_dying = true
	velocity = Vector2.ZERO
	animated_sprite_2d.play("death")
	await get_tree().create_timer(death_animation_duration).timeout
	respawn()

func _on_animation_finished():
	if is_dying and animated_sprite_2d.animation == "death":
		respawn()
	
	# --- NEW: End attack when animation finishes ---
	if is_attacking:
		is_attacking = false

func respawn():
	is_dying = false
	is_attacking = false # Reset attack
	health = max_health  # --- NEW: Reset health ---
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

func update_animations():
	# ---------------------------------------------------------
	# SPRITE FLIP (but ONLY when not attacking)
	# ---------------------------------------------------------
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
		elif velocity.x > 0:
			animated_sprite_2d.flip_h = false
		elif velocity.x < 0:
			animated_sprite_2d.flip_h = true

	# ---------------------------------------------------------
	# STOP RIGHT HERE IF WE ARE ATTACKING
	# Prevents animation system from overriding attack direction
	# ---------------------------------------------------------
	if is_attacking:
		return

	# ---------------------------------------------------------
	# HITBOX FLIP — only when NOT attacking
	# (Attack function sets this manually)
	# ---------------------------------------------------------
	# Only flip hitbox if NOT attacking
	if not is_attacking:
		hitbox.scale.x = -1 if animated_sprite_2d.flip_h else 1

	# ---------------------------------------------------------
	# PLAY ANIMATIONS
	# ---------------------------------------------------------
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
	# --- NEW: Check for invulnerability from dash/roll ---
	if invincible or is_dashing or is_rolling:
		return

	health -= amount
	health = max(health, 0)

	# --- NEW: Check for death ---
	if health <= 0:
		start_death()
		return

	# Knock the player into a "hurt" state
	hit_stun_timer = hit_stun_time
	invincible = true
	$AnimatedSprite2D.play("take_damage")

	# Apply a small knockback effect
	velocity.x = -facing_direction * 150  

	# If in the air, force them downward
	if not is_on_floor():
		velocity.y = 200

	# Turn off invincibility later
	await get_tree().create_timer(invincibility_time).timeout
	invincible = false

func _on_hitbox_body_entered(body):
	pass # We handle damage manually in check_hitbox_collision

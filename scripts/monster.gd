extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $Hitbox
@onready var attack_timer: Timer = $AttackTimer
@onready var sfx_attack: AudioStreamPlayer2D = $SFX_Attack
@onready var sfx_die: AudioStreamPlayer2D = $SFX_Die
@onready var sfx_wakeup: AudioStreamPlayer2D = $SFX_Wakeup
@onready var sfx_hurt: AudioStreamPlayer2D = $SFX_Hurt

var hitbox_default_position: Vector2

# --- CONFIGURATION ---
const MAX_SPEED = 130.0        
# TURN_SPEED: Lower = wider, smoother turns. Higher = snappier tracking.
const TURN_SPEED = 2.5          

const ATTACK_SPEED = 300.0 
const RETREAT_RANGE = 400.0
const ATTACK_RANGE = 70.0  
const ATTACK_CHARGE_TIME = 0.4 
const ATTACK_DURATION = 0.6    
const ATTACK_COOLDOWN = 0.5
const DAMAGE_AMOUNT = 1        
const PLAYER_KNOCKBACK_FORCE = 400.0
const MONSTER_STUN_TIME = 1.0  
const MONSTER_RECOIL_FORCE = 450.0 

enum State { IDLE, ACTIVE, ATTACKING, CHARGING, HURT, RECOIL }
var current_state = State.IDLE
var player: CharacterBody2D = null
var health = 2
var charge_target_position = Vector2.ZERO

func _ready():
	add_to_group("enemies")
	animated_sprite_2d.play("idle")
	
	if hitbox:
		hitbox_default_position = hitbox.position
		hitbox.monitoring = false 
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.wait_time = ATTACK_COOLDOWN
	add_child(attack_timer)
	
	if not detection_area.body_entered.is_connected(_on_detection_area_entered):
		detection_area.body_entered.connect(_on_detection_area_entered)
	if not detection_area.body_exited.is_connected(_on_detection_area_exited):
		detection_area.body_exited.connect(_on_detection_area_exited)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			# Very slow, drifting stop
			velocity = velocity.lerp(Vector2.ZERO, delta * 1.5)
			play_anim("idle")
			# Slowly correct rotation back to 0
			rotation = lerp(rotation, 0.0, delta * 2.0)
		
		State.ACTIVE:
			handle_active_state(delta)
		
		State.CHARGING:
			# Drift to a stop while winding up (feels heavier)
			velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
			play_anim("idle") 
			rotation = lerp(rotation, 0.0, delta * 5.0)
		
		State.ATTACKING:
			handle_attack_state()
			check_direct_collision_damage()
		
		State.HURT:
			# Slide back from knockback
			velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
			play_anim("hurt")
			rotation = 0 
			
		State.RECOIL:
			velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
			play_anim("fly") 

	move_and_slide()

func handle_active_state(delta):
	if not player:
		current_state = State.IDLE
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	if dist > RETREAT_RANGE:
		retreat()
		return

	# --- VISUALS ---
	if player.global_position.x < global_position.x:
		animated_sprite_2d.flip_h = true
		if hitbox: hitbox.position.x = -abs(hitbox_default_position.x)
	else:
		animated_sprite_2d.flip_h = false
		if hitbox: hitbox.position.x = abs(hitbox_default_position.x)
	
	play_anim("fly")
	
	# --- SMOOTH MOVEMENT (The Fix) ---
	var dir = (player.global_position - global_position).normalized()
	var target_velocity = dir * MAX_SPEED
	
	# using 'lerp' instead of 'move_toward' creates a curve.
	# It turns slowly at first, then speeds up, and slows down as it arrives.
	velocity = velocity.lerp(target_velocity, delta * TURN_SPEED)
	
	# --- SMOOTH TILT ---
	# Calculate tilt based on how much we are moving Up or Down
	# Clamped so he doesn't go full upside down
	var target_rotation = clamp(velocity.y * 0.001, -0.3, 0.3)
	
	if animated_sprite_2d.flip_h:
		target_rotation = -target_rotation
		
	# Lower number (0.05) means very heavy, slow rotation
	rotation = lerp(rotation, target_rotation, 0.05)
	
	# --- ATTACK CHECK ---
	if dist <= ATTACK_RANGE and attack_timer.is_stopped():
		start_charge_sequence()

func start_charge_sequence():
	if current_state != State.ACTIVE: return
	
	current_state = State.CHARGING
	sfx_attack.play()
	
	await get_tree().create_timer(ATTACK_CHARGE_TIME).timeout
	
	if current_state == State.CHARGING and player:
		start_attack_dash()
	elif current_state == State.CHARGING:
		current_state = State.ACTIVE

func start_attack_dash():
	current_state = State.ATTACKING
	rotation = 0 # Snappy reset for the dash
	
	# Predict slightly where the player is going
	var dir = (player.global_position - global_position).normalized()
	charge_target_position = player.global_position + (dir * 60)
	
	if hitbox: hitbox.monitoring = true
	
	await get_tree().create_timer(ATTACK_DURATION).timeout
	
	if current_state == State.ATTACKING:
		finish_attack()

func handle_attack_state():
	# Dash is linear and snappy (contrast to the floaty movement)
	var dir = (charge_target_position - global_position).normalized()
	velocity = dir * ATTACK_SPEED
	play_anim("fly")

func finish_attack():
	if hitbox: hitbox.monitoring = false
	current_state = State.ACTIVE
	attack_timer.start()

# --- COLLISION & DAMAGE LOGIC ---

func _on_hitbox_body_entered(body):
	if current_state == State.ATTACKING:
		if body.is_in_group("player"):
			deal_damage_to_player(body)

func check_direct_collision_damage():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			deal_damage_to_player(collider)
			break

func deal_damage_to_player(target):
	if target.has_method("take_damage"):
		
		var knock_dir = (target.global_position - global_position).normalized()
		if target.has_method("apply_knockback"):
			target.apply_knockback(knock_dir * PLAYER_KNOCKBACK_FORCE)
		target.take_damage(DAMAGE_AMOUNT)
		
		velocity = -knock_dir * MONSTER_RECOIL_FORCE
		
		current_state = State.RECOIL
		if hitbox: hitbox.monitoring = false
		
		await get_tree().create_timer(0.4).timeout
		
		if current_state == State.RECOIL:
			finish_attack()

# --- GETTING HIT LOGIC ---

func take_damage(amount, attacker_pos = null):
	if health <= 0: return
	
	health -= amount
	if health <= 0:
		die()
		return
	
	current_state = State.HURT
	sfx_hurt.play()
	rotation = 0 # Reset tilt
	if hitbox: hitbox.monitoring = false 
	
	if attacker_pos:
		var knock_dir = (global_position - attacker_pos).normalized()
		velocity = knock_dir * 250 
	
	await get_tree().create_timer(MONSTER_STUN_TIME).timeout
	
	if health > 0 and current_state == State.HURT:
		current_state = State.ACTIVE
		attack_timer.start() 

func retreat():
	current_state = State.IDLE
	player = null
	if hitbox: hitbox.monitoring = false
	play_anim("idle")

func die():
	sfx_die.play()
	collision_shape_2d.set_deferred("disabled", true)
	set_physics_process(false)
	play_anim("die")
	await animated_sprite_2d.animation_finished
	queue_free()

func play_anim(anim):
	if animated_sprite_2d.animation != anim:
		animated_sprite_2d.play(anim)

func _on_detection_area_entered(body):
	if body.is_in_group("player"):
		player = body
		if current_state == State.IDLE:
			current_state = State.ACTIVE
			sfx_wakeup.play()

func _on_detection_area_exited(body):
	if body == player:
		if current_state != State.ATTACKING and current_state != State.CHARGING and current_state != State.RECOIL:
			var dist = global_position.distance_to(player.global_position)
			if dist > RETREAT_RANGE:
				retreat()

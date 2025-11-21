extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d_top: CollisionShape2D = $"CollisionShape2D Top"
@onready var collision_shape_2d_bottom: CollisionShape2D = $"CollisionShape2D Bottom"
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
@onready var edge_detector: RayCast2D = $EdgeDetector

const BONE_PROJECTILE = preload("res://scenes/bone.tscn") 

const SPEED = 30.0
const GRAVITY = 980.0
const ATTACK_RANGE = 30.0  
const RETREAT_RANGE = 400.0
const BONE_SPEED = 200.0
const ATTACK_COOLDOWN = 2.0

# --- CHANGED: Added HURT to the State List ---
enum State { BONE_PILE, WAKING_UP, ACTIVE, SHUTTING_DOWN, HURT }
var current_state = State.BONE_PILE
var player: CharacterBody2D = null
var direction = 1
var health = 2
var is_attacking = false

func _ready():
	add_to_group("skeletons")
	collision_shape_2d_top.disabled = false
	collision_shape_2d_bottom.disabled = false
	
	animated_sprite_2d.play("bone_pile")
	attack_timer.wait_time = ATTACK_COOLDOWN
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	if not detection_area.body_entered.is_connected(_on_detection_area_entered):
		detection_area.body_entered.connect(_on_detection_area_entered)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	match current_state:
		State.BONE_PILE:
			velocity.x = 0
		State.WAKING_UP:
			velocity.x = 0
		State.ACTIVE:
			handle_active_state()
		State.SHUTTING_DOWN:
			velocity.x = 0
		# --- NEW: Handle movement while hurting ---
		State.HURT:
			# Apply friction so he slides a bit if knocked back, then stops
			velocity.x = move_toward(velocity.x, 0, 10)

	move_and_slide()

func wake_up():
	if current_state != State.BONE_PILE:
		return
		
	current_state = State.WAKING_UP
	animated_sprite_2d.play("bone_pile_wakeup")
	
	await animated_sprite_2d.animation_finished
	
	current_state = State.ACTIVE
	attack_timer.start()

func handle_active_state():
	if not player or is_attacking:
		velocity.x = 0
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > RETREAT_RANGE:
		shut_down()
		return
	
	if player.global_position.x < global_position.x:
		direction = -1
		animated_sprite_2d.flip_h = true
	else:
		direction = 1
		animated_sprite_2d.flip_h = false
	
	edge_detector.position.x = direction * 12 
	edge_detector.force_raycast_update()
	
	var at_ledge = not edge_detector.is_colliding()
	var in_attack_range = distance_to_player <= ATTACK_RANGE
	
	if in_attack_range or at_ledge:
		velocity.x = 0
		if animated_sprite_2d.animation != "standing_idle":
			animated_sprite_2d.play("standing_idle")
	else:
		velocity.x = direction * SPEED
		if animated_sprite_2d.animation != "limping_movement":
			animated_sprite_2d.play("limping_movement")

func shut_down():
	if current_state == State.SHUTTING_DOWN: return
	current_state = State.SHUTTING_DOWN
	attack_timer.stop()
	velocity.x = 0
	player = null
	animated_sprite_2d.play("standing_idle")
	await get_tree().create_timer(0.5).timeout
	animated_sprite_2d.play_backwards("bone_pile_wakeup")
	await animated_sprite_2d.animation_finished
	current_state = State.BONE_PILE
	animated_sprite_2d.play("bone_pile")

func _on_attack_timer_timeout():
	if current_state == State.ACTIVE and player and not is_attacking:
		throw_bone()

func throw_bone():
	if not player: return
	is_attacking = true 
	velocity.x = 0
	animated_sprite_2d.play("bone_toss")
	await get_tree().create_timer(0.3).timeout
	
	# If we got hurt mid-throw, stop the projectile logic
	if current_state != State.ACTIVE:
		is_attacking = false
		return
		
	if not player:
		is_attacking = false
		return
	
	var bone = BONE_PROJECTILE.instantiate()
	get_parent().add_child(bone)
	bone.global_position = global_position + Vector2(direction * 20, -10)
	var bone_direction = (player.global_position - bone.global_position).normalized()
	bone.velocity = bone_direction * BONE_SPEED
	
	await animated_sprite_2d.animation_finished
	is_attacking = false

# --- NEW: Updated Take Damage Logic ---
# Note: I added an optional "attacker_pos" argument for knockback later if you want it
func take_damage(amount, attacker_pos = null):
	# If already dying, don't interrupt death
	if health <= 0: return
	
	health -= amount
	
	if health <= 0:
		die()
		return
	
	# 1. INTERRUPT EVERYTHING
	is_attacking = false # Stop the attack lock
	current_state = State.HURT # Switch state so physics ignores input
	attack_timer.stop() # Pause the attack timer so he doesn't attack immediately after
	
	# 2. Play Animation
	animated_sprite_2d.play("hurt")
	
	# 3. Optional: Simple Knockback
	# If we know where the attacker is, get pushed away
	if attacker_pos != null:
		var knockback_dir = sign(global_position.x - attacker_pos.x)
		velocity.x = knockback_dir * 100 # Small push
		velocity.y = -100 # Small hop
	
	# 4. Wait for hurt animation to finish
	await animated_sprite_2d.animation_finished
	
	# 5. Return to normal (if not dead)
	if health > 0:
		current_state = State.ACTIVE
		attack_timer.start() # Restart the attack timer

func die():
	collision_shape_2d_top.set_deferred("disabled", true)
	collision_shape_2d_bottom.set_deferred("disabled", true)
	attack_timer.stop()
	set_physics_process(false)
	animated_sprite_2d.play("crumbling_into_bone_pile")
	await animated_sprite_2d.animation_finished
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _on_detection_area_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player = body
		if current_state == State.BONE_PILE:
			wake_up()

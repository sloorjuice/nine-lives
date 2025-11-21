extends Area2D

@onready var animated_sprite = $AnimatedSprite2D

var velocity = Vector2.ZERO
const GRAVITY = 300.0  # Bones arc downward

func _ready():
	animated_sprite.play("spinning_bone")
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _physics_process(delta):
	# Apply gravity for arc
	velocity.y += GRAVITY * delta
	position += velocity * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(2)  # Changed from 4 to 2
		queue_free()
	# Destroy bone if it hits any solid object (walls, floors, etc.)
	elif body is TileMapLayer or body is StaticBody2D:
		queue_free()

func _on_screen_exited():
	queue_free()  # Clean up when off screen

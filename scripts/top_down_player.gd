extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


const SPEED = 50.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	# Animation logic
	if input_vector.y > 0:
		animated_sprite_2d.play("front")
	elif input_vector.y < 0:
		animated_sprite_2d.play("up")
	elif input_vector.x != 0:
		animated_sprite_2d.play("side")
		animated_sprite_2d.flip_h = input_vector.x < 0

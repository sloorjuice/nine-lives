extends Area2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@export var yarn_ball_value: int = 1

var collected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Detect player overlaps
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	add_to_group("collectibles")

func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body): return
	if collected: return
	if body.is_in_group("player"):
		collected = true
		set_deferred("monitoring", false) # stop further overlaps
		call_deferred("_collect")         # defer collection logic

func _collect() -> void:
	animated_sprite_2d.visible = false
	collision_shape_2d.set_deferred("disabled", true) # defer collision change
	var gm = get_node("/root/GameManager")
	gm.add_current_yarn(yarn_ball_value)
	print("[YarnBall] Collected! Current+%d (total=%d)" % [yarn_ball_value, gm.get_current_yarn()])
	Input.start_joy_vibration(0, 0.2, 0.4, 0.1)
	audio_stream_player_2d.play()
	await audio_stream_player_2d.finished
	queue_free()

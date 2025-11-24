extends Control

# Adjust these values to customize the effect
@export var sway_speed: float = 1.0
@export var sway_amount: float = 20.0
@export var vertical_sway_amount: float = 10.0

var time_passed: float = 0.0
var layers: Array[TextureRect] = []
var layer_speeds: Array[float] = []
var layer_offsets: Array[float] = []

func _ready():
	# Get all TextureRect children
	for child in get_children():
		if child is TextureRect:
			layers.append(child)
	
	# Create different speeds and offsets for each layer
	# Layers further back (first in array) move slower
	for i in range(layers.size()):
		var speed_multiplier = 1.0 - (i * 0.15) # Each layer 15% slower
		layer_speeds.append(speed_multiplier)
		layer_offsets.append(i * 1.2) # Offset timing so layers aren't synchronized

func _process(delta):
	time_passed += delta * sway_speed
	
	for i in range(layers.size()):
		var layer = layers[i]
		var speed = layer_speeds[i]
		var offset = layer_offsets[i]
		
		# Horizontal sway using sine wave
		var h_sway = sin(time_passed + offset) * sway_amount * speed
		
		# Vertical sway using cosine wave (different frequency for variety)
		var v_sway = cos(time_passed * 0.7 + offset) * vertical_sway_amount * speed
		
		# Apply the movement using offset properties for centered/anchored nodes
		layer.offset_left = h_sway
		layer.offset_top = v_sway
		layer.offset_right = h_sway
		layer.offset_bottom = v_sway

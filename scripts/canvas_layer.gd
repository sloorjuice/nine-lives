extends CanvasLayer

@export var parallax_strength: Array[float] = [0.005, 0.015, 0.03, 0.045, 0.06]
@export var smoothness: float = 0.12
@export var vertical_factor: float = 0.0   # set to 0.1–0.3 for subtle vertical parallax

@onready var camera: Camera2D = get_parent().get_node("Player/Camera2D")
@onready var layers: Array[TextureRect] = [$Sky, $FarTowers, $MidBuildings, $NearStuff, $Foreground]

func _process(delta: float) -> void:
	if camera == null:
		return

	var cam_x: float = camera.global_position.x
	var cam_y: float = camera.global_position.y

	var count: int = min(layers.size(), parallax_strength.size())

	for i: int in count:
		var layer: TextureRect = layers[i]
		var strength: float = parallax_strength[i]

		var target_x: float = -cam_x * strength
		var target_y: float = -cam_y * strength * vertical_factor

		layer.position.x = lerp(layer.position.x, target_x, smoothness)
		layer.position.y = lerp(layer.position.y, target_y, smoothness)

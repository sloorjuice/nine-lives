extends ColorRect

# Shader limits
const MAX_ENEMIES = 10

# Internal references (No @export needed)
var player: Node2D
var detection_area: Area2D

# Settings
var detection_radius: float = 800.0 # Match this to your DetectionArea radius
var door_radius: float = 1400.0     # NEW: Larger for door (sense from across level)

func _process(delta: float):
	# 1. Validation: Check if we have a player. If not, try to find one.
	if not is_instance_valid(player):
		find_player_references()
		# If we still don't have a player, hide the effect and wait for next frame
		visible = false
		return
	
	visible = true
	
	# 2. Get Enemies (only overlapping detection area)
	var enemies = detection_area.get_overlapping_bodies()
	var threats: Array[Node2D] = []
	
	for body in enemies:
		# Only add actual enemies (ignores door even if overlapping)
		if is_instance_valid(body) and body.is_in_group("enemies"):
			threats.append(body)
	
	# 3. NEW: Add Door if unlocked/open (global search - works from anywhere!)
	var door = get_tree().get_first_node_in_group("exit_door")
	if is_instance_valid(door):
		threats.append(door)
	
	# 4. Sort ALL threats by distance (closest = highest priority)
	threats.sort_custom(func(a, b):
		return player.global_position.distance_squared_to(a.global_position) < \
			   player.global_position.distance_squared_to(b.global_position)
	)
	
	# 5. Prepare Data for Shader (top MAX_ENEMIES only)
	var enemy_vectors: Array[Vector2] = []
	var enemy_intensities: Array[float] = []
	var count = min(threats.size(), MAX_ENEMIES)
	
	for i in range(count):
		var threat = threats[i]
		var diff = threat.global_position - player.global_position
		var dist = diff.length()
		
		# Direction Vector (normalized)
		enemy_vectors.append(diff.normalized())
		
		# Intensity: DIFFERENT for Door vs Enemies!
		var intensity: float
		if threat.is_in_group("exit_door"):
			# DOOR: Slower falloff → visible even from far (faint red arc on edge)
			intensity = 1.0 - clamp(dist / door_radius, 0.0, 1.0)
			intensity = pow(intensity, 0.7)  # Keeps ~30% intensity at max range
			intensity *= 0.9  # Slightly less than close enemy (not "urgent")
		else:
			# ENEMIES: Sharp falloff (only close ones glow bright)
			intensity = 1.0 - clamp(dist / detection_radius, 0.0, 1.0)
			intensity = pow(intensity, 2.0) 
		
		enemy_intensities.append(intensity)

	# Pad the arrays to match MAX_ENEMIES (Shader requirement)
	while enemy_vectors.size() < MAX_ENEMIES:
		enemy_vectors.append(Vector2.ZERO)
		enemy_intensities.append(0.0)

	# 6. Send to Shader
	var mat = material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enemy_count", count)
		mat.set_shader_parameter("enemy_angles", enemy_vectors)
		mat.set_shader_parameter("enemy_intensities", enemy_intensities)

func find_player_references():
	# Look for the player in the "player" group
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Try to find the DetectionArea child
		if player.has_node("DetectionArea"):
			detection_area = player.get_node("DetectionArea")
		else:
			# Fallback if named differently
			print_debug("EnemySenses: Player found, but could not find 'DetectionArea' child node.")

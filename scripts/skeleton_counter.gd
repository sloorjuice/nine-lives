extends CanvasLayer

# --- NEW: Define the signal the door will listen for ---
signal all_enemies_dead

@onready var label: Label = $SkeletonCounter

var total_initial := 0
var min_monster_kills := 0
var monsters_killed := 0
const ENEMY_GROUP = "enemies"
var scene_queued = false # Prevent running the signal/scene change multiple times

func _ready():
	# Make sure other nodes (like the Door) can find this counter
	add_to_group("enemy_counter")
	
	# Wait until everything in the scene tree is fully ready
	await get_tree().process_frame
	total_initial = get_tree().get_nodes_in_group(ENEMY_GROUP).size()
	
	# Get the required monster kills from the door
	var door_node = get_tree().get_first_node_in_group("exit_door")
	if door_node:
		min_monster_kills = door_node.REQUIRED_MONSTER_KILLS
	else:
		min_monster_kills = total_initial # Default fallback
	
	# If there are enemies, start displaying the count
	if total_initial > 0:
		update_label()


func _process(delta):
	# Using _process for this is fine for simple enemy counting.
	update_label()

func _on_enemy_died():
	monsters_killed += 1

func update_label():
	var alive_count = get_tree().get_nodes_in_group(ENEMY_GROUP).size()
	monsters_killed = total_initial - alive_count
	
	# Display remaining kills needed
	var remaining = max(0, min_monster_kills - monsters_killed)
	label.text = "%d/%d" % [remaining, min_monster_kills]

	# Check for completion
	if monsters_killed >= min_monster_kills and not scene_queued:
		# --- START CINEMATIC: PAUSE THE GAME ---
		get_tree().paused = true 
		
		# Emit the signal to unlock the door
		all_enemies_dead.emit() 
		scene_queued = true # Mark as done to prevent repeated signals

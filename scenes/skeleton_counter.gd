extends CanvasLayer

# --- NEW: Define the signal the door will listen for ---
signal all_enemies_dead

@onready var label: Label = $SkeletonCounter

var total_initial := 0
const ENEMY_GROUP = "enemies"
var scene_queued = false # Prevent running the signal/scene change multiple times

func _ready():
	# Make sure other nodes (like the Door) can find this counter
	add_to_group("enemy_counter")
	
	# Wait until everything in the scene tree is fully ready
	await get_tree().process_frame
	total_initial = get_tree().get_nodes_in_group(ENEMY_GROUP).size()
	
	# If there are enemies, start displaying the count
	if total_initial > 0:
		update_label()


func _process(delta):
	# Using _process for this is fine for simple enemy counting.
	update_label()

func update_label():
	var alive_count = get_tree().get_nodes_in_group(ENEMY_GROUP).size()
	
	# Only update the label if the count is still changing
	label.text = "%d/%d" % [alive_count, total_initial]

	# Check for completion
	if alive_count <= 0 and total_initial > 0 and not scene_queued:
		# --- START CINEMATIC: PAUSE THE GAME ---
		get_tree().paused = true 
		
		# Emit the signal to unlock the door
		all_enemies_dead.emit() 
		scene_queued = true # Mark as done to prevent repeated signals

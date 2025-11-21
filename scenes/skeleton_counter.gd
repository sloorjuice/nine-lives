extends CanvasLayer

@onready var label: Label = $SkeletonCounter

var total_initial := 0
# Define the path to your next scene.
# IMPORTANT: You must replace "res://scenes/thanks_for_playing.tscn" with the actual path to your scene.
const NEXT_SCENE_PATH = "res://scenes/thanks_for_playing.tscn"

func _ready():
	# Count skeletons that exist when the scene starts
	total_initial = get_tree().get_nodes_in_group("skeletons").size()
	# Only call update_label if there are skeletons to track, otherwise the game might end instantly.
	if total_initial > 0:
		update_label()
	else:
		# If there were no skeletons initially, end the game.
		queue_next_scene()


func _process(delta):
	# Using _process for this is fine for simple enemy counting.
	# For larger games, you might use a signal on enemy death instead.
	update_label()

func update_label():
	var alive_count = get_tree().get_nodes_in_group("skeletons").size()
	
	label.text = "%d / %d" % [alive_count, total_initial]
	
	# --- WIN CONDITION CHECK ---
	if alive_count <= 0 and total_initial > 0:
		# All initial skeletons are gone, trigger the scene change
		queue_next_scene()
		
func queue_next_scene():
	# Use call_deferred to avoid changing the scene while in _process
	get_tree().call_deferred("change_scene_to_file", NEXT_SCENE_PATH)

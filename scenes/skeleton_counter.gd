extends CanvasLayer

@onready var label: Label = $SkeletonCounter

var total_initial := 0

func _ready():
	# Count skeletons that exist when the scene starts
	total_initial = get_tree().get_nodes_in_group("skeletons").size()
	update_label()

func _process(delta):
	update_label()

func update_label():
	var alive_count = get_tree().get_nodes_in_group("skeletons").size()
	label.text = "%d / %d" % [alive_count, total_initial]

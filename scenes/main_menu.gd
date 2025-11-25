class_name MainMenu
extends Control
@onready var play_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/PlayButton as Button
@onready var quit_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/QuitButton as Button
@export var start_level = preload("res://scenes/stage_one.tscn") as PackedScene

var using_controller := false

func on_start_up() -> void:
	get_tree().change_scene_to_packed(start_level)

func on_quit_up() -> void:
	get_tree().quit()
	
func _unhandled_input(event):
	# Detect controller
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if not using_controller:
			using_controller = true
			_on_controller_detected()

	# Detect mouse user and remove focus
	if event is InputEventMouseMotion:
		if using_controller:
			using_controller = false
			get_viewport().gui_release_focus()


func _on_controller_detected():
	play_button.grab_focus()

func _ready():
	# Disable the lowpass filter on the Music bus if present
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index >= 0 and AudioServer.get_bus_effect_count(music_bus_index) > 0:
		AudioServer.set_bus_effect_enabled(music_bus_index, 0, false)

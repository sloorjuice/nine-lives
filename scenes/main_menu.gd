class_name MainMenu
extends Control
@onready var play_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Button as Button
@onready var quit_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Button2 as Button
@export var start_level = preload("res://scenes/stage_one.tscn") as PackedScene

var using_controller := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_button.button_down.connect(on_start_down)
	quit_button.button_down.connect(on_quit_down)

func on_start_down() -> void:
	get_tree().change_scene_to_packed(start_level)

func on_quit_down() -> void:
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

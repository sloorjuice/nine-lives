extends Node2D

var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var music: AudioStreamPlayer = $BGM_Player

@export var pause_music_pitch_scale: float = 0.85
@export var pause_music_volume_db: float = -6.0

var _music_pitch_original := 1.0
var _music_volume_original := 0.0
var _music_bus_index := -1
var _has_lowpass := false

func _ready():
	set_process_input(true)
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if music:
		music.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_music_pitch_original = music.pitch_scale
		_music_volume_original = music.volume_db
		_music_bus_index = AudioServer.get_bus_index(music.bus)
		_has_lowpass = _music_bus_index >= 0 and AudioServer.get_bus_effect_count(_music_bus_index) > 0
		# Ensure filter is disabled at start
		if _has_lowpass:
			AudioServer.set_bus_effect_enabled(_music_bus_index, 0, false)
		# Ensure music is playing
		if not music.playing:
			music.play()

func _input(event):
	if event.is_action_pressed("pause"):
		set_game_paused(not get_tree().paused)

func set_game_paused(p: bool) -> void:
	get_tree().paused = p
	if p:
		apply_pause_audio()
		pause_menu.show()
	else:
		restore_audio()
		pause_menu.hide()

func apply_pause_audio():
	if music:
		music.pitch_scale = pause_music_pitch_scale
		music.volume_db = pause_music_volume_db
	if _has_lowpass:
		AudioServer.set_bus_effect_enabled(_music_bus_index, 0, true)

func restore_audio():
	if music:
		music.pitch_scale = _music_pitch_original
		music.volume_db = _music_volume_original
		if not music.playing:
			music.play()  # Resume music if stopped
	if _has_lowpass:
		AudioServer.set_bus_effect_enabled(_music_bus_index, 0, false)

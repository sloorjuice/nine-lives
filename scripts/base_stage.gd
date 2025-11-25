extends Node2D

var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@onready var pause_menu: Node = $PauseMenu
@onready var music: AudioStreamPlayer = $BGM_Player

@export var pause_music_pitch_scale: float = 0.85
@export var pause_music_volume_db: float = -6.0

var _music_pitch_original := 1.0
var _music_volume_original := 0.0
var _music_bus_index := -1
var _has_lowpass := false

func _ready():
	print("[BaseStage] =================================")
	print("[BaseStage] _ready() started")
	print("[BaseStage] GameManager.current_slot = ", GameManager.current_slot)
	print("[BaseStage] =================================")
	
	set_process_input(true)
	
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		if pause_menu.has_method("close_menu"):
			pause_menu.close_menu()
		else:
			pause_menu.visible = false
	
	if music:
		music.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_music_pitch_original = music.pitch_scale
		_music_volume_original = music.volume_db
		_music_bus_index = AudioServer.get_bus_index(music.bus)
		_has_lowpass = _music_bus_index >= 0 and AudioServer.get_bus_effect_count(_music_bus_index) > 0
		if _has_lowpass:
			AudioServer.set_bus_effect_enabled(_music_bus_index, 0, false)
		if not music.playing:
			music.play()
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[BaseStage] No player found!")
		return
	
	print("[BaseStage] _ready() finished")
	
	# THE FIX: Don't use await in _ready(), use call_deferred instead
	call_deferred("_deferred_save")

func _deferred_save():
	await get_tree().process_frame
	print("[BaseStage] Deferred save after frame | Slot:", GameManager.current_slot)
	save_current_progress()

func save_current_progress():
	var slot = GameManager.current_slot
	if slot <= 0:
		push_error("[BaseStage] ERROR: Invalid slot number: " + str(slot))
		return
	var current_scene = get_tree().current_scene
	if current_scene == null:
		push_warning("[BaseStage] Skip save (scene not ready).")
		return
	var path: String = current_scene.scene_file_path
	if path.is_empty() or not path.begins_with("res://scenes/"):
		push_warning("[BaseStage] Skip save (invalid scene path): " + str(path))
		return
	print("[BaseStage] Attempting save for slot: ", slot, " | Lives: ", GameManager.get_lives())
	SaveManager.save(slot, path, GameManager.get_lives())
	print("[BaseStage] Progress saved for slot %d" % slot)

func _input(event):
	if event.is_action_pressed("pause"):
		set_game_paused(not get_tree().paused)

func set_game_paused(p: bool) -> void:
	get_tree().paused = p
	if p:
		apply_pause_audio()
		if pause_menu.has_method("open_menu"):
			pause_menu.open_menu()
		else:
			pause_menu.show()
	else:
		restore_audio()
		if pause_menu.has_method("close_menu"):
			pause_menu.close_menu()
		else:
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
			music.play()
	if _has_lowpass:
		AudioServer.set_bus_effect_enabled(_music_bus_index, 0, false)

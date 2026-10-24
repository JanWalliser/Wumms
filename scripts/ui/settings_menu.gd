extends Control

var music_slider: HSlider
var waiting_action := ""
var binding_buttons: Dictionary = {}

# SettingsMenu - Audio, video, and gameplay preferences

@onready var master_slider: HSlider = $CenterContainer/Panel/VBoxContainer/MasterVolumeSlider
@onready var sfx_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SfxVolumeSlider
@onready var fullscreen_check: CheckBox = $CenterContainer/Panel/VBoxContainer/FullscreenCheck
@onready var back_button: Button = $TopBar/HBoxContainer/BackButton

func _ready() -> void:
	var labels = {"move_left":"Links","move_right":"Rechts","move_up":"Hoch","move_down":"Runter","ability_e":"Fähigkeit E","ability_r":"Ultimate R","toggle_auto_aim":"Auto-Zielen","pause_game":"Pause"}
	var box = $CenterContainer/Panel/VBoxContainer
	box.add_theme_constant_override("separation",8)
	var music_label = Label.new()
	music_label.text = "Musiklautstärke:"
	box.add_child(music_label)
	music_slider = HSlider.new()
	music_slider.value = AudioManager.music_volume*100
	box.add_child(music_slider)
	music_slider.value_changed.connect(func(value):
		AudioManager.music_volume = value/100
		_save_preferences())
	for action in ["move_left","move_right","move_up","move_down","ability_e","ability_r","toggle_auto_aim","pause_game"]:
		var button = Button.new()
		var events = InputMap.action_get_events(action)
		button.text = labels[action]+": "+(events[0].as_text().replace(" - Physical","") if not events.is_empty() else "unbelegt")
		button.pressed.connect(func():
			waiting_action = action
			button.text = "Neue Taste drücken … (Esc abbrechen)")
		binding_buttons[action] = button
		box.add_child(button)
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()

	master_slider.value = AudioManager.master_volume * 100.0
	sfx_slider.value = AudioManager.sfx_volume * 100.0
	fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)

	master_slider.value_changed.connect(func(val):
		AudioManager.master_volume = val / 100.0
		_save_preferences()
	)

	sfx_slider.value_changed.connect(func(val):
		AudioManager.sfx_volume = val / 100.0
		_save_preferences()
		AudioManager.play_sfx("coin")
	)

	fullscreen_check.toggled.connect(func(is_full):
		if is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_save_preferences()
	)

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _save_preferences() -> void:
	var file = ConfigFile.new()
	file.set_value("audio","master",AudioManager.master_volume)
	file.set_value("audio","sfx",AudioManager.sfx_volume)
	file.set_value("audio","music",AudioManager.music_volume)
	file.set_value("video","fullscreen",fullscreen_check.button_pressed)
	for action in binding_buttons:
		file.set_value("input",action,InputMap.action_get_events(action))
	file.save("user://settings.cfg")

func _input(event: InputEvent) -> void:
	if waiting_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_ESCAPE:
		InputMap.action_erase_events(waiting_action)
		var key = InputEventKey.new()
		key.physical_keycode = event.physical_keycode
		InputMap.action_add_event(waiting_action,key)
		binding_buttons[waiting_action].text = "Neue Belegung: "+key.as_text().replace(" - Physical","")
		_save_preferences()
	waiting_action = ""
	get_viewport().set_input_as_handled()

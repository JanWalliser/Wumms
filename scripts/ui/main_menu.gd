extends Control

# MainMenu - Main entry point for WUMMS: Operation Knall-Kartoffel

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var profile_btn: Button = $VBoxContainer/ProfileButton
@onready var upgrades_btn: Button = $VBoxContainer/UpgradesButton
@onready var characters_btn: Button = $VBoxContainer/CharactersButton
@onready var quests_btn: Button = $VBoxContainer/QuestsButton
@onready var stats_btn: Button = $VBoxContainer/StatsButton
@onready var settings_btn: Button = $VBoxContainer/SettingsButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	if NetworkManager.enabled: NetworkManager.leave()
	play_btn.pressed.connect(_on_play_pressed)
	profile_btn.pressed.connect(_on_profile_pressed)
	upgrades_btn.pressed.connect(_on_upgrades_pressed)
	characters_btn.pressed.connect(_on_characters_pressed)
	quests_btn.pressed.connect(_on_quests_pressed)
	stats_btn.pressed.connect(_on_stats_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	play_btn.grab_focus()
	var help = Label.new()
	help.text = "WASD/Pfeile: Bewegung · Automatische Waffen · E ab Stufe 3 · R ab Stufe 6 · C: Zielen · Esc: Pause\nGamepad: linker Stick / rechter Stick · A: E · B: R · RB: Zielen · Start: Pause"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -60
	add_child(help)

func _on_play_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

func _on_profile_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/profile_select.tscn")

func _on_upgrades_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func _on_characters_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_quests_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/quest_menu.tscn")

func _on_stats_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/stats_menu.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

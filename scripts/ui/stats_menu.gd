extends Control

# StatsMenu - Shows career statistics for the active player profile

@onready var stats_label: Label = $CenterContainer/Panel/VBoxContainer/StatsLabel
@onready var back_button: Button = $TopBar/HBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	_load_stats()

func _load_stats() -> void:
	var profile := SaveManager.load_profile(ProfileManager.player_slots[0]["profile_id"])
	var stats: Dictionary = profile.get("stats", {})

	var runs: int = int(stats.get("runs_played", 0))
	var wins: int = int(stats.get("runs_won", 0))
	var win_rate: float = (float(wins) / float(runs) * 100.0) if runs > 0 else 0.0
	var max_surv: float = float(stats.get("max_survival_time", 0.0))
	var mins := int(max_surv / 60.0)
	var secs := int(fmod(max_surv, 60.0))

	var text := "Profil: %s\n\n" % profile.get("name", "Spieler 1")
	text += "Gespielte Runden: %d\n" % runs
	text += "Gewonnene Runden: %d (Siegquote: %.1f%%)\n" % [wins, win_rate]
	text += "Besiegte Urviecher: %d\n" % int(stats.get("total_kills", 0))
	text += "Besiegte Ober-Obermacker: %d\n" % int(stats.get("total_boss_kills", 0))
	text += "Verursachter Gesamtschaden: %d\n" % int(stats.get("total_damage_dealt", 0.0))
	text += "Insgesamt erbeutete Dönerdublonen: %d\n" % int(stats.get("total_gold_earned", 0))
	text += "Entwickelte Waffen: %d\n" % int(stats.get("weapons_evolved", 0))
	text += "Maximale Überlebenszeit: %02d:%02d\n" % [mins, secs]

	stats_label.text = text

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

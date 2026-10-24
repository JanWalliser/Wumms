extends Control

# GameOverScreen - End-of-run summary displaying stats, victory/defeat, gold and unlocks

@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var stats_summary_label: Label = $CenterContainer/Panel/VBoxContainer/StatsSummaryLabel
@onready var return_button: Button = $CenterContainer/Panel/VBoxContainer/ReturnButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	var parent = stats_summary_label.get_parent()
	var place = stats_summary_label.get_index()
	parent.remove_child(stats_summary_label)
	var scroll = ScrollContainer.new()
	scroll.name = "ResultsScroll"
	parent.add_child(scroll)
	parent.move_child(scroll,place)
	scroll.add_child(stats_summary_label)
	stats_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CenterContainer/Panel.custom_minimum_size = Vector2.ZERO
	resized.connect(_layout_results)
	_layout_results()
	return_button.pressed.connect(_on_return_pressed)
	var retry = Button.new()
	retry.name = "RetrySave"
	retry.text = "Speichern erneut versuchen"
	retry.pressed.connect(func():
		if GameManager.retry_settlement(): retry.hide())
	$CenterContainer/Panel/VBoxContainer.add_child(retry)
	retry.hide()

func setup(is_victory: bool) -> void:
	return_button.disabled = false
	_layout_results()
	return_button.call_deferred("grab_focus")
	if is_victory:
		title_label.text = "SIEG! DIE URVIECHER WURDEN ZERSCHMETTERT!"
		title_label.modulate = Color(0.3, 1.0, 0.4)
		AudioManager.play_sfx("level_up", 1.2)
	else:
		title_label.text = "NIEDERLAGE! DIE KNALL-KARTOFFEL IST EXPLODIERT..."
		title_label.modulate = Color(1.0, 0.3, 0.3)
		AudioManager.play_sfx("death", 0.9)

	var mins := int(GameManager.game_time / 60.0)
	var secs := int(fmod(GameManager.game_time, 60.0))
	var gold_mult := float(GameManager.get_difficulty_multipliers().get("gold_mult", 1.0))
	var earned_gold = int(GameManager.final_result.get("gold",0))

	var text := "Überlebenszeit: %02d:%02d\n" % [mins, secs]
	text += "Besiegte Urviecher: %d\n" % GameManager.total_run_kills
	text += "Verursachter Gesamtschaden: %d\n" % int(GameManager.total_damage_dealt)
	text += "Erbeutete Dönerdublonen: %d (Multiplikator: %.2fx)\n\n" % [earned_gold, gold_mult]

	text += "ÜBUNGSRUN - kein Profilfortschritt\n" if GameManager.practice_mode else "--- SPIELER-STATISTIKEN ---\n"
	for p in GameManager.active_player_nodes:
		if is_instance_valid(p):
			text += "P%d (%s): Stufe %d | Ausgerüstete Waffen: %d | Passive: %d\n" % [
				p.player_slot_index + 1,
				p.char_data.get("display_name", ""),
				GameManager.team_level,
				p.weapon_controller.equipped_weapons.size() if p.weapon_controller else 0,
				p.passives.size()
			]

	if not GameManager.quest_notes.is_empty():
		text += "\nQuestbelohnungen zusätzlich zum Run-Gold:\n"
		for note in GameManager.quest_notes.values(): text += note+"\n"
	stats_summary_label.text = text
	$CenterContainer/Panel/VBoxContainer/RetrySave.visible = not GameManager.practice_mode and not GameManager.final_result.get("saved",false)

func _on_return_pressed() -> void:
	if return_button.disabled: return
	return_button.disabled = true
	# Leave the GUI callback before unpausing and freeing its current scene.
	call_deferred("_return_to_menu")

func _return_to_menu() -> void:
	if NetworkManager.is_client(): NetworkManager.leave()
	GameManager.return_to_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _layout_results() -> void:
	var available := get_viewport_rect().size
	var width := minf(900,available.x-64)
	var scroll := stats_summary_label.get_parent() as ScrollContainer
	if scroll:
		scroll.custom_minimum_size = Vector2(width,maxf(64,minf(450,available.y-250)))
		stats_summary_label.custom_minimum_size.x = maxf(100,width-28)
	title_label.add_theme_font_size_override("font_size",22 if available.x<1400 else 28)

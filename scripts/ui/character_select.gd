extends Control

# CharacterSelect - Full 9 character overview with stats, abilities and unlock requirements

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var back_button: Button = $TopBar/HBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	_build_characters()

func _build_characters() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var char_ids := CharacterRegistry.get_all_character_ids()
	var profile := SaveManager.load_profile(ProfileManager.player_slots[0]["profile_id"])
	var unlocked_chars: Array = profile.get("unlocked_characters", ["jankz"])

	for c_id in char_ids:
		var c_data := CharacterRegistry.get_character_data(c_id)
		var is_unlocked := unlocked_chars.has(c_id)

		var card := _create_character_card(c_id, c_data, is_unlocked)
		grid_container.add_child(card)

func _create_character_card(c_id: String, c_data: Dictionary, is_unlocked: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 260)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = "%s (%s)" % [c_data.get("display_name", c_id), c_data.get("ref_name", "")]
	name_lbl.add_theme_font_size_override("font_size", 18)
	if not is_unlocked:
		name_lbl.text += " [GESPERRT]"
		name_lbl.modulate = Color(0.6, 0.6, 0.6)
	vb.add_child(name_lbl)

	var title_lbl := Label.new()
	title_lbl.text = c_data.get("title", "")
	title_lbl.modulate = Color(0.9, 0.8, 0.2)
	vb.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = c_data.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc_lbl)

	var pass_info: Dictionary = c_data.get("passive", {})
	var pass_lbl := Label.new()
	pass_lbl.text = "Passiv: %s - %s" % [pass_info.get("name", ""), pass_info.get("desc", "")]
	pass_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(pass_lbl)

	var e_info: Dictionary = c_data.get("ability_e", {})
	var e_lbl := Label.new()
	e_lbl.text = "E: %s - %s" % [e_info.get("name", ""), e_info.get("desc", "")]
	e_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(e_lbl)

	var r_info: Dictionary = c_data.get("ability_r", {})
	var r_lbl := Label.new()
	r_lbl.text = "R: %s - %s" % [r_info.get("name", ""), r_info.get("desc", "")]
	r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(r_lbl)

	if not is_unlocked:
		var requirement = Label.new()
		requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for quest in QuestManager.all_quests.values():
			if str(quest["reward_value"]).split(":").has(c_id): requirement.text = "Freischalten: " + quest["title"]
		vb.add_child(requirement)
	return panel

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

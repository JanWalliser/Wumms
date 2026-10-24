extends Control

# ProfileSelect - Profile management (create, select, delete)

@onready var profile_list: VBoxContainer = $ScrollContainer/ProfileList
@onready var new_name_input: LineEdit = $CreatePanel/HBoxContainer/NameInput
@onready var create_btn: Button = $CreatePanel/HBoxContainer/CreateButton
@onready var back_btn: Button = $TopBar/HBoxContainer/BackButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	back_btn.grab_focus()
	create_btn.pressed.connect(_on_create_pressed)
	_refresh_profiles()

func _refresh_profiles() -> void:
	for child in profile_list.get_children():
		child.queue_free()

	var p_ids := SaveManager.list_profile_ids()
	for p_id in p_ids:
		var data := SaveManager.load_profile(p_id)
		var item := _create_profile_item(p_id, data)
		profile_list.add_child(item)

func _create_profile_item(p_id: String, data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 70)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	panel.add_child(hb)

	var stats: Dictionary = data.get("stats", {})
	var info_lbl := Label.new()
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.text = "%s | Gold: %d | Runs: %d (Siege: %d)" % [
		data.get("name", p_id),
		int(data.get("gold", 0)),
		int(stats.get("runs_played", 0)),
		int(stats.get("runs_won", 0))
	]
	hb.add_child(info_lbl)

	var select_btn := Button.new()
	select_btn.text = "Als P1 Wählen"
	select_btn.pressed.connect(func():
		ProfileManager.set_player_profile(0, p_id)
		AudioManager.play_sfx("coin")
		_on_back_pressed()
	)
	hb.add_child(select_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Löschen"
	delete_btn.disabled = (SaveManager.list_profile_ids().size() <= 1)
	delete_btn.pressed.connect(func():
		if not SaveManager.delete_profile(p_id): return
		var remaining = SaveManager.list_profile_ids()
		for i in range(ProfileManager.player_slots.size()):
			if ProfileManager.player_slots[i]["profile_id"] == p_id and not remaining.is_empty():
				ProfileManager.set_player_profile(i,remaining[0])
		_refresh_profiles()
	)
	hb.add_child(delete_btn)

	return panel

func _on_create_pressed() -> void:
	var name_text := new_name_input.text.strip_edges()
	if name_text.is_empty():
		name_text = "Kartoffel-Rekrut"
	ProfileManager.create_new_profile(name_text)
	new_name_input.text = ""
	_refresh_profiles()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

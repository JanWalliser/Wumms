extends Control

# QuestMenu - Displays all Swarm 2024 objectives, progress, and unlock rewards

@onready var quest_list: VBoxContainer = $ScrollContainer/QuestList
@onready var back_button: Button = $TopBar/HBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	_build_quests_list()

func _build_quests_list() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	var profile := SaveManager.load_profile(ProfileManager.player_slots[0]["profile_id"])
	var completed: Array = profile.get("completed_quests", [])
	var progress: Dictionary = profile.get("quest_progress", {})

	for q_id in QuestManager.all_quests.keys():
		var q_data: Dictionary = QuestManager.all_quests[q_id]
		var is_done := completed.has(q_id)
		var current_val: float = float(progress.get(q_id, 0.0))
		var target_val: float = float(q_data.get("target", 1.0))

		var item := _create_quest_item(q_data, is_done, current_val, target_val)
		quest_list.add_child(item)

func _create_quest_item(q_data: Dictionary, is_done: bool, cur: float, target: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(750, 70)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	panel.add_child(hb)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.text = "%s: %s" % [q_data.get("title", ""), q_data.get("reward_desc", "")]
	if is_done:
		title_lbl.modulate = Color(0.4, 1.0, 0.4)
	hb.add_child(title_lbl)

	var status_lbl := Label.new()
	if is_done:
		status_lbl.text = "[ERLEDIGT]"
		status_lbl.modulate = Color(0.3, 1.0, 0.4)
	else:
		status_lbl.text = "%d / %d" % [int(cur), int(target)]
		status_lbl.modulate = Color(0.8, 0.8, 0.8)
	hb.add_child(status_lbl)

	return panel

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

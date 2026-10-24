extends Control

# Shop - Permanent meta-progression shop for Lobby upgrades

@onready var gold_label: Label = $TopBar/HBoxContainer/GoldLabel
@onready var profile_label: Label = $TopBar/HBoxContainer/ProfileLabel
@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var back_button: Button = $TopBar/HBoxContainer/BackButton

var active_profile_id: String = ""

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	# Default to Player 1 profile
	active_profile_id = ProfileManager.player_slots[0]["profile_id"]
	_refresh_shop()

func _refresh_shop() -> void:
	var profile := SaveManager.load_profile(active_profile_id)
	var gold: int = int(profile.get("gold", 0))
	gold_label.text = "Dönerdublonen: %d" % gold
	profile_label.text = "Profil: %s" % profile.get("name", active_profile_id)

	for child in grid_container.get_children():
		child.queue_free()

	var upgrades_dict: Dictionary = ShopUpgradeRegistry.upgrades
	var profile_upgrades: Dictionary = profile.get("shop_upgrades", {})

	for u_id in upgrades_dict.keys():
		var u_data: Dictionary = upgrades_dict[u_id]
		var cur_lvl: int = int(profile_upgrades.get(u_id, 0))
		var max_lvl: int = int(u_data.get("max_level", 5))
		var cost := ShopUpgradeRegistry.get_cost(u_id, cur_lvl)
		var is_unlocked := ShopUpgradeRegistry.is_unlocked_for_profile(u_id, profile)

		var card := _create_upgrade_card(u_id, u_data, cur_lvl, max_lvl, cost, gold, is_unlocked)
		grid_container.add_child(card)

func _create_upgrade_card(u_id: String, u_data: Dictionary, cur_lvl: int, max_lvl: int, cost: int, player_gold: int, is_unlocked: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 160)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = "%s (%s)" % [u_data.get("display_name", u_id), u_data.get("ref_name", "")]
	name_lbl.add_theme_font_size_override("font_size", 16)
	vb.add_child(name_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Stufe: %d / %d" % [cur_lvl, max_lvl]
	vb.add_child(lvl_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = u_data.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc_lbl)

	var buy_btn := Button.new()
	if not is_unlocked:
		buy_btn.text = "GESPERRT: "+preload("res://scripts/progression/warehouse_progression.gd").shop_hint(u_id)
		buy_btn.disabled = true
	elif cur_lvl >= max_lvl:
		buy_btn.text = "MAXIMALSTUFE"
		buy_btn.disabled = true
	else:
		buy_btn.text = "Kaufen: %d Gold" % cost
		buy_btn.disabled = (player_gold < cost)

		buy_btn.pressed.connect(func():
			_buy_upgrade(u_id, cost)
		)

	vb.add_child(buy_btn)
	return panel

func _buy_upgrade(u_id: String, _cost: int) -> void:
	if ProfileManager.buy_upgrade(active_profile_id,u_id): AudioManager.play_sfx("coin",1.2)
	_refresh_shop()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

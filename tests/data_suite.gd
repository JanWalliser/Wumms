extends Node

# TestRunner - Headless test runner executing automated test suites for WUMMS

const WeaponRegistry = preload("res://scripts/weapons/weapon_registry.gd")
const CharacterRegistry = preload("res://scripts/characters/character_registry.gd")
const PassiveRegistry = preload("res://scripts/passives/passive_registry.gd")
const AugmentRegistry = preload("res://scripts/augments/augment_registry.gd")
const ShopUpgradeRegistry = preload("res://scripts/upgrades/shop_upgrade_registry.gd")
const FortuneBonusRegistry = preload("res://scripts/bonuses/fortune_bonus_registry.gd")
const Flowfield = preload("res://scripts/ai/flowfield.gd")
const StatCalculator = preload("res://scripts/core/stat_calculator.gd")
const SaveManagerScript = preload("res://scripts/core/save_manager.gd")
const QuestManagerScript = preload("res://scripts/core/quest_manager.gd")

func _ready() -> void:
	print("\n=======================================================")
	print("  WUMMS: OPERATION KNALL-KARTOFFEL - TEST SUITE RUNNER")
	print("=======================================================\n")

	var passed := 0
	var failed := 0

	var tests := [
		"test_stats_calculation",
		"test_persistence_and_profiles",
		"test_weapon_definitions_and_evolutions",
		"test_character_registry",
		"test_passives_and_augments",
		"test_flowfield_pathfinding",
		"test_quest_manager",
		"test_scenes_instantiation",
		"test_pause_and_process_modes"
	]

	for t_name in tests:
		print("Running: %s..." % t_name)
		var ok: bool = call(t_name)
		if ok:
			print("  -> PASSED\n")
			passed += 1
		else:
			print("  -> FAILED!\n")
			failed += 1

	print("=======================================================")
	print("TEST RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("=======================================================\n")

	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_stats_calculation() -> bool:
	# 1. Cooldown calculation with Ability Haste
	var cd1 := StatCalculator.calculate_effective_cooldown(1.0, 0.0)
	if absf(cd1 - 1.0) > 0.001:
		printerr("Fail: 0 haste cooldown should be 1.0, got: ", cd1)
		return false

	var cd2 := StatCalculator.calculate_effective_cooldown(1.0, 100.0)
	if absf(cd2 - 0.5) > 0.001: # 1.0 / (1 + 100/100) = 0.5
		printerr("Fail: 100 haste cooldown should be 0.5, got: ", cd2)
		return false

	# 2. Armor mitigation
	var dmg0 := StatCalculator.calculate_armor_mitigation(100.0, 0.0)
	if absf(dmg0 - 100.0) > 0.001:
		printerr("Fail: 0 armor should mitigate 0%, got: ", dmg0)
		return false

	var dmg100 := StatCalculator.calculate_armor_mitigation(100.0, 100.0)
	if absf(dmg100 - 50.0) > 0.001: # 100 / (100 + 100) = 50%
		printerr("Fail: 100 armor should mitigate 50%, got: ", dmg100)
		return false

	# 3. Full player stats calculation with trade-off augment (Glass Cannon: +40% dmg, -40% HP)
	var base := {"max_health": 500.0, "movement_speed": 350.0}
	var shop := {"damage": 2} # +20% dmg
	var passives := {"damage": 1} # +10% dmg
	var augments := ["augment_glass_cannon"]
	var buffs := {}

	var stats := StatCalculator.compute_player_stats(base, shop, passives, augments, buffs)
	# Archived Glass Cannon: 500 * (1 - 0.30) = 350.
	if absf(stats["max_health"] - 350.0) > 1.0:
		printerr("Fail: Glass cannon HP should be 350, got: ", stats["max_health"])
		return false

	# Independent sources multiply: shop 1.2 * passive 1.1 * Glass Cannon 1.4.
	if absf(stats["damage_multiplier"] - 1.848) > 0.001:
		printerr("Fail: Damage multiplier should be 1.848, got: ", stats["damage_multiplier"])
		return false

	return true

func test_persistence_and_profiles() -> bool:
	var sm := SaveManagerScript.new()
	var test_id := "test_profile_qa"
	var default_data := sm.create_default_profile(test_id, "Test Pilot")
	default_data["gold"] = 1500

	# Test save
	var save_ok := sm.save_profile(default_data)
	if not save_ok:
		printerr("Fail: Save failed")
		return false

	# Test load
	var loaded := sm.load_profile(test_id)
	if loaded.is_empty() or loaded["name"] != "Test Pilot" or loaded["gold"] != 1500:
		printerr("Fail: Loaded data mismatch: ", loaded)
		return false

	# Test negative gold protection
	loaded["gold"] = -500
	sm.save_profile(loaded)
	var reloaded := sm.load_profile(test_id)
	if reloaded["gold"] < 0:
		printerr("Fail: Gold should not be negative: ", reloaded["gold"])
		return false

	# Clean up
	sm.delete_profile(test_id)
	sm.free()
	return true

func test_weapon_definitions_and_evolutions() -> bool:
	var all_ids := WeaponRegistry.get_all_weapon_ids()
	if all_ids.size() != 29:
		printerr("Fail: Total weapons must be exactly 29, got: ", all_ids.size())
		return false

	for w_id in all_ids:
		var data := WeaponRegistry.get_weapon_data(w_id)
		if not data.has("evolution_id") or data["evolution_id"] == "":
			printerr("Fail: Weapon missing evolution_id: ", w_id)
			return false
		if not data.has("evolution_requires") or data["evolution_requires"] == "":
			printerr("Fail: Weapon missing evolution_requires: ", w_id)
			return false
		var cd_arr: Array = data.get("base_cooldown", [])
		if cd_arr.size() != 5:
			printerr("Fail: Weapon must have 5 cooldown tiers: ", w_id)
			return false

	return true

func test_character_registry() -> bool:
	var chars := CharacterRegistry.get_all_character_ids()
	if chars.size() != 9:
		printerr("Fail: Must have exactly 9 characters, got: ", chars.size())
		return false

	var expected := ["jankz", "seraföhn", "löwina", "illaupsi", "brioche", "yasüff", "rübenrambo", "auarora", "xayaya"]
	for exp_id in expected:
		if not chars.has(exp_id):
			printerr("Fail: Missing expected character: ", exp_id)
			return false

		var c_data := CharacterRegistry.get_character_data(exp_id)
		if not c_data.has("starter_weapon") or not c_data.has("passive") or not c_data.has("ability_e") or not c_data.has("ability_r"):
			printerr("Fail: Incomplete character definition: ", exp_id)
			return false

	return true

func test_passives_and_augments() -> bool:
	var pass_ids := PassiveRegistry.get_all_passive_ids()
	if pass_ids.size() != 12:
		printerr("Fail: Must have exactly 12 in-run passives, got: ", pass_ids.size())
		return false

	var aug_ids := AugmentRegistry.get_all_augment_ids()
	if aug_ids.size() != 33:
		printerr("Fail: Must have exactly 33 Yuumi-Augments, got: ", aug_ids.size())
		return false

	var upg_ids := ShopUpgradeRegistry.upgrades.keys()
	if upg_ids.size() != 15:
		printerr("Fail: Must have exactly 15 Lobby Shop upgrades, got: ", upg_ids.size())
		return false

	var bonus_ids := FortuneBonusRegistry.get_all_bonus_ids()
	if bonus_ids.size() != 9:
		printerr("Fail: Must have exactly 9 Fortune bonuses, got: ", bonus_ids.size())
		return false

	return true

func test_flowfield_pathfinding() -> bool:
	var ff := Flowfield.new(20, 20, 64.0, Vector2(-640.0, -640.0))
	var target_pos := Vector2(0.0, 0.0)
	ff.update_field([target_pos])

	# Sample a position to the left of target (-200, 0)
	var dir := ff.get_flow_direction(Vector2(-200.0, 0.0))
	# Flow direction should point towards positive X (towards target at 0, 0)
	if dir.x <= 0.0:
		printerr("Fail: Flow direction should point towards target (+X), got: ", dir)
		return false

	return true

func test_quest_manager() -> bool:
	var qm := QuestManagerScript.new()
	qm._init_quest_database()
	if qm.all_quests.size() < 25:
		printerr("Fail: Expected at least 25 quests, got: ", qm.all_quests.size())
		return false
	qm.free()
	return true

func test_scenes_instantiation() -> bool:
	var scenes_to_test := [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/lobby.tscn",
		"res://scenes/ui/shop.tscn",
		"res://scenes/ui/character_select.tscn",
		"res://scenes/ui/profile_select.tscn",
		"res://scenes/ui/quest_menu.tscn",
		"res://scenes/ui/stats_menu.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/pause_menu.tscn",
		"res://scenes/ui/game_over_screen.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/level_up_modal.tscn",
		"res://scenes/game/game_world.tscn",
		"res://scenes/characters/player.tscn",
		"res://scenes/maps/map_warehouse.tscn",
		"res://scenes/maps/map_outskirts.tscn",
		"res://scenes/maps/map_lab.tscn",
		"res://scenes/maps/map_beach.tscn",
		"res://scenes/combat/projectile_base.tscn",
		"res://scenes/combat/drop_item.tscn",
		"res://scenes/enemies/enemy_base.tscn",
		"res://scenes/enemies/boss_base.tscn"
	]

	for sc_path in scenes_to_test:
		if not ResourceLoader.exists(sc_path):
			printerr("Fail: Scene does not exist: ", sc_path)
			return false
		var instance = load(sc_path).instantiate()
		instance.free()

	return true

func test_pause_and_process_modes() -> bool:
	# 1. GameWorld & MapContainer
	var gw_scene: PackedScene = load("res://scenes/game/game_world.tscn")
	var gw_state := gw_scene.get_state()
	var gw_process_mode := 0
	var map_process_mode := 0
	for i in range(gw_state.get_node_count()):
		var n_name := gw_state.get_node_name(i)
		for p in range(gw_state.get_node_property_count(i)):
			if gw_state.get_node_property_name(i, p) == "process_mode":
				if n_name == "GameWorld":
					gw_process_mode = int(gw_state.get_node_property_value(i, p))
				elif n_name == "MapContainer":
					map_process_mode = int(gw_state.get_node_property_value(i, p))

	if gw_process_mode != 3: # Node.PROCESS_MODE_ALWAYS
		printerr("Fail: GameWorld scene process_mode should be 3 (ALWAYS), got: ", gw_process_mode)
		return false
	if map_process_mode != 1: # Node.PROCESS_MODE_PAUSABLE
		printerr("Fail: MapContainer scene process_mode should be 1 (PAUSABLE), got: ", map_process_mode)
		return false

	# 2. Player
	var p_scene: PackedScene = load("res://scenes/characters/player.tscn")
	var p_mode := _get_root_process_mode(p_scene.get_state())
	if p_mode != 1:
		printerr("Fail: Player scene process_mode should be 1 (PAUSABLE), got: ", p_mode)
		return false

	# 3. Projectile
	var proj_scene: PackedScene = load("res://scenes/combat/projectile_base.tscn")
	var proj_mode := _get_root_process_mode(proj_scene.get_state())
	if proj_mode != 1:
		printerr("Fail: Projectile scene process_mode should be 1 (PAUSABLE), got: ", proj_mode)
		return false

	# 4. Enemy
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
	var enemy_mode := _get_root_process_mode(enemy_scene.get_state())
	if enemy_mode != 1:
		printerr("Fail: Enemy scene process_mode should be 1 (PAUSABLE), got: ", enemy_mode)
		return false

	# 5. LevelUpModal
	var lvl_scene: PackedScene = load("res://scenes/ui/level_up_modal.tscn")
	var lvl_mode := _get_root_process_mode(lvl_scene.get_state())
	if lvl_mode != 2: # Node.PROCESS_MODE_WHEN_PAUSED
		printerr("Fail: LevelUpModal scene process_mode should be 2 (WHEN_PAUSED), got: ", lvl_mode)
		return false

	# 6. PauseMenu
	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	var pause_mode := _get_root_process_mode(pause_scene.get_state())
	if pause_mode != 2:
		printerr("Fail: PauseMenu scene process_mode should be 2 (WHEN_PAUSED), got: ", pause_mode)
		return false

	return true

func _get_root_process_mode(state: SceneState) -> int:
	for p in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, p) == "process_mode":
			return int(state.get_node_property_value(0, p))
	return 0

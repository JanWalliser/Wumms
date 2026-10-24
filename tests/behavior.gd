extends Node

var failed: Array[String] = []
var count := 0
var id := "behavior_test_"+str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failed.append(label)
		printerr("FAIL: ",label)

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var saved = ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume = 0
	SaveManager.save_profile(SaveManager.create_default_profile(id,"Behavior test"))
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = i == 0 or i == 3
		ProfileManager.player_slots[i]["profile_id"] = id
	GameManager.start_new_run("map_outskirts","hard")
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var p = GameManager.active_player_nodes[0]
	var ally = GameManager.active_player_nodes[1]
	world.current_map_node.spawner.set_physics_process(false)
	p.weapon_controller.set_process(false)
	ally.weapon_controller.set_process(false)
	var enemy = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	world.current_map_node.add_child(enemy)
	enemy.global_position = p.global_position+Vector2(50,0)
	enemy.max_health = 100000
	enemy.current_health = 100000
	enemy.set_physics_process(false)
	p.current_stats["armor"] = 100
	p.current_health = 300
	p.take_hit(100,false,enemy)
	check(p.current_health == 250,"armor mitigates contact")
	p.current_health = 300
	p.is_invulnerable_active = true
	p.current_shield = 100
	p.take_hit(100,false,enemy)
	check(p.current_shield == 100 and p.current_health == 300,"immunity before shield")
	p.is_invulnerable_active = false
	p.current_shield = 0
	var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
	world.add_child(proj)
	proj.setup(0,Vector2.RIGHT,0,10,1,1,p,{"crit_chance":0})
	var hp = enemy.current_health
	proj._handle_target_hit(enemy)
	proj._handle_target_hit(enemy)
	check(enemy.current_health == hp-10,"projectile finalizes immediately")
	var friendly_hp = ally.current_health
	var hostile = load("res://scenes/combat/projectile_base.tscn").instantiate()
	world.add_child(hostile)
	hostile.setup(0,Vector2.RIGHT,0,10,1,1,enemy,{})
	hostile._handle_target_hit(enemy)
	check(enemy.current_health == hp-10,"hostile ignores allies")
	hostile._handle_target_hit(ally)
	check(ally.current_health < friendly_hp,"hostile hits player")
	p.passives["ability_haste"] = 1
	check(not p.weapon_controller.evolve_weapon("weapon_meow_meow"),"cannot evolve below level 5")
	for n in range(4): p.weapon_controller.upgrade_weapon("weapon_meow_meow")
	check(p.weapon_controller.evolve_weapon("weapon_meow_meow"),"valid evolution accepted")
	check(not p.weapon_controller.evolve_weapon("weapon_meow_meow"),"evolution exactly once")
	GameManager.add_team_exp(sum_first_three_levels())
	GameManager.trigger_access_card()
	GameManager.trigger_access_card()
	var rounds = 0
	while not GameManager.current_selection.is_empty() and rounds < 10:
		var old_event = world.level_up_modal.event_id
		for slot in world.level_up_modal.player_choices_data.keys(): world.level_up_modal._confirm_selection(slot,0,old_event)
		await get_tree().process_frame
		if not GameManager.current_selection.is_empty():
			var before = GameManager.pending_level_up_players.duplicate()
			world.level_up_modal._confirm_selection(0,0,old_event)
			check(before == GameManager.pending_level_up_players,"stale event rejected")
		rounds += 1
	check(rounds == 5 and not get_tree().paused,"mixed event queue drains")
	# Freeze simulation for deterministic behavior checks.
	GameManager.set_state(GameManager.GameState.PAUSED)
	p.character_id = "jankz"
	p.jinx_kills = 0
	for kill in 70:
		var victim := Enemy.new()
		p.on_combat_kill(victim)
		victim.free()
	p._runtime_update(1.1)
	check(p.jinx_kills==0 and p.jinx_excited_until>GameManager.game_time and p.get_stat("movement_speed") > p.base_stats["movement_speed"],"Jankz milestone grants temporary excitement")
	p.character_id = "seraföhn"
	p._on_ability()
	check(p.consume_echo() and not p.consume_echo(),"Sera echo consumed once")
	p.character_id = "yasüff"
	p.wall_time = 5
	p.wall_direction = Vector2.RIGHT
	hostile = load("res://scenes/combat/projectile_base.tscn").instantiate()
	world.add_child(hostile)
	hostile.global_position = p.global_position+Vector2(80,0)
	check(p.blocks_projectile(hostile),"windwall owns collision region")
	p.character_id = "xayaya"
	p.place_feather(p.global_position+Vector2(200,0))
	p._trigger_bladecaller()
	check(p.feathers.is_empty(),"feather recall owns its feathers")
	p.character_id = "brioche"
	p._activate_ability_e()
	check(p.frenzy_time > 0,"Brioche enters frenzy")
	p._end_frenzy()
	check(p.frenzy_time == 0 and not p.temp_buffs.has("frenzy"),"Brioche exits frenzy")
	var director = world.current_map_node.get_node("EventDirector")
	director.active = {"id":1,"type":"trial","position":Vector2.ZERO}
	director.finish_event(true)
	var trial = SaveManager.load_profile(id)["quest_progress"].get("belveth_trials_hard_20",0)
	director.finish_event(true)
	check(trial == 1 and SaveManager.load_profile(id)["quest_progress"]["belveth_trials_hard_20"] == 1,"trial reward exactly once")
	world.current_map_node.carrier = p
	p.global_position = Vector2.ZERO
	world.current_map_node._process(0.1)
	check(world.current_map_node.cannon_active_timer>0,"battery delivery activates cannon")
	GameManager.end_run(false)
	GameManager.return_to_menu()
	world.free()
	await get_tree().process_frame
	# Save validation and recovery use only the temporary test profile.
	var profile = SaveManager.load_profile(id)
	profile["gold"] = 543
	SaveManager.save_profile(profile)
	SaveManager.save_profile(profile)
	var file = FileAccess.open(SaveManager.get_profile_path(id),FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	SaveManager.invalidate_cache(id)
	check(SaveManager.load_profile(id)["gold"] == 543,"backup recovers root-array corruption")
	profile = SaveManager.load_profile(id)
	profile["shop_upgrades"]["damage"] = 999
	profile["gold"] = -1
	SaveManager.save_profile(profile)
	profile = SaveManager.load_profile(id)
	check(profile["gold"] == 0 and profile["shop_upgrades"]["damage"] == 8,"save clamps values")
	check(not SaveManager.save_profile({"id":"../invalid"}),"unsafe profile id rejected")
	profile = SaveManager.load_profile(id)
	profile["schema_version"] = 999
	file = FileAccess.open(SaveManager.get_profile_path(id),FileAccess.WRITE)
	var future_text = JSON.stringify(profile)
	file.store_string(future_text)
	file.close()
	SaveManager.invalidate_cache(id)
	check(SaveManager.load_profile(id).is_empty(),"future schema refused")
	check(FileAccess.get_file_as_string(SaveManager.get_profile_path(id)) == future_text,"future schema not replaced by older backup")

	# =========================================================================
	# PRIORITY 1 TESTS: Weapon Selection Bug & Access Card Separation
	# =========================================================================
	GameManager.run_finalized = false
	GameManager.set_state(GameManager.GameState.GAMEPLAY)
	var test_p1_id := "p1_test_" + str(Time.get_ticks_usec())
	SaveManager.save_profile(SaveManager.create_default_profile(test_p1_id, "Priority1 Test"))
	var p_test: PlayerController = load("res://scenes/characters/player.tscn").instantiate()
	add_child(p_test)
	p_test.setup(0, test_p1_id, "jankz")
	# Level starter weapon to max level (5)
	for s in range(4):
		p_test.weapon_controller.upgrade_weapon("weapon_meow_meow")
	check(p_test.weapon_controller.get_weapon_level("weapon_meow_meow") == 5, "starter weapon reaches level 5")

	# When passives are full and starter weapon is at Lv 5, Level-Up must offer new weapons (not 25 gold/heal)
	p_test.passives = {"armor": 5, "damage": 5, "crit_chance": 5}
	var lvl_choices := LevelUpManager.generate_choices_for_player(p_test, false)
	var has_new_weapon := false
	var has_only_consumables := true
	for c in lvl_choices:
		if c.get("type") == "new_weapon":
			has_new_weapon = true
			has_only_consumables = false
		elif c.get("type") in ["weapon_upgrade", "new_passive", "passive_upgrade"]:
			has_only_consumables = false
	check(has_new_weapon, "level-up offers new weapon when starter is level 5")
	check(not has_only_consumables, "level-up does NOT fall back to only gold/heal when slots free")

	# Applying new weapon succeeds and expands weapon count
	for c in lvl_choices:
		if c.get("type") == "new_weapon":
			var ok_add := LevelUpManager.apply_choice_to_player(p_test, c)
			check(ok_add and p_test.weapon_controller.equipped_weapons.size() == 2, "new weapon added to player")
			break

	# Guest player with empty profile_id still gets valid choices
	var p_guest: PlayerController = load("res://scenes/characters/player.tscn").instantiate()
	add_child(p_guest)
	p_guest.setup(1, "", "seraföhn")
	var guest_choices := LevelUpManager.generate_choices_for_player(p_guest, false)
	check(guest_choices.size() == 3, "guest slot with empty profile_id receives 3 choices")
	p_guest.free()

	# Access Card separation: when Lv 5 weapon lacks matching passive, NO new_weapon is offered
	p_test.passives.clear()
	var card_choices_no_passive := LevelUpManager.generate_choices_for_player(p_test, true)
	var card_offered_new_weapon := false
	for c in card_choices_no_passive:
		if c.get("type") == "new_weapon":
			card_offered_new_weapon = true
	check(not card_offered_new_weapon, "access card never offers unequipped new weapons")
	check(card_choices_no_passive.size() == 3, "access card provides 3 selectable choices")

	# Access Card evolution: when required passive is added, evolution IS offered
	p_test.passives["ability_haste"] = 1
	var card_choices_with_passive := LevelUpManager.generate_choices_for_player(p_test, true)
	var card_offered_evolution := false
	for c in card_choices_with_passive:
		if c.get("type") == "evolution":
			card_offered_evolution = true
	check(card_offered_evolution, "access card offers evolution when Lv 5 + matching passive")
	p_test.free()

	# =========================================================================
	# PRIORITY 2 & 3 TESTS: Flowfield Corridor Navigation & Blocked Seed Handling
	# =========================================================================
	var ff_test := Flowfield.new(30, 30, 64.0, Vector2.ZERO)
	# Target at (5, 5) -> cell index 5*30 + 5 = 155
	var target_coord := ff_test.grid_to_world(Vector2i(5, 5)) + Vector2(10, 10)
	ff_test.update_field([target_coord])
	# Flow vector inside target cell should point towards target_coord
	var flow_in_target_cell := ff_test.get_flow_direction(ff_test.grid_to_world(Vector2i(5, 5)))
	check(not flow_in_target_cell.is_zero_approx(), "flowfield vector inside target cell is non-zero")

	# If target is inside a blocked cell, neighbor cells must still receive valid cost
	ff_test.set_blocked(5, 5, true)
	ff_test.update_field([ff_test.grid_to_world(Vector2i(5, 5))])
	var neighbor_cost := ff_test.cost_field[5 * 30 + 6]
	check(neighbor_cost < ff_test.INFINITE_COST, "blocked target cell successfully seeds nearest unblocked neighbor")

	# =========================================================================
	# PRIORITY 4 TESTS: Loot Crate, Rek'Sai Boss Mechanics & Map 1 Scene
	# =========================================================================
	var crate_test = load("res://scenes/combat/loot_crate.tscn").instantiate()
	add_child(crate_test)
	check(crate_test.is_in_group("enemies"), "loot crate is in enemies group for projectile targeting")
	check(crate_test.current_health == 100.0, "loot crate has 100 reference HP")
	crate_test.receive_damage(20.0, false)
	check(crate_test.current_health == 80.0, "loot crate receives damage")
	crate_test.receive_damage(85.0, false)
	check(crate_test.is_broken, "loot crate shatters on depletion")

	# Rek'Sai Boss phase 2
	GameManager.set_state(GameManager.GameState.GAMEPLAY)
	var boss_test: BossController = load("res://scenes/enemies/boss_base.tscn").instantiate()
	add_child(boss_test)
	boss_test.setup("boss_reksai", ff_test, SpatialHash.new(64))
	boss_test.current_health = boss_test.max_health * 0.4
	boss_test._physics_process(0.016)
	check(boss_test.phase_2_triggered and boss_test.boss_phase == 2, "Rek'Sai triggers phase 2 below 50% HP")
	boss_test.free()

	# Map Warehouse scene
	var map_wh: MapBase = load("res://scenes/maps/map_warehouse.tscn").instantiate()
	add_child(map_wh)
	check(map_wh.map_id == "map_warehouse", "map_warehouse loads with correct ID")
	check(is_instance_valid(map_wh.get_node_or_null("FountainMarker")), "warehouse has FountainMarker")
	check(map_wh.obstacles_container.get_child_count() > 10, "warehouse has reconstructed obstacles and crates")
	map_wh.free()

	# =========================================================================
	# OFFICIAL XP REQUIREMENTS & REROLL EXCLUSION TESTS
	# =========================================================================
	check(GameManager.calculate_required_exp_for_level(1) == 5, "official Swarm XP curve: Level 1 requires 5 XP")
	check(GameManager.calculate_reference_exp_for_level(2) == 10, "archived cumulative interpretation retains ten XP at level two")
	check(GameManager.calculate_reference_exp_for_level(5) == 25, "archived cumulative interpretation retains twenty-five XP at level five")
	check(GameManager.calculate_required_exp_for_level(2)==15 and GameManager.calculate_required_exp_for_level(5)==38,"early-game project pacing is explicitly separate from archive values")

	# Reroll excludes previously offered choices
	var test_prof := SaveManager.load_profile(test_p1_id)
	test_prof["features"] = ["yuumi_quests", "reroll"]
	SaveManager.save_profile(test_prof)
	var p_reroll: PlayerController = load("res://scenes/characters/player.tscn").instantiate()
	p_reroll.setup(0, test_p1_id, "jankz")
	add_child(p_reroll)
	var initial_choices := LevelUpManager.generate_choices_for_player(p_reroll, false)
	var exclude_ids: Array = []
	for c in initial_choices:
		exclude_ids.append(c["id"])
	var rerolled_choices := LevelUpManager.generate_choices_for_player(p_reroll, false, exclude_ids)
	var any_overlap := false
	for c in rerolled_choices:
		if exclude_ids.has(c["id"]):
			any_overlap = true
	check(not any_overlap and rerolled_choices.size() == 3, "reroll excludes previously offered ability choices")

	# Augment reroll exclusion
	var aug_initial := LevelUpManager.augment_choices(p_reroll)
	var aug_exclude: Array = []
	for a in aug_initial:
		aug_exclude.append(a["id"])
	var aug_rerolled := LevelUpManager.augment_choices(p_reroll, aug_exclude)
	var aug_overlap := false
	for a in aug_rerolled:
		if aug_exclude.has(a["id"]):
			aug_overlap = true
	check(not aug_overlap and aug_rerolled.size() == 3, "augment reroll excludes previously offered augments")
	p_reroll.free()

	ProfileManager.player_slots = saved
	SaveManager.delete_profile(id)
	SaveManager.delete_profile(test_p1_id)
	QuestManager.dirty_profiles.erase(id)
	print("BEHAVIOR: ",count," checks, ",failed.size()," failed")
	get_tree().quit(0 if failed.is_empty() else 1)

func sum_first_three_levels() -> int:
	var total := 0
	for level in range(1,4): total+=GameManager.calculate_required_exp_for_level(level)+1
	return total

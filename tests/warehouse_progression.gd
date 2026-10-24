extends Node
const Catalog = preload("res://scripts/progression/warehouse_progression.gd")
var checks := 0
var failures: Array[String] = []
var ids: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func new_profile(label: String) -> String:
	var id := "warehouse_scope_"+label+"_"+str(Time.get_ticks_usec())
	ids.append(id)
	SaveManager.save_profile(SaveManager.create_default_profile(id,label))
	return id

func can_reach_metric(metric: String, profile: Dictionary) -> bool:
	var difficulties: Array = profile["unlocked_difficulties"]
	if metric=="boss_extreme_reksai": return difficulties.has("extreme")
	if metric in ["boss_hard_reksai","hard_time_survived","miniboss_hard_kills"]: return difficulties.has("hard")
	if metric in ["trials_completed","trials_hard_count"]: return difficulties.has("hard") and profile["features"].has("belveth_trials")
	if metric=="passives_in_hard_run": return difficulties.has("hard") and profile["passive_slots"]>=4 and profile["unlocked_passives"].size()>=4
	if metric.begins_with("char_milestone_"): return profile["unlocked_characters"].has(metric.trim_prefix("char_milestone_"))
	var weapon_metrics := {"weapon_level_blade":"weapon_blade_o_rang","weapon_level_vortex":"weapon_vortex_glove","weapon_level_shortbow":"weapon_shortbow","weapon_level_radiant":"weapon_radiant_field"}
	if weapon_metrics.has(metric): return profile["unlocked_weapons"].has(weapon_metrics[metric])
	if metric=="evolve_weapon":
		for id in profile["unlocked_weapons"]:
			if profile["unlocked_passives"].has(WeaponRegistry.get_weapon_data(id)["evolution_requires"]): return true
		return false
	if metric.begins_with("story_event_"):
		var characters := ["jankz","seraföhn","löwina","yasüff","brioche","rübenrambo","auarora","xayaya"]
		return profile["unlocked_characters"].has(characters[int(metric.trim_prefix("story_event_"))-1]) and can_reach_metric("evolve_weapon",profile)
	return metric in ["boss_kill","boxes_destroyed","char_level","elite_kills","fountain_activated","max_weapons_in_run","passives_in_run","time_survived","total_kills","vacuums_collected","warehouse_miniboss_kills"]

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false,1.0/60)
	get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/warehouse-scope-"+label+".png")

func run_tests() -> void:
	var old_slots := ProfileManager.player_slots.duplicate(true)
	GameManager.set_process(false)
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	var fresh_id := new_profile("fresh")
	var guest_id := new_profile("guest")
	for slot in 4:
		ProfileManager.player_slots[slot]["active"]=slot==0
		ProfileManager.player_slots[slot]["profile_id"]=fresh_id
		ProfileManager.player_slots[slot]["device_id"]=-1 if slot==0 else slot-1
		ProfileManager.player_slots[slot]["character_id"]="jankz"
	var fresh := SaveManager.load_profile(fresh_id)
	check(fresh["schema_version"]==4 and fresh["unlocked_difficulties"]==["story"],"new profile starts in Story without automatic unlock-all")
	check(not ShopUpgradeRegistry.is_unlocked_for_profile("anima_power",fresh),"Anima locked before Extreme win")
	var lobby = load("res://scenes/ui/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby.map_ids==["map_warehouse"] and lobby.map_option.item_count==1,"lobby exposes exactly the released map")
	check(lobby.difficulty_option.is_item_disabled(1) and lobby.difficulty_option.is_item_disabled(2),"fresh host sees locked Hard and Extreme")
	check(lobby.difficulty_option.get_item_tooltip(1)==Catalog.difficulty_hint("hard"),"difficulty hints use shared progression catalog")
	await capture("fresh-lobby")
	lobby.free()
	# Migration reads an actual old-schema file, preserving financial/history data.
	var legacy_id := new_profile("legacy")
	var legacy := SaveManager.create_default_profile(legacy_id,"Legacy")
	legacy["schema_version"]=3
	legacy["gold"]=4321
	legacy["shop_upgrades"]["damage"]=2
	legacy["passive_slots"]=6
	legacy["unlocked_maps"]=["map_warehouse","map_outskirts","map_lab","map_beach"]
	legacy["settled_runs"]=["historical-run"]
	legacy["completed_quests"]=["defeat_reksai","defeat_briar","defeat_belveth","defeat_aatrox","lab_freeze","lab_fuel","belveth_hard","aatrox_hard","reksai_hard","story_pastete"]
	legacy["quest_progress"]["lab_freeze"]=1
	var file := FileAccess.open(SaveManager.get_profile_path(legacy_id),FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	SaveManager.invalidate_cache(legacy_id)
	var migrated := SaveManager.load_profile(legacy_id)
	check(migrated["gold"]==4321 and migrated["shop_upgrades"]["damage"]==2 and migrated["settled_runs"]==["historical-run"],"migration preserves gold, purchases and settlement ledger without replaying story gold")
	check(migrated["unlocked_maps"]==legacy["unlocked_maps"] and migrated["passive_slots"]==6,"historical maps and six earned slots retained")
	for new_id in Catalog.LEGACY_COMPLETIONS.values(): check(migrated["completed_quests"].has(new_id),"legacy objective maps to "+new_id)
	check(migrated["unlocked_characters"].has("brioche") and migrated["unlocked_characters"].has("yasüff"),"old character entitlements restored")
	check(migrated["unlocked_weapons"].has("weapon_iceblast") and migrated["unlocked_weapons"].has("weapon_mega_blast"),"old map-specific weapon rewards restored")
	check(migrated["unlocked_difficulties"].has("hard") and migrated["unlocked_difficulties"].has("extreme") and ShopUpgradeRegistry.is_unlocked_for_profile("anima_power",migrated),"legacy difficulties and Anima remain available")
	check(SaveManager._validate_and_migrate_profile(migrated.duplicate(true))==migrated,"migration is idempotent")
	check(SaveManager.save_profile(migrated),"migrated profile saves successfully")
	var backup_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.get_backup_path(legacy_id)))
	check(backup_data["schema_version"]==3 and backup_data["gold"]==4321,"saving migrated data retains old-schema backup")
	var partial := SaveManager.create_default_profile("partial","Partial")
	partial["schema_version"]=3
	partial["quest_progress"]["lab_fuel"]=0.5
	partial=SaveManager._validate_and_migrate_profile(partial)
	check(partial["quest_progress"]["lab_fuel"]==0.5 and not partial["completed_quests"].has("warehouse_miniboss5_megablast"),"incompatible historical partial progress retained but not counted as completed new goal")
	var old_story := SaveManager.create_default_profile("old_story","Old Story")
	old_story["schema_version"]=3
	old_story["completed_quests"]=["defeat_aatrox"]
	old_story=SaveManager._validate_and_migrate_profile(old_story)
	check(old_story["unlocked_difficulties"].has("hard") and not old_story["unlocked_difficulties"].has("extreme"),"old Aatrox Story completion preserves Hard without falsely claiming a new Hard victory")
	var retained := SaveManager.create_default_profile("retained","Retained")
	retained["schema_version"]=3
	retained["passive_slots"]=6
	retained["features"]=["extreme_and_anima"]
	retained["unlocked_characters"].append("xayaya")
	retained=SaveManager._validate_and_migrate_profile(retained)
	check(retained["passive_slots"]==6 and retained["unlocked_characters"].has("xayaya") and retained["unlocked_difficulties"].has("extreme") and ShopUpgradeRegistry.is_unlocked_for_profile("anima_power",retained),"existing entitlements survive even without their historical quest ledger")
	# Natural gameplay event routes, with a different-profile guest and shared slots.
	for slot in 4:
		ProfileManager.player_slots[slot]["active"]=true
		ProfileManager.player_slots[slot]["profile_id"]=fresh_id if slot<2 else guest_id
	for difficulty in ["story","hard","extreme"]:
		GameManager.start_new_run("map_warehouse",difficulty)
		var world = load("res://scenes/game/game_world.tscn").instantiate()
		add_child(world)
		world.current_map_node.spawner.set_physics_process(false)
		world.current_map_node.set_process(false)
		world.current_map_node.get_node("EventDirector").set_process(false)
		for player in GameManager.active_player_nodes:
			player.set_physics_process(false)
			player.weapon_controller.set_process(false)
		if difficulty=="story":
			for kill in 5:
				var miniboss = world.current_map_node.spawner._spawn_single_enemy("mini_boss",world.current_map_node.spawner.valid_spawn())
				check(is_instance_valid(miniboss),"miniboss can be spawned for actual death-path check")
				if is_instance_valid(miniboss):
					miniboss.status_effects.update(2.0) # Finish the intentional entrance protection.
					DamageSystem.apply_damage({},miniboss,1e9,false,GameManager.active_player_nodes[0],"true")
			for id in [fresh_id,guest_id]: check(SaveManager.load_profile(id)["unlocked_weapons"].has("weapon_mega_blast"),"five actual miniboss deaths unlock Mega-Blast once per profile")
		GameManager.spawn_map_boss()
		check(is_instance_valid(GameManager.current_boss_node),"warehouse boss exists for "+difficulty)
		GameManager.current_boss_node.status_effects.update(2.0)
		DamageSystem.apply_damage({},GameManager.current_boss_node,1e9,false,GameManager.active_player_nodes[0],"true")
		for frame in 3: await get_tree().process_frame
		for id in [fresh_id,guest_id]:
			var profile := SaveManager.load_profile(id)
			check(profile["unlocked_difficulties"].has("hard"),"boss victory unlocks Hard for each distinct participating profile")
			if difficulty=="story": check(not profile["unlocked_difficulties"].has("extreme"),"Story victory does not skip Hard")
			else: check(profile["unlocked_difficulties"].has("extreme"),"Hard victory unlocks Extreme")
			check(ShopUpgradeRegistry.is_unlocked_for_profile("anima_power",profile)==(difficulty=="extreme"),"Anima requires Extreme victory")
			check(profile["stats"]["runs_played"]==["story","hard","extreme"].find(difficulty)+1,"shared slots settle once per distinct profile")
		GameManager.return_to_menu()
		world.free()
		await get_tree().process_frame
	# Fixed-point reachability: only metrics available through this map and owned gear.
	var closure_id := new_profile("closure")
	for slot in 4:
		ProfileManager.player_slots[slot]["active"]=slot==0
		ProfileManager.player_slots[slot]["profile_id"]=closure_id
	GameManager.start_new_run("map_warehouse","story")
	for pass_index in 20:
		var before: int = SaveManager.load_profile(closure_id)["completed_quests"].size()
		for quest in Catalog.OBJECTIVES:
			var profile := SaveManager.load_profile(closure_id)
			if profile["completed_quests"].has(quest["id"]) or not can_reach_metric(quest["metric"],profile): continue
			QuestManager.notify_event(quest["metric"],quest["target"],false)
		if SaveManager.load_profile(closure_id)["completed_quests"].size()==before: break
	var reachable := SaveManager.load_profile(closure_id)
	for quest in Catalog.OBJECTIVES:
		check(reachable["completed_quests"].has(quest["id"]),"reachable from a fresh warehouse profile: "+quest["id"])
		check(quest["reward_type"] not in ["map","char_and_map"],"no reward depends on exposing another map: "+quest["id"])
	for id in CharacterRegistry.characters: check(reachable["unlocked_characters"].has(id),"all nine characters reachable: "+id)
	for id in WeaponRegistry.get_general_weapon_ids(): check(reachable["unlocked_weapons"].has(id),"all twenty general weapons reachable: "+id)
	for id in PassiveRegistry.passives: check(reachable["unlocked_passives"].has(id),"all twelve passives reachable: "+id)
	check(reachable["passive_slots"]==6 and reachable["unlocked_difficulties"].has("extreme"),"six passive slots and Extreme reachable without other maps")
	var completed_count: int = reachable["completed_quests"].size()
	var gold_before: int = reachable["gold"]
	for quest in Catalog.OBJECTIVES: QuestManager.notify_event(quest["metric"],quest["target"],false)
	check(SaveManager.load_profile(closure_id)["completed_quests"].size()==completed_count and SaveManager.load_profile(closure_id)["gold"]==gold_before,"replaying all objectives cannot duplicate rewards")
	lobby=load("res://scenes/ui/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby.map_option.item_count==1 and not lobby.difficulty_option.is_item_disabled(2),"fully unlocked profile still exposes only warehouse with all difficulties")
	await capture("unlocked-lobby")
	lobby.free()
	var menu = load("res://scenes/ui/quest_menu.tscn").instantiate()
	add_child(menu)
	check(menu.quest_list.get_child_count()==Catalog.OBJECTIVES.size(),"quest menu renders the active shared catalog")
	menu.free()
	GameManager.return_to_menu()
	QuestManager.flush()
	ProfileManager.player_slots=old_slots
	for id in ids: SaveManager.delete_profile(id)
	GameManager.set_process(true)
	await get_tree().process_frame
	print("WAREHOUSE PROGRESSION: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("WAREHOUSE PROGRESSION PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

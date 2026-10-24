extends Node

var failed: Array[String] = []

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var original = ProfileManager.player_slots.duplicate(true)
	var id = "soak_"+str(Time.get_ticks_usec())
	SaveManager.save_profile(SaveManager.create_default_profile(id,"Soak"))
	AudioManager.sfx_volume = 0
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = true
		ProfileManager.player_slots[i]["profile_id"] = id
		ProfileManager.player_slots[i]["character_id"] = ["jankz","seraföhn","löwina","rübenrambo"][i]
	Engine.time_scale = 30
	for map_id in ["map_warehouse","map_outskirts","map_lab","map_beach"]:
		GameManager.start_new_run(map_id,"extreme")
		GameManager.practice_mode = true
		GameManager.team_level = 30
		var world = load("res://scenes/game/game_world.tscn").instantiate()
		add_child(world)
		world.current_map_node.spawner.max_concurrent_enemies = 120
		for p in GameManager.active_player_nodes:
			p.set_meta("god_mode",true)
			p.passives = {"ability_haste":5,"damage":5,"area_size":5,"duration":5,"projectile_count":5,"crit_chance":5}
			p.recalculate_stats()
			for weapon in ["weapon_slicers","weapon_paw_poison","weapon_statikk","weapon_tibbers"]: p.weapon_controller.add_weapon(weapon)
		var frames = 0
		var began = Time.get_ticks_msec()
		while not GameManager.run_finalized and frames < 3000:
			if not GameManager.current_selection.is_empty():
				for slot in world.level_up_modal.player_choices_data.keys(): world.level_up_modal._confirm_selection(slot,0)
			if is_instance_valid(GameManager.current_boss_node):
				GameManager.current_boss_node.current_health = 1000000000
				if GameManager.boss_enraged_state:
					DamageSystem.apply_damage({},GameManager.current_boss_node,1e12,false,GameManager.active_player_nodes[0],"true")
			if frames%180 == 0:
				for p in GameManager.active_player_nodes:
					p._activate_ability_e()
					p._activate_ability_r()
			frames += 1
			if frames%600 == 0: print("SOAK PROGRESS: ",map_id," ",GameManager.game_time,"s, nodes=",get_tree().get_node_count())
			await get_tree().process_frame
		if not GameManager.run_finalized or not GameManager.final_result.get("victory",false): failed.append(map_id)
		print("SOAK MAP: ",map_id," time=",GameManager.game_time," frames=",frames," wall_ms=",Time.get_ticks_msec()-began," nodes=",get_tree().get_node_count())
		GameManager.return_to_menu()
		world.free()
		await get_tree().process_frame
	Engine.time_scale = 1
	ProfileManager.player_slots = original
	SaveManager.delete_profile(id)
	print("SOAK: 4 map timelines, ",failed.size()," failed")
	get_tree().quit(0 if failed.is_empty() else 1)

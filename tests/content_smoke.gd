extends Node

var failures: Array[String] = []
var checks := 0
var id := "content_test_"+str(Time.get_ticks_usec())

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var saved = ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume = 0
	var profile = SaveManager.create_default_profile(id,"Content regression")
	profile["features"] = ["yuumi_quests","reroll","boons_unlocked"]
	SaveManager.save_profile(profile)
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = i == 0
		ProfileManager.player_slots[i]["profile_id"] = id
	for char_id in CharacterRegistry.get_all_character_ids():
		ProfileManager.player_slots[0]["character_id"] = char_id
		GameManager.start_new_run("map_beach","extreme")
		GameManager.practice_mode = true
		GameManager.team_level = 10
		var world = load("res://scenes/game/game_world.tscn").instantiate()
		add_child(world)
		var p = GameManager.active_player_nodes[0]
		p.set_meta("god_mode",true)
		p.weapon_controller.set_process(false)
		var spawner = world.current_map_node.spawner
		spawner.set_physics_process(false)
		for enemy_id in EnemyRegistry.enemies:
			if enemy_id.begins_with("boss"): continue
			spawner._spawn_single_enemy(enemy_id,Vector2(100+randf()*250,randf()*200))
		p._activate_ability_e()
		p._activate_ability_r()
		verify(p.ability_e_cd>0 and p.ability_r_cd>0,"abilities: "+char_id)
		for w_id in WeaponRegistry.get_all_weapon_ids():
			var weapon = WeaponInstance.new(w_id,p)
			weapon.fire()
			weapon.level = 5
			weapon.evolve()
			weapon.fire()
			verify(weapon.is_evolved,"weapon: "+w_id)
		for aug_id in AugmentRegistry.get_all_augment_ids():
			p.augments = [aug_id]
			p.recalculate_stats()
			p._runtime_update(3.1)
			verify(p.get_stat("max_health")>0 and p.get_stat("movement_speed")>0,"augment: "+aug_id)
		for boon in FortuneBonusRegistry.get_all_bonus_ids():
			world.current_map_node.get_node("EventDirector").grant_boon(boon)
			verify(p.temp_buffs.has(boon),"boon: "+boon)
		for frame in range(30):
			if GameManager.current_state == GameManager.GameState.LEVEL_UP_PAUSE:
				for slot in world.level_up_modal.player_choices_data.keys(): world.level_up_modal._confirm_selection(slot,0)
			await get_tree().physics_frame
		GameManager.spawn_map_boss()
		GameManager.current_boss_node.current_health = GameManager.current_boss_node.max_health*0.4
		GameManager.current_boss_node._physics_process(0.01)
		verify(world.current_map_node.is_flooding,"phase triggers flood")
		GameManager.end_run(false)
		GameManager.return_to_menu()
		world.free()
		await get_tree().process_frame
	ProfileManager.player_slots = saved
	SaveManager.delete_profile(id)
	print("CONTENT SMOKE: ",checks," checks, ",failures.size()," failed")
	get_tree().quit(0 if failures.is_empty() else 1)

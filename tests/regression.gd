extends Node

var failures: Array[String] = []
var checks := 0
var test_id := "repair_test_" + str(Time.get_ticks_usec())
var original_slots: Array[Dictionary]

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		printerr("FAIL: ",description)

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	original_slots = ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume = 0
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Temporary regression"))
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = i == 0 or i == 2
		ProfileManager.player_slots[i]["profile_id"] = test_id
		ProfileManager.player_slots[i]["character_id"] = "seraföhn" if i == 2 else "jankz"
	for map_id in ["map_warehouse","map_outskirts","map_lab","map_beach"]:
		GameManager.start_new_run(map_id,"story")
		var world = load("res://scenes/game/game_world.tscn").instantiate()
		add_child(world)
		check(is_instance_valid(world.current_map_node),"map loads: " + map_id)
		check(GameManager.active_player_nodes.size() == 2,"two players")
		if GameManager.active_player_nodes.size() < 2: continue
		var p = GameManager.active_player_nodes[1]
		check(p.player_slot_index == 2,"slot identity")
		check(p.weapon_controller.equipped_weapons.size() == 1,"one starter")
		check(world.hud.players_hud_container.get_child_count() == 2,"HUD binds after spawn")
		GameManager.spawn_map_boss()
		check(is_instance_valid(GameManager.current_boss_node),"boss loads")
		check(GameManager.current_boss_node.boss_health_updated.get_connections().size() > 0,"boss HUD connection")
		GameManager.add_team_exp(sum_first_three_levels())
		var count = 0
		while not GameManager.current_selection.is_empty() and count < 10:
			for idx in world.level_up_modal.player_choices_data.keys(): world.level_up_modal._confirm_selection(idx,0)
			await get_tree().process_frame
			count += 1
		check(count == 3,"three queued choices")
		check(not get_tree().paused,"choice queue resumes")
		var pickup = load("res://scenes/combat/drop_item.tscn").instantiate()
		world.add_child(pickup)
		pickup.setup(1,10)
		var gold = GameManager.team_gold_earned
		pickup._collect(p)
		pickup._collect(p)
		check(GameManager.team_gold_earned == gold+10,"pickup exactly once")
		p.current_health = 300
		p.current_shield = 100
		p.take_hit(30,false,GameManager.current_boss_node)
		check(p.current_health == 300 and p.current_shield < 100,"shield before health")
		var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
		world.add_child(proj)
		proj.setup(0,Vector2.RIGHT,100,10,1,1,GameManager.current_boss_node,{})
		check(proj.collision_mask == 1,"hostile projectile targets player")
		GameManager.team_gold_earned = 10
		var before = SaveManager.load_profile(test_id)
		GameManager.end_run(false)
		GameManager.end_run(false)
		var after = SaveManager.load_profile(test_id)
		check(after["stats"]["runs_played"] == before["stats"]["runs_played"]+1,"unique profile run settlement")
		check(after["gold"] == before["gold"]+10,"one gold settlement")
		GameManager.return_to_menu()
		world.free()
		await get_tree().process_frame
	QuestManager.notify_event("total_kills",1,true)
	QuestManager.notify_event("total_kills",1,true)
	QuestManager.flush()
	SaveManager.invalidate_cache(test_id)
	check(SaveManager.load_profile(test_id)["quest_progress"].get("kills_15k",0) == 2,"partial quest persists")
	ProfileManager.player_slots = original_slots
	SaveManager.delete_profile(test_id)
	print("REGRESSION: ",checks," checks, ",failures.size()," failed")
	get_tree().quit(0 if failures.is_empty() else 1)

func sum_first_three_levels() -> int:
	var total := 0
	for level in range(1,4): total+=GameManager.calculate_required_exp_for_level(level)+1
	return total

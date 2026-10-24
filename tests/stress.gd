extends Node

func _ready() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var old = ProfileManager.player_slots.duplicate(true)
	var id = "stress_"+str(Time.get_ticks_usec())
	SaveManager.save_profile(SaveManager.create_default_profile(id,"Stress"))
	AudioManager.sfx_volume = 0
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = true
		ProfileManager.player_slots[i]["profile_id"] = id
	GameManager.start_new_run("map_warehouse","extreme")
	GameManager.practice_mode = true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var spawner = world.current_map_node.spawner
	spawner.max_concurrent_enemies = 500
	for p in GameManager.active_player_nodes:
		p.set_meta("god_mode",true)
		p.passives = {"ability_haste":5,"area_size":5,"damage":5,"duration":5,"projectile_count":5,"crit_chance":5}
		p.recalculate_stats()
		for weapon in ["weapon_slicers","weapon_paw_poison","weapon_statikk","weapon_tibbers"]: p.weapon_controller.add_weapon(weapon)
	for i in range(500):
		spawner._spawn_single_enemy("standard_grunt",Vector2.from_angle(TAU*i/500)*(350+i%10*30))
	for enemy in spawner.active_enemies:
		enemy.max_health = 1e10
		enemy.current_health = 1e10
	var samples: Array[float] = []
	for frame in range(240):
		var began = Time.get_ticks_usec()
		await get_tree().process_frame
		if frame>30: samples.append((Time.get_ticks_usec()-began)/1000.0)
	samples.sort()
	print("PROFILE: ",GameManager.profile_totals)
	print("STRESS: 500 enemies, 4 full builds; headless CPU frame median_ms=",samples[samples.size()/2]," p95_ms=",samples[int(samples.size()*0.95)]," nodes=",get_tree().get_node_count())
	GameManager.end_run(false)
	GameManager.return_to_menu()
	world.free()
	await get_tree().process_frame
	ProfileManager.player_slots = old
	SaveManager.delete_profile(id)
	get_tree().quit()

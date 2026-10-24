extends Node

var checks := 0
var failures: Array[String] = []
var temporary_id := "swarm_ui_"+str(Time.get_ticks_usec())

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void:
	call_deferred("run_tests")

func drain(world: Node) -> void:
	for turn in 30:
		if GameManager.current_selection.is_empty() and GameManager.selection_queue.is_empty(): break
		for index in world.level_up_modal.player_choices_data.keys():
			world.level_up_modal._confirm_selection(index,0,world.level_up_modal.event_id)
		await get_tree().process_frame
	await get_tree().process_frame

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	for frame in 4:
		await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60.0)
	get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/"+label+".png")

func run_tests() -> void:
	var old_slots := ProfileManager.player_slots.duplicate(true)
	var original_scale := get_window().content_scale_size
	var original_size := get_window().size
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	SaveManager.save_profile(SaveManager.create_default_profile(temporary_id,"Swarm UI acceptance"))
	AudioManager.sfx_volume = 0
	for index in 4:
		ProfileManager.player_slots[index]["active"] = true
		ProfileManager.player_slots[index]["profile_id"] = temporary_id
		ProfileManager.player_slots[index]["character_id"] = "jankz"
		ProfileManager.player_slots[index]["device_id"] = -1 if index==0 else index
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode = true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	map.spawner.set_physics_process(false)
	map.get_node("EventDirector").set_process(false)
	var players := GameManager.active_player_nodes.duplicate()
	for player in players:
		player.set_physics_process(false)
		player.weapon_controller.set_process(false)
		player.set_meta("god_mode",true)
	await get_tree().physics_frame
	var player = players[0]
	check(player.get_stat("max_health")==1000,"reference Jinx base health")
	check(CharacterRegistry.get_character_data("illaupsi")["base_stats"]["max_health"]==1500,"reference Illaoi base health")
	check(CharacterRegistry.get_character_data("löwina")["base_stats"]["armor"]==25,"reference Leona armor")
	check(WeaponRegistry.get_weapon_data("weapon_uwu_blaster")["evolution_damage"]==65,"14.15 UwU evolution damage")
	check(WeaponRegistry.get_weapon_data("weapon_gatling")["base_damage"]==[15.0,35.0,55.0,75.0,95.0],"14.15 Gatling damage progression")
	check(WeaponRegistry.get_weapon_data("weapon_shield_slam")["evolution_cooldown"]==1.5,"14.15 Leona weapon cooldown")
	var yasuo_stats: Dictionary = CharacterRegistry.get_character_data("yasüff")["base_stats"].duplicate()
	yasuo_stats["character_id"] = "yasüff"
	check(is_equal_approx(StatCalculator.compute_player_stats(yasuo_stats,{}, {"crit_chance":1},[],{})["crit_chance"],0.28),"Yasuo gains additive 15 percent without doubling upgrades")
	for i in 2:
		var drop = load("res://scenes/combat/drop_item.tscn").instantiate()
		world.add_child(drop)
		drop.setup(0,EnemyRegistry.get_enemy_data("standard_grunt")["exp_drop"])
		drop._collect(player)
		drop._collect(player)
	check(GameManager.team_level==1 and GameManager.current_team_exp==2,"two normal kills cannot reach level three; duplicate collect ignored")
	seed(20261023)
	for i in 32:
		var crate = load("res://scenes/combat/loot_crate.tscn").instantiate()
		world.add_child(crate)
		crate.position = Vector2(1000,1000)
		crate.receive_damage(100,false,player)
	await get_tree().process_frame
	var crate_xp := 0
	for item in get_tree().get_nodes_in_group("pickups"):
		if not item.collected and item.item_type==DropItem.ItemType.EXP_ORB: crate_xp+=item.value
	check(crate_xp==0,"destroying pods cannot create a 25-45 XP burst")
	GameManager.add_team_exp(3)
	check(GameManager.team_level==1 and GameManager.current_team_exp==5,"display threshold 5/5 does not level prematurely")
	GameManager.add_team_exp(1)
	check(GameManager.team_level==2 and GameManager.current_team_exp==0,"sixth blue XP reaches level two exactly")
	await drain(world)
	player.passives.clear()
	player.augments.clear()
	player.recalculate_stats()
	player.current_health = 500
	player._physics_process(5)
	check(is_equal_approx(player.current_health,500),"zero base regeneration does not invent healing")
	player.passives["health_regen"] = 1
	player.recalculate_stats()
	player._physics_process(5)
	check(is_equal_approx(player.current_health,504),"four HP5 restores four health over five seconds")
	player.augments.append("augment_experienced_fighter")
	player.recalculate_stats()
	GameManager.current_team_exp = 0
	GameManager.exp_carry = 0
	var orb = load("res://scenes/combat/drop_item.tscn").instantiate()
	world.add_child(orb)
	orb.setup(0,10)
	orb._collect(player)
	check(GameManager.team_level==2 and GameManager.current_team_exp==11,"own XP augment applies ten percent once, respecting slower early level costs")
	await drain(world)
	for teammate in players:
		teammate.current_health = teammate.get_stat("max_health")*0.5
	var health_pack = load("res://scenes/combat/drop_item.tscn").instantiate()
	world.add_child(health_pack)
	health_pack.setup(DropItem.ItemType.HEALTH_PACK,150)
	health_pack._collect(player)
	for teammate in players:
		check(is_equal_approx(teammate.current_health,teammate.get_stat("max_health")*0.7),"health pack restores twenty percent to each ally")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		get_window().size = resolution
		for count in [1,2,4]:
			GameManager.active_player_nodes.clear()
			for index in 4:
				players[index].remove_from_group("players")
				players[index].visible = index<count
				if index<count:
					GameManager.active_player_nodes.append(players[index])
					players[index].add_to_group("players")
					players[index].global_position = Vector2(index*80,1740)
			world.hud._rebuild_players_hud()
			await get_tree().process_frame
			world.hud._layout_hud()
			map.camera.global_position = Vector2(0,-1200)
			map.camera.zoom = Vector2.ONE*2.2
			map.camera._process(1.0/60.0)
			var safe: Rect2 = map.camera.get_playfield_rect()
			var view_size: Vector2 = map.camera.get_viewport_rect().size
			for participant in GameManager.active_player_nodes:
				var screen: Vector2 = (participant.global_position-map.camera.global_position)*map.camera.zoom+view_size*0.5
				check(safe.grow(-24).has_point(screen),"HUD clearance %s, %d players" % [resolution,count])
			check(map.camera.global_position.y>1400,"camera follows southern edge beyond old clamp")
			if count==4:
				players[0].global_position = Vector2(-1400,-1600)
				players[3].global_position = Vector2(1400,1700)
				map.camera._process(1.0/60.0)
				for participant in GameManager.active_player_nodes:
					var screen: Vector2 = (participant.global_position-map.camera.global_position)*map.camera.zoom+view_size*0.5
					check(safe.grow(-24).has_point(screen),"separated team remains in unobstructed playfield")
	get_window().size = Vector2i(1920,1080)
	for count in [1,4]:
		GameManager.active_player_nodes.clear()
		for index in 4:
			players[index].remove_from_group("players")
			players[index].visible = index<count
			if index<count:
				GameManager.active_player_nodes.append(players[index])
				players[index].add_to_group("players")
				players[index].global_position = map.get_safe_position(Vector2(-60+index*65,1150),24)
		world.hud._rebuild_players_hud()
		await get_tree().process_frame
		map.camera.position = players[0].position
		map.camera.zoom = Vector2.ONE*2.2
		map.camera._process(1)
		await capture("hud-%d-players" % count)
		var card = load("res://scenes/combat/drop_item.tscn").instantiate()
		world.add_child(card)
		card.setup(3,1)
		card.position = players[0].position+Vector2(90,-40)
		check(card.sprite.texture.resource_path.ends_with("access-card.res"),"custom access card art loaded")
		check(is_equal_approx(card.sprite.get_rect().size.x*card.sprite.scale.x,160.0),"access card graphic is four times its original width")
		var minimap = world.hud.get_node("Minimap")
		check(minimap.get_access_card_positions().has(card.global_position),"uncollected card appears on minimap")
		check(card.get_node("CollisionShape2D").shape.radius==16,"large aura does not enlarge pickup collision")
		if count==1: await capture("access-card-world")
		GameManager.add_team_exp(GameManager.required_team_exp-GameManager.current_team_exp+1)
		await get_tree().process_frame
		await get_tree().process_frame
		for index in world.level_up_modal.player_buttons:
			for button in world.level_up_modal.player_buttons[index]:
				check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(button.get_global_rect()),"selection cards fit screen")
				for label_name in ["Tag","Title","Description"]:
					check(Rect2(Vector2.ZERO,button.size).encloses(button.get_node(label_name).get_rect()),"card text stays within its artwork")
				if OS.get_cmdline_user_args().has("--dump-ui"):
					print("CARD ",button.get_global_rect()," TITLE ",button.get_node("Title").get_rect()," TAG ",button.get_node("Tag").get_rect()," DESC ",button.get_node("Description").get_rect())
		await capture("selection-%d-players" % count)
		await drain(world)
		var card_position: Vector2 = card.global_position
		var serial_before: int = GameManager.selection_serial
		card._collect(players[0])
		card._collect(players[0])
		check(not minimap.get_access_card_positions().has(card_position),"collected card marker disappears immediately")
		check(GameManager.selection_serial==serial_before+1,"large card still triggers only once")
		await drain(world)
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots = old_slots
	SaveManager.delete_profile(temporary_id)
	get_window().size = original_size
	get_window().content_scale_size = original_scale
	print("SWARM UI BALANCE: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("SWARM UI BALANCE PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

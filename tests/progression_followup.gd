extends Node

const Icons = preload("res://scripts/ui/swarm_icons.gd")
var checks := 0
var failures: Array[String] = []
var temporary_id := "progression_followup_"+str(Time.get_ticks_usec())

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

func freeze_world(world: Node) -> void:
	world.current_map_node.spawner.set_physics_process(false)
	world.current_map_node.get_node("EventDirector").set_process(false)
	world.current_map_node.set_process(false)
	for player in GameManager.active_player_nodes:
		player.set_physics_process(false)
		player.weapon_controller.set_process(false)

func run_tests() -> void:
	var original_slots := ProfileManager.player_slots.duplicate(true)
	var original_size := get_window().size
	var original_scale := get_window().content_scale_size
	get_window().content_scale_size = Vector2i.ZERO
	AudioManager.sfx_volume = 0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	var profile := SaveManager.create_default_profile(temporary_id,"Progression followup")
	check(profile["unlocked_weapons"].size()==5,"exactly five starter weapon types")
	check(profile["unlocked_passives"].size()==3 and profile["passive_slots"]==3,"three starter passive types and slots")
	var legacy := profile.duplicate(true)
	legacy["schema_version"] = 2
	legacy["gold"] = 1234
	legacy["unlocked_weapons"].append("weapon_crossbow")
	legacy["unlocked_weapons"].append("weapon_blade_o_rang")
	legacy["completed_quests"].append("survive_2_min")
	var migrated := SaveManager._validate_and_migrate_profile(legacy)
	check(migrated["gold"]==1234 and migrated["unlocked_weapons"].has("weapon_blade_o_rang"),"migration preserves gold and earned unlock")
	check(not migrated["unlocked_weapons"].has("weapon_crossbow"),"migration removes erroneous automatic late weapon grant")
	SaveManager.save_profile(profile)
	for index in 4:
		ProfileManager.player_slots[index]["active"] = index==0
		ProfileManager.player_slots[index]["profile_id"] = temporary_id
		ProfileManager.player_slots[index]["character_id"] = "jankz"
		ProfileManager.player_slots[index]["device_id"] = -1
	GameManager.start_new_run("map_warehouse","story")
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	freeze_world(world)
	var player = GameManager.active_player_nodes[0]
	check(not LevelUpManager.apply_choice_to_player(player,{"type":"new_weapon","id":"weapon_crossbow"}),"locked weapon rejected at application boundary")
	check(not LevelUpManager.apply_choice_to_player(player,{"type":"new_passive","id":"exp_gain"}),"locked passive rejected at application boundary")
	var milestone_enemy = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	world.add_child(milestone_enemy)
	milestone_enemy.set_physics_process(false)
	milestone_enemy.is_elite=false
	for kill in 69:
		var victim := Enemy.new()
		player.on_combat_kill(victim)
		victim.free()
	player._runtime_update(1)
	check(player.get_stat("movement_speed")==350 and player.get_stat("ability_haste")==0,"ordinary kills cannot stack permanent movement or haste")
	player.on_combat_kill(milestone_enemy)
	player._runtime_update(1)
	check(player.jinx_kills==0 and player.get_stat("ability_haste")==150,"70th kill starts eight-second excitement")
	GameManager.game_time=9
	player._runtime_update(1)
	check(player.get_stat("movement_speed")==350 and player.get_stat("ability_haste")==0,"excitement expires without lingering buffs")
	var elite_victim := Enemy.new()
	elite_victim.is_elite=true
	player.on_combat_kill(elite_victim)
	elite_victim.free()
	check(player.jinx_excited_until==17,"elite triggers excitement immediately")
	player.jinx_excited_until=-1
	player._runtime_update(1)
	GameManager.game_time=0
	check(is_equal_approx(milestone_enemy.move_speed,220*0.342),"enemy movement shares the map scale")
	milestone_enemy.free()
	var starter = player.weapon_controller.equipped_weapons[0]
	check(starter.get_damage()==20 and starter.get_effective_cooldown()==2.5 and starter.get_projectiles()==3,"level-one signature weapon has measured cluster damage and cadence")
	check(EnemyRegistry.get_enemy_data("standard_grunt")["max_health"]>starter.get_damage()*starter.get_projectiles(),"ordinary enemy survives one noncritical opening volley")
	for index in 60:
		for choice in LevelUpManager.generate_choices_for_player(player):
			if choice["type"]=="new_weapon": check(profile["unlocked_weapons"].has(choice["id"]),"only unlocked weapon offered")
			if choice["type"]=="new_passive": check(profile["unlocked_passives"].has(choice["id"]),"only unlocked passive offered")
	QuestManager.notify_event("time_survived",120)
	check(SaveManager.load_profile(temporary_id)["unlocked_weapons"].has("weapon_blade_o_rang"),"two-minute unlock works")
	for id in ["armor","damage","max_health"]:
		check(LevelUpManager.apply_choice_to_player(player,{"type":"new_passive","id":id}),"starter passive selectable")
	check(player.max_passive_slots==4,"fourth slot updates during same run")
	QuestManager.notify_event("passives_in_hard_run",4)
	player.recalculate_stats()
	check(player.max_passive_slots==5,"independent slot objective adds one, not jump to six")
	QuestManager.notify_event("trials_hard_count",3)
	player.recalculate_stats()
	check(player.max_passive_slots==6,"third slot objective reaches six")
	QuestManager.notify_event("trials_hard_count",3)
	player.recalculate_stats()
	check(player.max_passive_slots==6,"repeated objective cannot add slots twice")
	for id in profile["unlocked_weapons"]:
		if player.weapon_controller.equipped_weapons.size()<5: player.weapon_controller.add_weapon(id)
	check(player.weapon_controller.equipped_weapons.size()==5,"five weapon slots available including starter")
	check(not player.weapon_controller.add_weapon("weapon_tibbers"),"sixth weapon rejected")
	GameManager.practice_mode = true
	var enemy_scene = load("res://scenes/enemies/enemy_base.tscn")
	var early = enemy_scene.instantiate()
	world.add_child(early)
	early.set_physics_process(false)
	early.setup("standard_grunt",null,null)
	GameManager.game_time=600
	var late = enemy_scene.instantiate()
	world.add_child(late)
	late.set_physics_process(false)
	late.setup("standard_grunt",null,null)
	check(late.max_health>early.max_health and late.contact_damage>early.contact_damage,"later spawn has stronger HP and damage")
	var story_hp := 100*lerpf(2.2,3.6,220.0/240.0) # 600 real seconds now means 580 strength seconds.
	check(is_equal_approx(late.max_health,story_hp),"delayed story time scaling applied once")
	late.setup("standard_grunt",null,null)
	check(is_equal_approx(late.max_health,story_hp),"repeated setup does not compound scaling")
	check(GameManager.get_enemy_time_multipliers(0)==Vector2.ONE,"no early difficulty spike")
	check(GameManager.get_enemy_time_multipliers(1800)==GameManager.get_enemy_time_multipliers(900),"time scale capped after boss arrival")
	GameManager.selected_difficulty="hard"
	late.setup("ranged_spitter",null,null)
	check(is_equal_approx(late.magic_damage,35*1.5*1.65),"ranged damage includes correct time and difficulty factors")
	GameManager.selected_difficulty="story"
	early.free()
	late.free()
	check(Icons.WEAPONS["weapon_meow_meow"]!=Icons.WEAPONS["weapon_mega_blast"],"starter and megablast differ")
	for index in [36,37,38]: check(Icons.texture(index)!=null,"dedicated icon loads")
	check(Icons.texture(36)!=Icons.texture(37) and Icons.texture(37)!=Icons.texture(38),"ultimate has independent graphic")
	if OS.get_cmdline_user_args().has("--capture"):
		var saved_weapons = player.weapon_controller.equipped_weapons.duplicate()
		player.weapon_controller.equipped_weapons.clear()
		player.weapon_controller.add_weapon("weapon_meow_meow")
		player.weapon_controller.add_weapon("weapon_mega_blast")
		var original_level := GameManager.team_level
		GameManager.team_level=6
		for frame in 4:
			await get_tree().process_frame
			RenderingServer.force_draw(false,1.0/60)
		get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/distinct-weapon-icons.png")
		player.weapon_controller.equipped_weapons.assign(saved_weapons)
		GameManager.team_level=original_level
	# Force the former global merge budget, without manufacturing gameplay drops.
	var budget_nodes: Array[Node] = []
	for index in 600:
		var placeholder := Node.new()
		world.add_child(placeholder)
		placeholder.add_to_group("pickups")
		budget_nodes.append(placeholder)
	DropManager.spawn_exp_orb(world,Vector2(0,0),2)
	await get_tree().process_frame
	DropManager.spawn_exp_orb(world,Vector2(1500,0),4)
	await get_tree().process_frame
	var orbs: Array[DropItem] = []
	for item in get_tree().get_nodes_in_group("pickups"):
		if item is DropItem and item.item_type==DropItem.ItemType.EXP_ORB: orbs.append(item)
	check(orbs.size()==2,"budget cannot teleport remote XP into one nearby orb")
	var sum := 0
	for orb in orbs: sum+=orb.value
	check(sum==6,"merging conserves generated XP")
	for placeholder in budget_nodes: placeholder.free()
	player.passives.clear()
	player.augments.clear()
	player.recalculate_stats()
	var vacuum = load("res://scenes/combat/drop_item.tscn").instantiate()
	world.add_child(vacuum)
	vacuum.setup(DropItem.ItemType.VACUUM,1)
	vacuum._collect(player)
	check(orbs.all(func(orb): return orb.is_attracted and orb.attraction_reason=="Magnet"),"magnet attracts existing XP with recorded source")
	for orb in orbs:
		orb._collect(player)
		orb._collect(player)
	check(GameManager.total_xp_collected==6 and GameManager.team_level==2,"magnet credits exact XP once")
	check(world.hud.xp_batch==6,"HUD explains magnet XP amount")
	await drain(world)
	var total_before := GameManager.total_xp_collected
	for index in 100:
		var orb = load("res://scenes/combat/drop_item.tscn").instantiate()
		world.add_child(orb)
		orb.setup(DropItem.ItemType.EXP_ORB,1)
		orb.start_attraction(player,"Magnet")
		orb._collect(player)
		orb._collect(player)
	check(GameManager.total_xp_collected-total_before==100,"large vacuum burst has no duplicated or invented XP")
	check(GameManager.team_level==5 and GameManager.current_team_exp==29,"magnet uses exact tuned early costs without losing or inventing XP")
	await drain(world)
	GameManager.return_to_menu()
	world.free()
	# Real GUI routing: click the result button in an actual paused scene.
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size=resolution
		GameManager.start_new_run("map_warehouse","story")
		GameManager.practice_mode=true
		var scene = load("res://scenes/game/game_world.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene=scene
		freeze_world(scene)
		GameManager.end_run(false)
		for frame in 3: await get_tree().process_frame
		var button: Button = scene.game_over_screen.return_button
		check(button.is_visible_in_tree() and button.can_process(),"defeat button active while paused")
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(button.get_global_rect()),"defeat button fits small window")
		var at := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position=at
		get_viewport().push_input(motion,true)
		for pressed in [true,false]:
			var click := InputEventMouseButton.new()
			click.button_index=MOUSE_BUTTON_LEFT
			click.position=at
			click.pressed=pressed
			get_viewport().push_input(click,true)
		for frame in 5: await get_tree().process_frame
		check(get_tree().current_scene.scene_file_path=="res://scenes/ui/main_menu.tscn","mouse click returns to main menu")
		check(not get_tree().paused and GameManager.current_state==GameManager.GameState.MENU,"return clears paused state")
		if OS.get_cmdline_user_args().has("--capture") and resolution.x==1280:
			RenderingServer.force_draw(false,1.0/60)
			get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/returned-main-menu.png")
		get_tree().current_scene.free()
		get_tree().current_scene=null
	QuestManager.flush()
	ProfileManager.player_slots=original_slots
	SaveManager.delete_profile(temporary_id)
	get_window().size=original_size
	get_window().content_scale_size=original_scale
	GameManager.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROGRESSION FOLLOWUP: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("PROGRESSION FOLLOWUP PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)


extends Node
const Balance = preload("res://scripts/game/warehouse_balance.gd")
const Timeline = preload("res://scripts/game/warehouse_timeline.gd")
var checks := 0
var failures: Array[String] = []
var test_id := "warehouse_coop_"+str(Time.get_ticks_usec())

class SimEnemy extends RefCounted:
	var exp_drop := 0
	var is_elite := false
	var drops_access_card := false
	var enemy_id := ""

class SimSpawner extends RefCounted:
	var active_enemies: Array = []
	var max_concurrent_enemies := 550
	func valid_spawn() -> Vector2: return Vector2(300,300)
	func safe_position(point: Vector2) -> Vector2: return point
	func _get_players_center() -> Vector2: return Vector2.ZERO
	func _spawn_single_enemy(id: String, _point: Vector2, reserve: int = 0):
		if active_enemies.size()>=max_concurrent_enemies+reserve: return null
		var enemy := SimEnemy.new()
		enemy.enemy_id=id
		active_enemies.append(enemy)
		return enemy

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func slots(count: int) -> void:
	for i in 4: ProfileManager.player_slots[i]["active"]=i<count

func run_tests() -> void:
	var original := ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Coop"))
	for i in 4:
		ProfileManager.player_slots[i]["profile_id"]=test_id
		ProfileManager.player_slots[i]["character_id"]="jankz"
		ProfileManager.player_slots[i]["device_id"]=-1 if i==0 else i-1
	# The actual wave scheduler, without terrain/physics, across all twelve modes.
	for difficulty in ["story","hard","extreme"]:
		var baseline := 0
		for count in range(1,5):
			slots(count)
			GameManager.start_new_run("map_warehouse",difficulty)
			GameManager.practice_mode=true
			var timeline := Timeline.new()
			var spawner := SimSpawner.new()
			var minibosses := 0
			var elites := 0
			var normal := 0
			var xp := 0
			var late := 0
			for second in 900:
				GameManager.game_time=second
				timeline.tick(spawner,1.0)
				for enemy in spawner.active_enemies:
					if enemy.enemy_id=="mini_boss": minibosses+=1
					elif enemy.drops_access_card: elites+=1
					else:
						normal+=1
						xp+=GameManager.normalized_warehouse_xp(enemy.exp_drop,1.0/Balance.density(count))
						if second>=840: late+=1
				spawner.active_enemies.clear()
			if count==1: baseline=normal
			check(minibosses==8 and elites==5,"fixed thirteen card-bearing encounters: "+difficulty+" / "+str(count))
			check(absf(float(normal)/maxi(1,baseline)-Balance.density(count))<0.04,"normal density scales sublinearly: "+difficulty+" / "+str(count))
			check(late>=1100*Balance.density(count),"final minute stays dense: "+difficulty+" / "+str(count))
			check(xp>0,"normalized XP remains available")
			var density := Balance.density(count)
			check(density*Balance.hp(count,"standard_grunt")<=count+0.01,"normal HP budget no longer multiplies past team size")
			GameManager.warehouse_xp_carry=0
			var credited := 0
			for kill in 1000: credited+=GameManager.normalized_warehouse_xp(1,1.0/density)
			check(absf(credited-1000.0/density)<1.0,"fractional normal XP never rounds away or duplicates")
			var untouched := GameManager.warehouse_xp_carry
			check(GameManager.normalized_warehouse_xp(0,1.0/density)==0 and untouched==GameManager.warehouse_xp_carry,"zero-XP trial enemies do not spend fractional XP")
			var attack := Balance.reksai_attack(difficulty,true)
			# Base walking, 250 ms reaction, large body and an additional safety margin.
			check((float(attack["warmup"])-0.25)*350*0.342>float(attack["radius"])+26*0.55*1.3+8,"phase-two warning can be escaped without dash: "+difficulty)
			GameManager.start_new_run("map_warehouse",difficulty)
			check(GameManager.warehouse_xp_carry==0.0,"new run clears fractional enemy XP")
	# Real enemy HP, central caps and actual death/drop/collection path.
	slots(4)
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode=true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	var spawner = map.spawner
	spawner.set_physics_process(false)
	map.set_process(false)
	map.get_node("EventDirector").set_process(false)
	for player in GameManager.active_player_nodes:
		player.set_physics_process(false)
		player.weapon_controller.set_process(false)
	var player = GameManager.active_player_nodes[0]
	player.set_meta("god_mode",true)
	for character in CharacterRegistry.characters:
		var speed: float = CharacterRegistry.get_character_data(character)["base_stats"]["movement_speed"]
		for difficulty in ["story","hard","extreme"]:
			for second_phase in [false,true]:
				var spec := Balance.reksai_attack(difficulty,second_phase)
				check((float(spec["warmup"])-0.25)*speed*0.342>float(spec["radius"])+26*0.55*1.3+8,"base movement escape for "+character+" / "+difficulty+" / "+str(second_phase))
	for location in [Vector2(-1000,-650),Vector2(850,450),Vector2(120,1120),Vector2(1630,1150)]:
		var origin: Vector2 = map.get_safe_position(location,20)
		var escape := false
		for sector in 32:
			var direction := Vector2.from_angle(TAU*sector/32)
			var clear := true
			for step in 9:
				if not map.layout.is_clear(origin+direction*98*float(step)/8,18.6): clear=false
			if clear: escape=true
		check(escape,"unbuffed escape route exists at sampled park/industry/coast point "+str(location))
	for id in ["standard_grunt","mini_boss","elite_variant"]:
		var enemy = spawner._spawn_single_enemy(id,spawner.valid_spawn())
		check(is_instance_valid(enemy),"real enemy spawns: "+id)
		if not is_instance_valid(enemy): continue
		check(is_equal_approx(enemy.max_health,float(EnemyRegistry.get_enemy_data(id)["max_health"])*Balance.hp(4,id)),"real enemy uses role-specific HP: "+id)
		check(enemy.has_meta("warehouse_normal_xp_scale")== (id=="standard_grunt"),"only normal enemies normalize XP")
		enemy.free()
	spawner.active_enemies.clear()
	spawner.max_concurrent_enemies=0
	check(spawner._spawn_single_enemy("standard_grunt",spawner.valid_spawn())==null,"internal spawns cannot bypass normal cap")
	var special = spawner._spawn_single_enemy("mini_boss",spawner.valid_spawn(),48)
	check(is_instance_valid(special),"required special can use reserved capacity")
	if is_instance_valid(special): special.free()
	spawner.active_enemies.clear()
	spawner.max_concurrent_enemies=550
	GameManager.warehouse_xp_carry=0
	for kill in 5:
		var enemy = spawner._spawn_single_enemy("standard_grunt",spawner.valid_spawn())
		enemy.exp_drop=1
		enemy.gold_drop=0
		enemy.status_effects.update(2.0)
		DamageSystem.apply_damage({},enemy,1e9,false,player,"true")
	for frame in 3: await get_tree().process_frame
	var collected := 0
	for item in get_tree().get_nodes_in_group("pickups"):
		if item.item_type==0:
			collected+=item.value
			item._collect(player)
	check(collected==2 and GameManager.total_xp_collected==2,"five real four-player kills produce and credit two XP, not five")
	# Cancellation owns the warning and damage together; no autonomous delayed hit.
	GameManager.spawn_map_boss()
	var boss = GameManager.current_boss_node
	boss.set_physics_process(false)
	boss.status_effects.update(2.0)
	check(is_equal_approx(boss.max_health,float(EnemyRegistry.get_enemy_data("boss_reksai")["max_health"])*Balance.hp(4,"boss_reksai")),"boss has its own team HP scaling")
	boss._execute_boss_attack()
	var warning = boss.pending_attack_effect
	check(is_instance_valid(warning) and warning.config["radius"]==72 and warning.config["requires_commit"],"real boss uses exact painted radius and explicit attack commitment")
	var locked: Vector2 = warning.global_position
	player.global_position+=Vector2(100,0)
	check(warning.global_position==locked,"warning never chases moving player")
	if OS.get_cmdline_user_args().has("--capture"):
		warning.age=0.7
		for frame in 4: await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
		get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/coop-boss-warning.png")
	boss.status_effects.apply_effect("stun",2.0)
	boss._physics_process(0)
	check(not boss.is_telegraphing and warning.done and not warning.config.get("committed",false),"stun cancels both delayed hit and burrow")
	for frame in 100: await get_tree().process_frame
	check(not is_instance_valid(warning),"cancelled warning cannot return after old timer")
	boss.status_effects._active_effects.clear()
	for ally in GameManager.active_player_nodes:
		ally.global_position=player.global_position
		ally.set_meta("god_mode",true)
	boss._execute_boss_attack()
	var committed = boss.pending_attack_effect
	committed.set_physics_process(false)
	for frame in 100: await get_tree().process_frame
	check(is_instance_valid(committed) and committed.config["committed"] and not boss.is_telegraphing,"legitimate boss timer commits exactly the announced attack")
	for projectile in get_tree().get_nodes_in_group("projectiles"): projectile.free()
	player.set_meta("god_mode",false)
	player.damage_grace=0
	player.current_health=1000000
	player.current_shield=0
	var hp_before: float = player.current_health
	committed.age=float(committed.config["warmup"])
	committed._physics_process(0)
	var hp_after: float = player.current_health
	committed._damage_tick("area")
	check(hp_after<hp_before and player.current_health==hp_after,"committed impact damages a player once, never per animation frame")
	boss._execute_boss_attack()
	var interrupted = boss.pending_attack_effect
	boss._trigger_phase_transition()
	check(interrupted.done and not interrupted.config.get("committed",false),"phase change cancels the old attack before the new phase")
	boss.status_effects._active_effects.clear()
	boss._execute_boss_attack()
	var just_committed = boss.pending_attack_effect
	just_committed.config["committed"]=true
	boss.is_telegraphing=false
	boss._trigger_phase_transition()
	check(just_committed.done,"phase change also cancels the gap between timer commitment and the first effect tick")
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=original
	SaveManager.delete_profile(test_id)
	GameManager.set_process(true)
	await get_tree().process_frame
	print("WAREHOUSE COOP: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("WAREHOUSE COOP PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

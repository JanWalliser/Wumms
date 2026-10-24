extends Node

var checks := 0
var failures: Array[String] = []
var temporary_id := "weapon_rework_"+str(Time.get_ticks_usec())

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void:
	call_deferred("run_tests")

func clear_combat() -> void:
	for group in ["projectiles","runtime_effects"]:
		for node in get_tree().get_nodes_in_group(group): node.free()

func owned_projectiles(player: Node2D) -> Array:
	return get_tree().get_nodes_in_group("projectiles").filter(func(node): return node.source_owner==player and not node.is_queued_for_deletion())

func expected_e_direction(aim: Vector2, index: int) -> Vector2:
	var lane := floori(index/2.0)
	var angle := -22.5+22.5*lane
	if index%2==1: angle+=-11.25 if lane==2 else 11.25
	return aim.normalized().rotated(deg_to_rad(angle))

func run_tests() -> void:
	var slots := ProfileManager.player_slots.duplicate(true)
	var old_size := get_window().size
	var old_scale := get_window().content_scale_size
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=Vector2i(1920,1080)
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	SaveManager.save_profile(SaveManager.create_default_profile(temporary_id,"Weapon rework"))
	for index in 4:
		ProfileManager.player_slots[index]["active"]=index==0
		ProfileManager.player_slots[index]["profile_id"]=temporary_id
		ProfileManager.player_slots[index]["device_id"]=-1
		ProfileManager.player_slots[index]["character_id"]="jankz"
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode=true
	GameManager.set_process(false)
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	map.spawner.set_physics_process(false)
	map.get_node("EventDirector").set_process(false)
	map.set_process(false)
	var player = GameManager.active_player_nodes[0]
	player.set_physics_process(false)
	player.weapon_controller.set_process(false)
	player.global_position=map.get_safe_position(Vector2(0,850),24)
	map.camera.position=player.global_position
	map.camera._process(1)
	map.camera.set_process(false)
	for frame in 2: await get_tree().process_frame
	var enemy = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position=player.global_position+Vector2(-100,0)
	enemy.max_health=100000
	enemy.current_health=100000
	enemy.armor=0
	var second = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	world.add_child(second)
	second.set_physics_process(false)
	second.global_position=enemy.global_position+Vector2(-20,0)
	second.max_health=100000
	second.current_health=100000
	second.armor=0
	InputManager.auto_aim_states[0]=true
	var desired := Vector2(200,-80)
	var mouse := InputEventMouseMotion.new()
	mouse.position=get_viewport().get_canvas_transform()*(player.global_position+desired)
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--debug-aim"):
		print("AIM TEST: mouse event=",mouse.position," viewport=",get_viewport().get_mouse_position()," player=",player.global_position," direction=",player.get_ability_aim_direction()," transform=",get_viewport().get_canvas_transform())
	check(player.get_aim_direction().x<0,"weapon auto aim still targets nearby enemy")
	check(player.get_ability_aim_direction().dot(desired.normalized())>0.999,"active aim follows mouse despite auto aim")
	player._activate_ability_e()
	check(owned_projectiles(player).size()==1 and player.pending_jinx_abilities.size()==5,"E starts immediately and queues five individual rockets")
	player._tick_jinx_abilities(0.119)
	check(owned_projectiles(player).size()==1,"second rocket is staggered rather than simultaneous")
	player._tick_jinx_abilities(0.002)
	check(owned_projectiles(player).size()==2,"left pair releases after 120 milliseconds")
	var second_rocket = owned_projectiles(player)[1]
	check(is_equal_approx(second_rocket.initial_pos.distance_to(player.visual_animator.muzzle_position()),5.0),"second rocket starts five units beside the current muzzle")
	# A later cursor change must not rotate the already committed sweep.
	mouse=InputEventMouseMotion.new()
	mouse.position=get_viewport().get_canvas_transform()*(player.global_position-desired)
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	player._tick_jinx_abilities(0.198)
	check(owned_projectiles(player).size()==2,"left pair finishes before the centre lane starts")
	player._tick_jinx_abilities(0.002)
	check(owned_projectiles(player).size()==3,"centre lane starts at 320 milliseconds")
	player._tick_jinx_abilities(0.119)
	check(owned_projectiles(player).size()==4,"centre pair follows in order")
	player._tick_jinx_abilities(0.199)
	check(owned_projectiles(player).size()==4,"right lane waits for its own release")
	player._tick_jinx_abilities(0.002)
	check(owned_projectiles(player).size()==5,"right lane starts at 640 milliseconds")
	player._tick_jinx_abilities(0.119)
	check(owned_projectiles(player).size()==6 and player.pending_jinx_abilities.is_empty(),"sixth rocket completes the sweep at 760 milliseconds")
	var sweep := owned_projectiles(player)
	for index in sweep.size():
		var expected := expected_e_direction(desired,index)
		check(sweep[index].direction.dot(expected)>0.99999,"E retains saved cursor aim with half-lane offsets on second rockets")
	for projectile in owned_projectiles(player):
		check(projectile.direction.dot(desired.normalized())>=cos(deg_to_rad(22.5))-0.0001,"E stays within the narrow 45 degree cursor fan")
		check(is_equal_approx(projectile.speed,576),"E flight speed is reduced by twenty percent from 720")
		check(is_equal_approx(projectile.aoe_radius,60) and is_equal_approx(projectile.max_travel_distance,440) and is_equal_approx(projectile.damage,55),"E keeps damage, explosion radius and range")
	player._tick_jinx_abilities(1)
	check(owned_projectiles(player).size()==6,"completed E does not emit a duplicate delayed volley")
	clear_combat()
	player._spawn_rockets(desired.normalized(),6,55)
	player._queue_jinx_ability("r")
	player._tick_jinx_abilities(1)
	var caught_up := owned_projectiles(player)
	check(caught_up.size()==7 and player.pending_jinx_abilities.is_empty(),"one long frame releases the complete E sweep and independently charged R exactly once")
	for index in mini(6,caught_up.size()):
		var expected := expected_e_direction(desired,index)
		# R charges for 0.5s and now legitimately releases before the final E pair.
		var projectile_index := index if index<4 else index+1
		check(caught_up[projectile_index].direction.dot(expected)>0.99999,"long frame preserves chronological lane order alongside R")
	clear_combat()
	player._spawn_rockets(desired.normalized(),10,55)
	player._tick_jinx_abilities(2)
	check(owned_projectiles(player).size()==10 and player.pending_jinx_abilities.is_empty(),"bonus projectiles join the staggered lanes without duplication")
	clear_combat()
	player._spawn_rockets(desired.normalized(),6,55)
	player.is_downed=true
	player._tick_jinx_abilities(1)
	player.is_downed=false
	player._tick_jinx_abilities(1)
	check(owned_projectiles(player).size()==1 and player.pending_jinx_abilities.is_empty(),"downing cancels remaining E shots across revival")
	clear_combat()
	player._spawn_rockets(desired.normalized(),6,55)
	var saved_run: String = GameManager.run_id
	GameManager.run_id="other_run_for_E_test"
	player._tick_jinx_abilities(1)
	GameManager.run_id=saved_run
	check(owned_projectiles(player).size()==1 and player.pending_jinx_abilities.is_empty(),"old run cannot release a queued sweep")
	clear_combat()
	player._spawn_rockets(desired.normalized(),6,55)
	player.life_generation+=1
	player._tick_jinx_abilities(1)
	check(owned_projectiles(player).size()==1,"old life cannot release a queued sweep after revival")
	mouse=InputEventMouseMotion.new()
	mouse.position=get_viewport().get_canvas_transform()*(player.global_position+desired)
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	clear_combat()
	player._activate_ability_r()
	check(owned_projectiles(player).is_empty(),"R respects its windup")
	player._tick_jinx_abilities(0.49)
	check(owned_projectiles(player).is_empty(),"R does not fire before half a second")
	player._tick_jinx_abilities(0.011)
	check(owned_projectiles(player).size()==1 and owned_projectiles(player)[0].direction.dot(desired.normalized())>0.999,"R rocket follows cursor instead of enemy")
	if not owned_projectiles(player).is_empty():
		var ultimate = owned_projectiles(player)[0]
		check(is_equal_approx(ultimate.speed,800),"R travels at twice the previous speed")
		check(is_equal_approx(ultimate.missile_display_width,132*0.8),"R artwork is 80 percent of the previous size")
		check(is_equal_approx(ultimate.aoe_radius,120) and is_equal_approx(ultimate.max_travel_distance,400) and is_equal_approx(ultimate.damage,500),"R keeps damage, explosion radius and range")
	player._tick_jinx_abilities(1)
	check(owned_projectiles(player).size()==1 and player.pending_jinx_abilities.is_empty(),"R releases exactly once")
	clear_combat()
	player._spawn_solar_flare()
	for effect in get_tree().get_nodes_in_group("runtime_effects"):
		check(effect.global_position.distance_to(player.global_position+desired)<0.1,"ground ultimate uses mouse position")
	clear_combat()
	player.passives.clear()
	player.augments.clear()
	player.recalculate_stats()
	player.current_stats["crit_chance"]=0
	var uwu := WeaponInstance.new("weapon_uwu_blaster",player)
	var hp: float = enemy.current_health
	uwu.fire()
	check(enemy.current_health==hp,"UwU never applies instant beam damage")
	check(get_tree().get_nodes_in_group("runtime_effects").all(func(effect): return effect.config.get("visual","")=="uwu_emitter" and effect.config.get("damage",0)==0),"UwU emitter is cosmetic and creates no damage beam")
	var bullets := owned_projectiles(player)
	check(bullets.size()==1 and bullets[0].movement_pattern==Projectile.MovementPattern.STRAIGHT,"UwU launches a travelling projectile")
	check(bullets[0].direction.x<0 and bullets[0].speed==400,"UwU automatically targets nearest enemy in map units")
	bullets[0]._handle_target_hit(enemy)
	bullets[0]._handle_target_hit(enemy)
	bullets[0]._handle_target_hit(second)
	check(enemy.current_health==hp-45,"UwU impact applies base damage once")
	check(second.current_health==100000,"UwU cannot pierce a second target")
	clear_combat()
	uwu.level=5
	uwu.evolve()
	uwu.fire()
	check(owned_projectiles(player).size()==1 and uwu.pending_shots.size()==2,"OwO burst queues individual shots")
	uwu._tick_pending(0.034)
	check(owned_projectiles(player).size()==2,"second shot is released after its delay")
	uwu._tick_pending(0.034)
	check(owned_projectiles(player).size()==3 and uwu.pending_shots.is_empty(),"burst emits exactly three shots")
	check(uwu.get_effective_cooldown()==0.25 and uwu.get_damage()==65,"OwO cooldown and damage match reference")
	uwu.fire()
	var burst_id: String = uwu.pending_shots[0]["attack_id"]
	uwu.casts+=1
	uwu._tick_pending(0.1)
	check(owned_projectiles(player)[-1].attacker_stats["attack_id"]==burst_id,"delayed shots preserve original cast ownership")
	clear_combat()
	uwu.fire()
	player.is_downed=true
	uwu._tick_pending(0.1)
	check(uwu.pending_shots.is_empty(),"downed player cannot retain delayed shots")
	player.is_downed=false
	clear_combat()
	var bow := WeaponInstance.new("weapon_shortbow",player)
	bow.fire()
	var arrow = owned_projectiles(player)[0]
	check(arrow.ground_target.is_finite(),"shortbow selects a landing position")
	arrow.ground_target=enemy.global_position # Fix the landing for this damage test; real casts choose random zones.
	hp=enemy.current_health
	arrow._handle_target_hit(enemy)
	check(enemy.current_health==hp,"airborne ground arrow does not double-hit enemies")
	arrow._physics_process(0.51)
	check(get_tree().get_nodes_in_group("ground_hazards").size()==1,"landing creates a visible fire hazard")
	var fire = get_tree().get_nodes_in_group("ground_hazards")[0]
	fire._damage_tick("area")
	check(enemy.current_health==hp-20,"fire tick uses half the reference DPS without extra direct or splash damage")
	bow.fire()
	owned_projectiles(player)[0].ground_target=fire.global_position
	owned_projectiles(player)[0]._physics_process(0.51)
	check(get_tree().get_nodes_in_group("ground_hazards").size()==1,"overlapping fire pools refresh rather than multiply")
	clear_combat()
	var lioness := WeaponInstance.new("weapon_lioness",player)
	player.current_health=500
	lioness.fire()
	check(player.current_health==500,"Lioness has no invented healing effect")
	lioness._tick_pending(0.53)
	bullets=owned_projectiles(player)
	check(bullets.size()==6 and bullets[0].direction.x*bullets[-1].direction.x<0,"Lioness alternates left and right with three paths per crescent")
	clear_combat()
	var gatling := WeaponInstance.new("weapon_gatling",player)
	gatling.fire()
	gatling.fire()
	check(get_tree().get_nodes_in_group("runtime_effects").size()==1,"gatling cannot overlap its own active barrage")
	check(gatling.effect_node.config["mode"]=="cone" and gatling.effect_node.config["interval"]==0.25,"gatling uses archived four ticks per second")
	player.current_stats["crit_chance"]=1
	hp=enemy.current_health
	gatling.effect_node._damage_tick("cone")
	check(enemy.current_health==hp-15,"gatling cannot critically strike")
	gatling.update(4)
	check(gatling.cooldown_timer==5,"gatling cooldown waits for barrage end")
	clear_combat()
	var slicers := WeaponInstance.new("weapon_slicers",player)
	slicers.fire()
	slicers.fire()
	check(owned_projectiles(player).size()==2,"slicers cannot duplicate their orbit ring")
	var razor = owned_projectiles(player)[0]
	hp=enemy.current_health
	razor._handle_target_hit(enemy)
	razor.elapsed_time=0.3
	razor._handle_target_hit(enemy)
	check(enemy.current_health==hp-55,"razor cannot damage same enemy twice in one revolution or crit")
	razor.elapsed_time=TAU/2.5+0.01
	var previous_time := GameManager.game_time
	GameManager.game_time+=TAU/2.5+0.01
	razor._handle_target_hit(enemy)
	check(enemy.current_health==hp-110,"razor can hit again on next revolution")
	GameManager.game_time=previous_time
	clear_combat()
	slicers.evolve()
	slicers.fire()
	check(owned_projectiles(player)[0].lifetime>10000,"evolved slicers persist instead of expiring after four seconds")
	slicers.fire()
	check(owned_projectiles(player).size()==6,"persistent evolved slicers cannot duplicate")
	clear_combat()
	player.current_stats["crit_chance"]=0
	var aura := WeaponInstance.new("weapon_radiant_field",player)
	aura.fire()
	aura.fire()
	check(get_tree().get_nodes_in_group("runtime_effects").size()==1,"radiant field stays a single aura")
	check(is_equal_approx(aura.effect_node.config["radius"],44),"aura range uses original-to-map conversion")
	player.passives={"ability_haste":5,"duration":5}
	player.recalculate_stats()
	check(aura.get_effective_cooldown()==0.5,"haste cannot amplify fixed aura tick rate")
	clear_combat()
	uwu=WeaponInstance.new("weapon_uwu_blaster",player)
	uwu.fire()
	check(is_equal_approx(owned_projectiles(player)[0].lifetime,0.6),"duration does not inflate UwU projectile range")
	for passive in PassiveRegistry.get_all_passive_ids():
		check(PassiveRegistry.get_bonus(passive,99)==PassiveRegistry.get_bonus(passive,5),"passive level ceiling "+passive)
		check(PassiveRegistry.get_bonus(passive,-5)==0,"passive negative rank "+passive)
	check(PassiveRegistry.get_bonus("projectile_count",2)==1 and PassiveRegistry.get_bonus("projectile_count",5)==3,"projectile passive uses original stepped table")
	var stats: Dictionary = StatCalculator.compute_player_stats(player.base_stats,{}, {"damage":99,"duration":99},[],{})
	check(is_equal_approx(stats["damage_multiplier"],1.5) and is_equal_approx(stats["duration_multiplier"],1.6),"passive bonuses do not exceed level five")
	clear_combat()
	check_jinx_passive(player)
	preload("res://tests/weapon_reference_checks.gd").run(player,self,enemy,second)
	preload("res://tests/arsenal_checks.gd").run(player,self,enemy,second)
	preload("res://tests/jinx_item_checks.gd").run(player,self,enemy)
	preload("res://tests/early_progression_checks.gd").run(player,self,enemy)
	preload("res://tests/enemy_pacing_checks.gd").run(player,self,enemy)
	preload("res://tests/actor_animation_checks.gd").run(player,self,enemy)
	preload("res://tests/jinx_directional_checks.gd").run(player,self)
	preload("res://tests/arsenal_vfx_checks.gd").run(player,self,enemy)
	if OS.get_cmdline_user_args().has("--capture"):
		await preload("res://tests/actor_animation_checks.gd").capture(player,self)
		await preload("res://tests/arsenal_vfx_checks.gd").capture(player,self)
		await capture_arsenal(player)
		await capture_rockets(player)
		await capture_effects(player)
		await preload("res://tests/jinx_item_checks.gd").capture(self)
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=slots
	SaveManager.delete_profile(temporary_id)
	GameManager.set_process(true)
	get_window().size=old_size
	get_window().content_scale_size=old_scale
	await get_tree().process_frame
	print("WEAPON REWORK: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("WEAPON REWORK PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

func check_jinx_passive(player: PlayerController) -> void:
	var old_time := GameManager.game_time
	var old_passives := player.passives.duplicate()
	var old_augments := player.augments.duplicate()
	player.passives.clear()
	player.augments.clear()
	player.temp_buffs.clear()
	player._reset_jinx_passive()
	player.recalculate_stats()
	var baseline := player.get_stat("movement_speed")
	var baseline_haste := player.get_stat("ability_haste")
	for i in 69:
		var victim := Enemy.new()
		player.on_combat_kill(victim)
		player.on_combat_kill(victim)
		victim.free()
	check(player.jinx_kills==69 and not player.is_jinx_excited(),"passive counts unique kills, not duplicate callbacks")
	var trigger := Enemy.new()
	player.on_combat_kill(trigger)
	trigger.free()
	check(player.jinx_kills==0 and player.is_jinx_excited(),"exactly seventy kills trigger passive and reset progress")
	check(is_equal_approx(player.get_stat("ability_haste"),baseline_haste+150),"passive haste is available immediately")
	check(is_equal_approx(player.get_stat("movement_speed"),baseline+float(player.base_stats.get("movement_speed",350))*0.35),"passive adds one base-speed bonus")
	GameManager.game_time+=4
	player._update_jinx_passive()
	check(is_equal_approx(player.get_stat("movement_speed"),baseline+float(player.base_stats.get("movement_speed",350))*0.175),"passive movement decays halfway at four seconds")
	var elite := Enemy.new()
	elite.is_elite=true
	player.on_combat_kill(elite)
	player.on_combat_kill(elite)
	elite.free()
	check(is_equal_approx(player.jinx_passive_remaining(),8) and player.get_stat("ability_haste")==baseline_haste+150,"elite refresh resets lifetime without stacking haste")
	GameManager.game_time+=8
	player._update_jinx_passive()
	check(not player.is_jinx_excited() and is_equal_approx(player.get_stat("movement_speed"),baseline) and player.get_stat("ability_haste")==baseline_haste,"expiry removes both bonuses immediately")
	player.jinx_excited_until=GameManager.game_time+8
	player._update_jinx_passive()
	player.is_downed=true
	player._reset_jinx_passive()
	player.recalculate_stats()
	player.is_downed=false
	check(not player.is_jinx_excited() and player.jinx_kills==0 and is_equal_approx(player.get_stat("movement_speed"),baseline),"downed reset does not restore passive on revival")
	var converted := StatCalculator.compute_player_stats({"movement_speed":350},{"movement_speed":4},{"movement_speed":5,"ability_haste":2},["augment_with_haste"],{"ability_haste":150,"jinx_speed_pct":0.35})
	var expected := 350.0*1.2*1.45+350.0*170*0.005+350.0*0.35
	check(is_equal_approx(converted["movement_speed"],expected),"haste conversion and passive cannot multiply shop/passive movement bonuses")
	GameManager.game_time=old_time
	player._reset_jinx_passive()
	player.passives=old_passives
	player.augments.assign(old_augments)
	player.recalculate_stats()
	var pickup = load("res://scenes/combat/drop_item.tscn").instantiate()
	pickup.item_type=DropItem.ItemType.HEALTH_PACK
	player.get_parent().add_child(pickup)
	pickup.set_physics_process(false)
	pickup.global_position=player.global_position+Vector2(200,0)
	pickup.start_attraction(player)
	pickup.magnet_speed=12000
	pickup._physics_process(0.25)
	check(pickup.collected and pickup.global_position.is_equal_approx(player.global_position),"fast vacuum pickups arrive once instead of oscillating around the player")

func capture_arsenal(player: Node2D) -> void:
	player.current_stats["damage_multiplier"]=1
	player.current_stats["bonus_projectiles"]=0
	player.current_stats["area_multiplier"]=1
	player.current_stats["duration_multiplier"]=1
	for number in get_tree().get_nodes_in_group("damage_numbers"): number.free()
	for id in WeaponRegistry.weapons.keys():
		for evolved in [false,true]:
			clear_combat()
			var weapon := WeaponInstance.new(id,player)
			weapon.level=5
			weapon.is_evolved=evolved
			weapon.fire()
			if id=="weapon_iceblast": weapon.consume_iceblast()
			for projectile in owned_projectiles(player):
				projectile.set_physics_process(false)
				projectile.elapsed_time=0.22
				if id=="weapon_crossbow": projectile.global_position+=projectile.direction*110
				if id=="weapon_uwu_blaster": projectile.global_position+=projectile.direction*75
				if id in ["weapon_blade_o_rang","weapon_batblades","weapon_lioness"]: projectile.global_position+=projectile.direction*80
				if id=="weapon_shortbow":
					projectile.global_position=projectile.initial_pos.lerp(projectile.ground_target,0.44)
					var flame := RuntimeEffect.spawn(player.get_parent(),player,projectile.ground_target,{"visual":"fire","radius":40 if not evolved else 65,"duration":5,"damage":0,"evolved":evolved,"scale_area":false})
					flame.age=1
					flame.set_physics_process(false)
			for effect in get_tree().get_nodes_in_group("runtime_effects"):
				effect.set_physics_process(false)
				var warmup := float(effect.config.get("warmup",0))
				var duration := float(effect.config.get("duration",1))
				effect.age=warmup+minf(0.12,(duration-warmup)*0.35) if warmup>0 else minf(0.8,duration*0.35)
				if id=="weapon_shortbow" and effect.config.get("visual","")=="landing": effect.hide()
				effect.queue_redraw()
			for frame in 4:
				await get_tree().process_frame
				RenderingServer.force_draw(false,1.0/60)
			get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/arsenal-"+id.trim_prefix("weapon_")+("-evolved" if evolved else "-level5")+".png")
	clear_combat()

func capture_rockets(player: Node2D) -> void:
	var pickup = load("res://scenes/combat/drop_item.tscn").instantiate()
	pickup.item_type=DropItem.ItemType.BOMB
	player.get_parent().add_child(pickup)
	pickup.global_position=player.global_position+Vector2(-70,-65)
	pickup.set_physics_process(false)
	check(not pickup.sprite.visible,"bomb pickup replaces the old black/red placeholder")
	player.jinx_kills=42
	for number in get_tree().get_nodes_in_group("damage_numbers"): number.free()
	player.current_health=player.get_stat("max_health")
	GameManager.team_level=6
	player.ability_e_cd=0
	player.ability_r_cd=0
	var rocket = player._spawn_jinx_rocket(Vector2(1,-0.1),500,"r")
	rocket.global_position=player.global_position+Vector2(75,-35)
	rocket.set_physics_process(false)
	for index in 5:
		var small = player._spawn_jinx_rocket(Vector2.from_angle(deg_to_rad(-22.5+index*11.25)),55,"e")
		small.global_position=player.global_position+Vector2(50+index*28,-145+index*12)
		small.set_physics_process(false)
	var splash := RuntimeEffect.spawn(player.get_parent(),player,player.global_position+Vector2(255,-30),{"visual":"rocket_explosion","radius":120,"duration":0.65,"damage":0,"scale_area":false,"scale_duration":false})
	splash.age=0.15
	splash.set_physics_process(false)
	splash.queue_redraw()
	for frame in 4:
		await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
	get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/jinx-rockets-ingame.png")
	player.jinx_kills=0
	player.jinx_excited_until=GameManager.game_time+8
	player._update_jinx_passive()
	for frame in 3:
		await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
	get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/jinx-passive-active.png")
	player._reset_jinx_passive()
	player.recalculate_stats()
	pickup.free()
	clear_combat()

func capture_effects(player: Node2D) -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1600,1000)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color=Color("111b26")
	background.size=Vector2(1600,1000)
	viewport.add_child(background)
	var samples := ["uwu","crescent","slicer","mine","fire","orbital","gatling","radiant","dark_vortex"]
	var titles := ["ÜwÜ: einzelne Energiekugel","Lichtsichel","Rotierende Klinge","Mine mit Vorwarnung","Feuerfläche am Einschlag","Orbitalschlag","Gatling: gerichtetes Sperrfeuer","Eine persistente Aura","Rotierender Energiestrom"]
	for index in samples.size():
		var center := Vector2(265+(index%3)*530,175+int(index/3)*325)
		var label := Label.new()
		label.text=titles[index]
		label.position=center+Vector2(-225,-130)
		label.add_theme_font_size_override("font_size",23)
		viewport.add_child(label)
		if index in [0,1,2,8]:
			var projectile = load("res://scenes/combat/projectile_base.tscn").instantiate()
			viewport.add_child(projectile)
			projectile.position=center
			projectile.setup(0,Vector2.RIGHT,0,0,1,1,player,{"weapon_id":"showcase"})
			projectile.visual_style=samples[index]
			projectile.elapsed_time=0.1
			projectile.scale=Vector2.ONE*3
			projectile.set_physics_process(false)
			projectile.queue_redraw()
		else:
			var effect := RuntimeEffect.new()
			effect.source=player
			effect.config={"visual":samples[index],"radius":90,"duration":2,"warmup":1.0 if index==3 else 0,"weapon_id":"weapon_gatling" if index==6 else "weapon_shortbow","cos_angle":cos(deg_to_rad(14)),"damage":0}
			effect.position=center
			viewport.add_child(effect)
			effect.age=0.45
			effect.set_physics_process(false)
			effect.queue_redraw()
	for frame in 4:
		await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
	viewport.get_texture().get_image().save_png("res://output/swarm-ui/weapon-rework-effects.png")
	viewport.free()


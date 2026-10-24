extends Node
const Rules = preload("res://scripts/progression/evolution_rules.gd")
var checks := 0
var failures: Array[String] = []
var profile_id := "evolution_test_"+str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false,1.0/60)
	get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/evolution-"+label+".png")

func run_tests() -> void:
	var old_slots := ProfileManager.player_slots.duplicate(true)
	var old_size := get_window().size
	var old_scale := get_window().content_scale_size
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=Vector2i(1920,1080)
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	var profile := SaveManager.create_default_profile(profile_id,"Evolution test")
	profile["unlocked_weapons"]=WeaponRegistry.get_general_weapon_ids()
	profile["unlocked_passives"]=PassiveRegistry.passives.keys()
	SaveManager.save_profile(profile)
	for i in 4:
		ProfileManager.player_slots[i]["active"]=i==0
		ProfileManager.player_slots[i]["profile_id"]=profile_id
		ProfileManager.player_slots[i]["character_id"]="jankz"
		ProfileManager.player_slots[i]["device_id"]=-1
	GameManager.start_new_run("map_warehouse","story")
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	world.current_map_node.spawner.set_physics_process(false)
	world.current_map_node.set_process(false)
	world.current_map_node.get_node("EventDirector").set_process(false)
	var player = GameManager.active_player_nodes[0]
	player.set_physics_process(false)
	player.weapon_controller.set_process(false)
	var wc = player.weapon_controller
	for id in WeaponRegistry.get_all_weapon_ids():
		wc.equipped_weapons.clear()
		player.passives.clear()
		var weapon := WeaponInstance.new(id,player)
		wc.equipped_weapons.append(weapon)
		var passive: String = weapon.data["evolution_requires"]
		check(PassiveRegistry.passives.has(passive),id+" has valid recipe")
		check(not Rules.weapon_state(player,id)["ready"],id+" needs both ingredients")
		weapon.level=5
		player.passives[passive]=0
		check(not wc.evolve_weapon(id),id+" zero passive rank rejected")
		player.passives[passive]=1
		weapon.level=4
		check(not wc.evolve_weapon(id),id+" rank four rejected")
		weapon.level=5
		check(Rules.weapon_state(player,id)["ready"],id+" rank one passive suffices")
		check(Rules.passive_matches(player,passive,true).has(id),id+" reverse recipe finds owned weapon")
		check(not LevelUpManager.generate_choices_for_player(player,false).any(func(c): return c["type"]=="evolution"),id+" normal levels cannot evolve")
		var offer := LevelUpManager.generate_choices_for_player(player,true)
		check(offer[0]["type"]=="evolution" and offer[0]["id"]==id,id+" access card prioritizes evolution")
		var reroll := LevelUpManager.generate_choices_for_player(player,true,[id,"evolution:"+id])
		check(reroll[0]["type"]=="evolution",id+" reroll retains ready evolution")
		check(not LevelUpManager.apply_choice_to_player(player,offer[0]),id+" application needs actual card event")
		weapon.cooldown_timer=1.37
		weapon.pending_shots.append({"delay":0.5})
		weapon.orbit_hit_times[123]=42.0
		var count_before := get_tree().get_nodes_in_group("projectiles").size()
		check(wc.evolve_weapon(id),id+" evolution accepted")
		check(wc.equipped_weapons.size()==1 and wc.equipped_weapons[0]==weapon and player.passives[passive]==1,id+" same slot and passive retained")
		check(weapon.cooldown_timer==1.37 and weapon.pending_shots.is_empty() and weapon.orbit_hit_times[123]==42.0,id+" cooldown and lockouts preserved, old queue cancelled")
		check(get_tree().get_nodes_in_group("projectiles").size()==count_before,id+" transformation grants no extra attack")
		check(not wc.evolve_weapon(id),id+" duplicate evolution rejected")
		check(not LevelUpManager.generate_choices_for_player(player,true).any(func(c): return c.get("type")=="evolution"),id+" evolved weapon leaves candidate pool")
	# Existing casts retain captured values, rather than transforming mid-flight.
	var gatling := WeaponInstance.new("weapon_gatling",player)
	gatling.level=5
	gatling.fire()
	var old_effect = gatling.effect_node
	var old_damage: float = old_effect.config["damage"]
	var old_duration: float = old_effect.config["duration"]
	old_effect.age=1.0
	old_effect.tick=0.08
	gatling.evolve()
	gatling.update(0)
	check(gatling.effect_node==old_effect and old_effect.age==1.0 and old_effect.tick==0.08 and old_effect.config["damage"]==old_damage and old_effect.config["duration"]==old_duration and not old_effect.config["evolved"],"active gatling cast retains damage, duration and tick phase")
	old_effect.queue_free()
	var slicers := WeaponInstance.new("weapon_slicers",player)
	slicers.level=5
	slicers.fire()
	var blade = slicers.orbit_nodes[0]
	blade.elapsed_time=2.0
	slicers.orbit_hit_times[123]=GameManager.game_time
	slicers.evolve()
	check(slicers.orbit_nodes.has(blade) and blade.elapsed_time==2.0 and slicers.orbit_nodes.size()==slicers.get_projectiles(),"orbit evolution reuses live blades and creates exactly required count")
	check(blade.damage_lockouts.has(123) and blade.lifetime>10000,"orbit evolution preserves shared hit lockout")
	for node in slicers.orbit_nodes: node.queue_free()
	# Five ready recipes remain simultaneously selectable, including after rerolls.
	wc.equipped_weapons.clear()
	player.passives.clear()
	for id in ["weapon_meow_meow","weapon_uwu_blaster","weapon_crossbow","weapon_shortbow","weapon_slicers"]:
		var weapon := WeaponInstance.new(id,player)
		weapon.level=5
		wc.equipped_weapons.append(weapon)
		player.passives[weapon.data["evolution_requires"]]=1
	var all_offers := LevelUpManager.generate_choices_for_player(player,true)
	check(all_offers.size()==5 and all_offers.all(func(c): return c["type"]=="evolution"),"all five ready weapons are visible")
	check(Rules.recipe_book(player).contains("Krawallkatzen-Kugelhagel"),"recipe book contains character weapon")
	var teammate := PlayerController.new()
	teammate.weapon_controller=WeaponController.new()
	teammate.add_child(teammate.weapon_controller)
	teammate.weapon_controller.host_player=teammate
	var teammate_weapon := WeaponInstance.new("weapon_meow_meow",teammate)
	teammate_weapon.level=5
	teammate.weapon_controller.equipped_weapons.append(teammate_weapon)
	check(not Rules.weapon_state(teammate,"weapon_meow_meow")["ready"],"teammate cannot borrow another player's evolution passive")
	teammate.free()
	GameManager.trigger_access_card()
	await get_tree().process_frame
	var modal = world.level_up_modal
	check(modal.player_choices_data[0].size()==5,"real card modal shows five evolution options")
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		get_window().size=resolution
		await get_tree().process_frame
		modal._rebuild_columns()
		for frame in 3: await get_tree().process_frame
		for button in modal.player_buttons[0]:
			check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(button.get_global_rect()),"five evolution cards fit "+str(resolution))
			check(button.get_node("Recipe").text.is_empty() and not button.get_node("Recipe").visible,"recipes have moved from cards to TAB")
		await capture("five-cards-"+str(resolution.x))
	var event: int = modal.event_id
	for count in [2,4]:
		var clones: Array[Node2D] = []
		for index in range(1,count):
			var clone := PlayerController.new()
			clone.player_slot_index=index
			clone.profile_id=profile_id
			clone.char_data=player.char_data
			clone.passives=player.passives.duplicate()
			clone.weapon_controller=WeaponController.new()
			clone.add_child(clone.weapon_controller)
			clone.weapon_controller.host_player=clone
			clone.weapon_controller.equipped_weapons=wc.equipped_weapons.duplicate()
			clones.append(clone)
			GameManager.active_player_nodes.append(clone)
		modal._rebuild_columns()
		for frame in 4: await get_tree().process_frame
		for slot in modal.player_buttons:
			for button in modal.player_buttons[slot]:
				check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(button.get_global_rect()),"five ready cards fit for "+str(count)+" players at 720p")
		await capture(str(count)+"-players")
		for clone in clones:
			GameManager.active_player_nodes.erase(clone)
			clone.free()
	modal._rebuild_columns()
	modal._reroll(0,event)
	check(modal.player_choices_data[0].size()==5,"real reroll preserves five ready evolutions")
	var evolved_before := GameManager.evolved_count
	modal._confirm_selection(0,4,event)
	modal._confirm_selection(0,4,event)
	check(GameManager.evolved_count==evolved_before+1 and wc.equipped_weapons[4].is_evolved,"one card evolves exactly the selected fifth weapon once")
	check(wc.equipped_weapons.size()==5 and player.passives.size()==4,"card consumes neither slot nor passive")
	world.hud._update_tab_stats()
	check(world.hud.tab_overlay.recipe_buttons.size()>20,"TAB displays the icon recipe book")
	await capture("hud-ready")
	# Normal selection: an owned weapon, a new weapon and a matching passive.
	get_window().size=Vector2i(1920,1080)
	for child in modal.columns_container.get_children():
		modal.columns_container.remove_child(child)
		child.queue_free()
	var recipes: Array[Dictionary] = [{"type":"weapon_upgrade","id":"weapon_meow_meow","title":"Miau-MG","sub":"WAFFE"},{"type":"new_weapon","id":"weapon_gatling","title":"Hasen-Hagelkanone","sub":"NEUE WAFFE"},{"type":"new_passive","id":"ability_haste","title":"Fähigkeitstempo","sub":"PASSIVE"}]
	modal.show()
	modal.columns_container.add_child(modal._create_player_column(player,recipes))
	await capture("recipes")
	modal.hide()
	wc.equipped_weapons[0].level=3
	wc.equipped_weapons[2].level=4
	player.passives.erase("ability_haste")
	check(Rules.weapon_state(player,"weapon_uwu_blaster")["status"]=="Passive fehlt","max weapon reports missing passive")
	check(Rules.weapon_state(player,"weapon_crossbow")["status"]=="Waffe auf Stufe 5 bringen","owned passive reports missing weapon rank")
	await capture("hud-statuses")
	GameManager.return_to_menu()
	world.free()
	QuestManager.flush()
	ProfileManager.player_slots=old_slots
	SaveManager.delete_profile(profile_id)
	get_window().size=old_size
	get_window().content_scale_size=old_scale
	GameManager.set_process(true)
	await get_tree().process_frame
	print("EVOLUTION: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("EVOLUTION PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

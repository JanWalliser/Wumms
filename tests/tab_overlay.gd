extends Node

const Overlay = preload("res://scripts/ui/swarm_tab_overlay.gd")
const Rules = preload("res://scripts/progression/evolution_rules.gd")
var failures: Array[String] = []
var checks := 0
var test_id := "tab_overlay_"+str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func tab_event(echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=KEY_TAB
	event.physical_keycode=KEY_TAB
	event.pressed=true
	event.echo=echo
	return event

func run_tests() -> void:
	var original := ProfileManager.player_slots.duplicate(true)
	var old_size := get_window().size
	var old_scale := get_window().content_scale_size
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=Vector2i(1920,1080)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"TAB test"))
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	for index in 4:
		ProfileManager.player_slots[index]["active"]=index<2
		ProfileManager.player_slots[index]["profile_id"]=test_id
		ProfileManager.player_slots[index]["character_id"]="jankz" if index==0 else "seraföhn"
		ProfileManager.player_slots[index]["device_id"]=-1 if index==0 else index-1
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode=true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	world.current_map_node.spawner.set_physics_process(false)
	for actor in GameManager.active_player_nodes:
		actor.set_physics_process(false)
		actor.weapon_controller.set_process(false)
	var p: PlayerController=GameManager.active_player_nodes[0]
	var overlay = world.hud.tab_overlay
	check(not overlay.visible,"new TAB display starts hidden")
	get_viewport().push_input(tab_event(),true)
	check(overlay.visible and not world.hud.tab_stats_panel.visible,"TAB opens graphical display instead of old text window")
	world.hud._input(tab_event(true))
	check(overlay.visible,"key repeat cannot repeatedly toggle display")
	check(not get_tree().paused,"opening stats does not pause the game")
	var weapon_ids: Array[String] = []
	var hover_button: Button
	for button in overlay.recipe_buttons:
		var id: String=button.get_meta("weapon","")
		if id.is_empty(): continue
		weapon_ids.append(id)
		check(button.get_meta("passive")==Rules.recipe_data(id).get("evolution_requires"),"recipe icon is grouped by its actual passive: "+id)
		check(button.tooltip_text.contains(str(Rules.recipe_data(id).get("evolution_name"))),"weapon hover names the evolution: "+id)
		if id=="weapon_meow_meow": hover_button=button
	check(weapon_ids.has("weapon_meow_meow") and not weapon_ids.has("weapon_sound_wave"),"selected player sees own signature recipe, not teammate signature")
	for id in WeaponRegistry.get_general_weapon_ids(): check(weapon_ids.has(id),"general weapon recipe is visible: "+id)
	p.weapon_controller.equipped_weapons[0].level=5
	p.passives["ability_haste"]=1
	p.recalculate_stats()
	overlay.refresh()
	check(hover_button.tooltip_text.contains("Evolution bereit"),"recipe hover updates when evolution becomes ready")
	p.passives.erase("ability_haste")
	p.passives["damage"]=2
	p.recalculate_stats()
	p.apply_temporary_buff("tab_test",10,{"ability_haste":50,"speed_pct":0.25})
	var snapshot := Overlay.stat_snapshot(p)
	check(snapshot["damage"]=="120%","damage shows total live multiplier, including 100 percent base")
	check(snapshot["movement"]=="438" and snapshot["haste"]=="50","movement and haste include temporary effects")
	check(snapshot["cooldown"]=="33.3%","50 haste is 33.3 percent cooldown reduction")
	p.current_stats["cooldown_multiplier"]=0.8
	check(Overlay.stat_snapshot(p)["cooldown"]=="46.7%","cooldown reduction includes additional multiplier")
	overlay.select_player(1)
	check(overlay.player==GameManager.active_player_nodes[1] and overlay.stat_labels["damage"].text=="100%","player selector does not leak teammate stats")
	check(overlay.recipe_buttons.any(func(b): return b.get_meta("weapon","")=="weapon_sound_wave"),"player selector rebuilds signature recipe")
	overlay.select_player(0)
	for button in overlay.recipe_buttons:
		if button.get_meta("weapon","")=="weapon_meow_meow": hover_button=button
	GameManager.enqueue_selection("level",7)
	await get_tree().process_frame
	check(get_tree().paused and world.level_up_modal.visible,"real level-up selection is paused")
	world.hud._input(tab_event())
	world.hud._input(tab_event())
	check(overlay.visible and get_tree().paused,"TAB can close and reopen during paused selection")
	for slot in world.level_up_modal.player_buttons:
		for card in world.level_up_modal.player_buttons[slot]:
			check(not card.get_node("Recipe").visible and card.get_node("Recipe").text.is_empty(),"evolution recipes no longer printed below selection cards")
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		get_window().size=resolution
		for frame in 4: await get_tree().process_frame
		overlay.layout_display()
		var screen := Rect2(Vector2.ZERO,Vector2(resolution))
		check(screen.encloses(overlay.recipes.get_global_rect()),"recipe panel fits "+str(resolution))
		check(screen.encloses(overlay.stats.get_global_rect()),"stats panel fits "+str(resolution))
		check(not overlay.recipes.get_global_rect().intersects(overlay.stats.get_global_rect()),"TAB panels do not overlap "+str(resolution))
	if OS.get_cmdline_user_args().has("--capture"):
		get_window().size=Vector2i(1920,1080)
		for frame in 5: await get_tree().process_frame
		overlay.layout_display()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/repair/tab-evolution-selection.png")
		var mouse := InputEventMouseMotion.new()
		mouse.position=hover_button.get_global_rect().get_center()
		get_viewport().push_input(mouse,true)
		for frame in 50: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/repair/tab-evolution-hover.png")
		var teammate: PlayerController=GameManager.active_player_nodes[1]
		GameManager.active_player_nodes.erase(teammate)
		world.hud._rebuild_players_hud()
		world.level_up_modal._rebuild_columns()
		for frame in 8: await get_tree().process_frame
		overlay.refresh()
		overlay.layout_display()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/repair/tab-single-player.png")
		GameManager.active_player_nodes.append(teammate)
		world.hud._rebuild_players_hud()
		world.level_up_modal._rebuild_columns()
	var clones: Array[PlayerController] = []
	for index in [2,3]:
		var clone := PlayerController.new()
		clone.player_slot_index=index
		clone.profile_id=test_id
		clone.char_data=p.char_data
		clone.base_stats=p.base_stats.duplicate()
		clone.current_stats=p.current_stats.duplicate()
		clone.weapon_controller=WeaponController.new()
		clone.add_child(clone.weapon_controller)
		clone.weapon_controller.host_player=clone
		clone.weapon_controller.equipped_weapons=p.weapon_controller.equipped_weapons.duplicate()
		GameManager.active_player_nodes.append(clone)
		clones.append(clone)
	world.level_up_modal._rebuild_columns()
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		get_window().size=resolution
		for frame in 5: await get_tree().process_frame
		for slot in world.level_up_modal.player_buttons:
			for card in world.level_up_modal.player_buttons[slot]:
				check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(card.get_global_rect()),"four-player choices fit with TAB at "+str(resolution))
				check(card.get_global_rect().position.x>=258,"four-player choices do not overlap the recipe strip")
	for clone in clones:
		GameManager.active_player_nodes.erase(clone)
		clone.free()
	GameManager.return_to_menu()
	check(not overlay.visible,"run end closes the overlay")
	world.free()
	ProfileManager.player_slots=original
	SaveManager.delete_profile(test_id)
	GameManager.set_process(true)
	get_window().content_scale_size=old_scale
	get_window().size=old_size
	await get_tree().process_frame
	print("TAB OVERLAY: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("TAB OVERLAY PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

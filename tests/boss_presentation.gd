extends Node2D

var failures: Array[String] = []
var checks := 0
var test_id := "boss_presentation_"+str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func painted_height(actor: Node2D) -> float:
	return actor.sprite.texture.get_image().get_used_rect().size.y*actor.sprite.scale.y*preload("res://scripts/maps/world_projection.gd").ground_scale().y

func run_tests() -> void:
	var original := ProfileManager.player_slots.duplicate(true)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Presentation"))
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	for index in 4:
		ProfileManager.player_slots[index]["active"]=index==0
		ProfileManager.player_slots[index]["profile_id"]=test_id
		ProfileManager.player_slots[index]["character_id"]="jankz"
		ProfileManager.player_slots[index]["device_id"]=-1 if index==0 else index-1
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode=true
	GameManager.game_time=180
	GameManager.team_level=7
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	GameManager.run_timer_updated.emit(180.0)
	map.spawner.set_physics_process(false)
	map.set_process(false)
	var p: PlayerController = GameManager.active_player_nodes[0]
	p.set_physics_process(false)
	p.weapon_controller.set_process(false)
	p.global_position=map.get_safe_position(map.fountain_pos+Vector2(0,440),20)
	p.visual_animator.facing_sector=2
	p.visual_animator.update(0,false,Vector2.DOWN)
	var jinx_height := painted_height(p)
	check(jinx_height*2.2>=88 and jinx_height*2.2<=105,"Jinx visible height matches the 1080p reference range")
	check(is_equal_approx(p.actor_scale,0.55) and is_equal_approx(p.get_node("CollisionShape2D").shape.radius,13.2),"visual enlargement preserves player physics")
	check(is_equal_approx(p.get_stat("movement_speed"),350),"visual enlargement preserves player speed")
	check(not p.health_bar.visible and not p.health_bar.show_percentage,"old unframed HP display is replaced, no HP percentage")
	check(p.visual_animator.overhead_anchor().y<p.visual_animator.visual_top,"player overhead display stays above enlarged art")
	var before_scale: Vector2=p.sprite.scale
	p._update_visuals()
	check(p.sprite.scale.is_equal_approx(before_scale),"repeated setup does not compound visual scale")
	p.visual_animator.facing_sector=2
	p.visual_animator.update(0,false,Vector2.DOWN)
	var mini = map.spawner._spawn_single_enemy("mini_boss",map.spawner.safe_position(p.global_position+Vector2(-200,0)))
	var elite = map.spawner._spawn_single_enemy("elite_variant",map.spawner.safe_position(Vector2(1000,700)))
	var ordinary = map.spawner._spawn_single_enemy("standard_grunt",map.spawner.safe_position(p.global_position+Vector2(150,50)))
	for enemy in [mini,elite,ordinary]: enemy.set_physics_process(false)
	var boss_ratio := painted_height(mini)/painted_height(p)
	print("PRESENTATION SIZES: Jinx=",painted_height(p)*2.2,"px, miniboss=",painted_height(mini)*2.2,"px, ratio=",boss_ratio)
	check(boss_ratio>=4 and boss_ratio<=6,"intermediate boss is four to six Jinx heights")
	check(mini.visual_animator.overhead_anchor().y<mini.visual_animator.visual_top,"boss HP display sits above enlarged silhouette")
	var minimap := Minimap.new()
	add_child(minimap)
	minimap.hide()
	var markers := minimap.get_threat_markers()
	check(markers.has(mini.global_position),"intermediate boss is marked immediately")
	check(markers.has(elite.global_position),"offscreen elite is marked immediately")
	check(not markers.has(ordinary.global_position),"normal enemies do not clutter the warning markers")
	var boss_hp: float=mini.current_health
	mini.status_effects.clear_all()
	DamageSystem.apply_damage({},mini,100,false,p)
	check(mini.current_health<boss_hp and mini.current_health>0,"boss receives real damage for its overhead HP display")
	mini.current_health=mini.max_health*0.65
	mini.queue_redraw()
	map.camera.set_process(false)
	map.camera.zoom=preload("res://scripts/maps/world_projection.gd").ground_scale()*2.2
	map.camera.global_position=p.global_position+Vector2(-70,0)
	map.camera.force_update_scroll()
	if OS.get_cmdline_user_args().has("--capture"):
		for effect in get_tree().get_nodes_in_group("runtime_effects"):
			if effect.config.get("damage",0)==0: effect.queue_free()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/repair/boss-presentation.png")
	mini.death_started=true
	check(not minimap.get_threat_markers().has(mini.global_position),"dying boss warning disappears immediately")
	mini.death_started=false
	mini.queue_free()
	check(not minimap.get_threat_markers().has(mini.global_position),"queued deletion cannot leave a ghost marker")
	await get_tree().process_frame
	check(minimap.get_threat_markers().size()==1,"other boss markers survive independently")
	minimap.free()
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=original
	SaveManager.delete_profile(test_id)
	GameManager.set_process(true)
	await get_tree().process_frame
	print("BOSS PRESENTATION: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("BOSS PRESENTATION PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

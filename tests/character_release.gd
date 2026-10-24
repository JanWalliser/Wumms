extends Node2D

const Icons = preload("res://scripts/ui/swarm_icons.gd")
var checks := 0
var failures: Array[String] = []
var test_id := "character_release_"+str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func run_tests() -> void:
	var original := ProfileManager.player_slots.duplicate(true)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Character test"))
	AudioManager.sfx_volume = 0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	for slot in 4:
		ProfileManager.player_slots[slot]["active"] = slot<2
		ProfileManager.player_slots[slot]["profile_id"] = test_id
		ProfileManager.player_slots[slot]["character_id"] = "seraföhn" if slot==0 else "löwina"
		ProfileManager.player_slots[slot]["device_id"] = -1 if slot==0 else slot-1
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode = true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	map.spawner.set_physics_process(false)
	for player in GameManager.active_player_nodes:
		player.set_physics_process(false)
		player.weapon_controller.set_process(false)
	var p: PlayerController = GameManager.active_player_nodes[0]
	var ally: PlayerController = GameManager.active_player_nodes[1]
	var enemy = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	map.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position=p.global_position+Vector2(60,0)
	enemy.current_health=100000
	enemy.max_health=100000
	# Real damage path: one direct bleed hit, one DoT, unrelated proc and ordinary hit.
	p.character_id="brioche"
	p.current_health=100
	enemy.status_effects.apply_effect("bleed",5,1,p)
	var healing: float = p.get_stat("max_health")*0.02
	DamageSystem.apply_damage({"status":"bleed"},enemy,10,false,p)
	check(is_equal_approx(p.current_health,100+healing),"direct bleed hit heals exactly once")
	DamageSystem.apply_damage({"status":"bleed"},enemy,10,false,p,"true",1)
	check(is_equal_approx(p.current_health,100+healing*2),"bleed tick heals once at proc depth one")
	DamageSystem.apply_damage({},enemy,10,false,p,"true",1)
	check(is_equal_approx(p.current_health,100+healing*2),"unrelated secondary proc cannot heal from existing bleed")
	DamageSystem.apply_damage({},enemy,10,false,p)
	check(is_equal_approx(p.current_health,100+healing*3),"ordinary direct hit on bleeding target still heals")
	p.character_id="rübenrambo"
	p._on_ability()
	for target in [enemy,ally]:
		check(is_equal_approx(p.modify_outgoing_damage(target,100,0,"multi:1"),140),"one empowered attack covers all its targets")
	check(p.riven_charges==2,"multi-target attack spends only one charge")
	check(p.modify_outgoing_damage(enemy,100,0,"")==100 and p.riven_charges==2,"missing attack identity cannot become a permanent empowered attack")
	check(p.modify_outgoing_damage(enemy,100,1,"proc")==100 and p.riven_charges==2,"secondary procs do not spend empowered charges")
	ally.character_id="rübenrambo"
	ally.riven_charges=3
	ally.modify_outgoing_damage(enemy,100,0,"multi:1")
	check(ally.riven_charges==2 and p.riven_charges==2,"identical characters own independent attack charges")
	# Real pausable delayed cast must be invalidated by death, even after instant revive.
	p.character_id="löwina"
	p._activate_ability_e()
	var before: float = enemy.current_health
	p.echo_charges=3
	p.riven_charges=3
	p.solar_marks[enemy.get_instance_id()]=GameManager.game_time+3
	p.aura_hits[enemy.get_instance_id()]=2
	p.place_feather(enemy.global_position)
	var effect = RuntimeEffect.spawn(map,p,p.global_position,{"radius":100,"damage":5,"duration":10})
	p._enter_downed_state()
	check(p.echo_charges==0 and p.riven_charges==0 and p.boosted_attacks.is_empty(),"death clears passive charges and empowerment history")
	check(p.solar_marks.is_empty() and p.aura_hits.is_empty() and p.feathers.is_empty(),"death clears target marks and feathers")
	check(effect.done and effect.is_queued_for_deletion(),"death retires owned effects immediately")
	check(not p.temp_buffs.has("eclipse"),"death removes delayed eclipse armor")
	p.revive_player()
	for frame in 200: await get_tree().process_frame
	check(enemy.current_health==before,"old eclipse cannot explode after death and revival")
	p._activate_ability_e()
	for frame in 200: await get_tree().process_frame
	check(enemy.current_health<before,"a new eclipse still explodes after revival")
	p.character_id="auarora"
	p.aura_hits[enemy.get_instance_id()]=2
	enemy.current_health=0
	p._runtime_update(1.1)
	check(p.aura_hits.is_empty(),"teammate-killed targets cannot leak Aurora passive entries")
	p.on_combat_hit(enemy,{"is_crit":false,"status":""},0)
	check(p.aura_hits.is_empty(),"killing hit does not re-add an Aurora mark")
	p.character_id="löwina"
	p.solar_marks.clear()
	p.on_combat_hit(enemy,{"is_crit":false,"status":""},0)
	check(p.solar_marks.is_empty(),"killing hit does not re-add a sunlight mark")
	# HUD resources are actual nonempty, distinct images, not merely different IDs.
	var hashes: Dictionary = {}
	for id in Icons.CHARACTER_ABILITIES:
		var ids: Array = Icons.CHARACTER_ABILITIES[id]
		check(ids.size()==3 and not ids.has(Icons.WEAPONS.get(CharacterRegistry.get_character_data(id)["starter_weapon"])),"E/R/passive distinct from signature icon: "+id)
		for icon in ids:
			var texture = Icons.texture(icon)
			var picture: Image = texture.get_image()
			check(not picture.is_empty() and picture.get_used_rect().size.x>100,"painted icon exists: "+str(icon))
			var fingerprint := picture.get_data().hex_encode().sha256_text()
			check(not hashes.has(fingerprint),"painted icon is visually unique: "+str(icon))
			hashes[fingerprint]=true
	for id in ["seraföhn","löwina"]:
		p.character_id=id
		p._update_visuals()
		check(p.visual_animator.frames!=null,"character uses compiled animation: "+id)
		for animation in ["idle","walk","shoot"]:
			var frames: SpriteFrames = p.visual_animator.frames
			check(frames.get_frame_count(animation)==4,"four frames: "+id+" / "+animation)
			var unique: Dictionary = {}
			for index in 4:
				var picture: Image = frames.get_frame_texture(animation,index).get_image()
				unique[picture.get_data().hex_encode().sha256_text()]=true
			check(unique.size()==4,"animation frames actually differ: "+id+" / "+animation)
		p.visual_animator.attack(Vector2.LEFT)
		p.visual_animator.update(0.02,false,Vector2.LEFT)
		check(p.visual_animator.animation=="shoot" and p.sprite.flip_h,"cast animation and horizontal facing: "+id)
	if OS.get_cmdline_user_args().has("--capture"):
		await capture(world)
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=original
	SaveManager.delete_profile(test_id)
	GameManager.set_process(true)
	await get_tree().process_frame
	print("CHARACTER RELEASE: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("CHARACTER RELEASE PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

func capture(world: Node) -> void:
	for index in GameManager.active_player_nodes.size():
		var player: PlayerController = GameManager.active_player_nodes[index]
		player.setup(index,test_id,"seraföhn" if index==0 else "löwina")
		player.visual_animator.attack(Vector2.RIGHT)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/repair/package-c-ingame.png")
	world.visible=false
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1400,1000)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.size=viewport.size
	background.color=Color("172632")
	viewport.add_child(background)
	var row := 0
	for id in ["seraföhn","löwina"]:
		var frames: SpriteFrames = load("res://assets/actors/animated/"+id+".res")
		for animation in ["idle","walk","shoot"]:
			for frame in 4:
				var sprite := Sprite2D.new()
				sprite.texture=frames.get_frame_texture(animation,frame)
				sprite.position=Vector2(170+frame*320,75+row*105)
				sprite.scale=Vector2.ONE*0.45
				viewport.add_child(sprite)
			row+=1
	for id in 24:
		var sprite := Sprite2D.new()
		sprite.texture=Icons.texture(200+id)
		sprite.position=Vector2(75+(id%12)*113,760+floori(id/12.0)*115)
		sprite.scale=Vector2.ONE*0.4
		viewport.add_child(sprite)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://output/repair/package-c-characters.png")
	viewport.free()

extends RefCounted

static func run(player: Node2D, suite: Node, enemy: Node2D) -> void:
	var icons = preload("res://scripts/ui/swarm_icons.gd")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/swarm/jinx-items/manifest.json"))
	var indices: Dictionary = {}
	var images: Dictionary = {}
	for id in manifest:
		var index := int(manifest[id]["index"])
		suite.check(not indices.has(index),id+" has its own semantic icon index")
		indices[index]=true
		var texture: Texture2D = icons.texture(index)
		suite.check(texture!=null,id+" has a compiled runtime icon")
		suite.check(texture.get_width()==256 and texture.get_height()==256,id+" uses a compact mipmapped painting in the HUD")
		suite.check(str(manifest[id]["path"]).contains("painted") or id in ["weapon_meow_meow","jinx_r"],id+" has no sketch fallback")
		var fingerprint := texture.get_image().get_data().hex_encode().sha256_text()
		suite.check(not images.has(fingerprint),id+" has different pixels from every other Jinx item")
		images[fingerprint]=true
		if not id.begins_with("jinx_"):
			suite.check(icons.choice_index({"id":id})==index,id+" uses the same icon in HUD and choices")
	suite.check(manifest.size()==69,"all Jinx weapons, stats, augments and kit abilities have icons")
	for id in ["painted-boomerang","painted-batblade","painted-crescent"]:
		var sprite: Texture2D = preload("res://scripts/combat/weapon_visuals.gd").texture(id)
		suite.check(sprite!=null and sprite.get_image().detect_alpha()!=Image.ALPHA_NONE,id+" uses finished artwork with genuine transparency")
	var passive_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/swarm-passive-reference.json"))
	var fields := {"max_health":"max_health","armor":"armor","health_regen":"health_regen","movement_speed":"movement_speed","crit_chance":"crit_chance","damage":"damage_multiplier","ability_haste":"ability_haste","duration":"duration_multiplier","area_size":"area_multiplier","exp_gain":"exp_multiplier","pickup_radius":"pickup_radius","projectile_count":"bonus_projectiles"}
	for id in passive_data:
		for rank in range(1,6):
			var raw: float = passive_data[id]["values"][rank]
			var stats := StatCalculator.compute_player_stats({"max_health":1000},{},{id:rank},[],{})
			var expected := raw
			if id=="max_health": expected+=1000
			elif id=="movement_speed": expected=350*(1+raw)
			elif id=="pickup_radius": expected=100*(1+raw)
			elif id=="crit_chance": expected+=0.05
			elif id in ["damage","duration","area_size","exp_gain"]: expected+=1
			suite.check(is_equal_approx(float(stats[fields[id]]),expected),id+" actual stat calculation matches archived rank "+str(rank))
	var time: float = GameManager.game_time
	player.passives.clear()
	player.augments.clear()
	player.temp_buffs.clear()
	player.recalculate_stats()
	player.current_stats["crit_chance"]=0
	var pos: Vector2 = enemy.global_position
	enemy.global_position=player.global_position+Vector2(50,0)
	GameManager.game_time=100
	var gun := WeaponInstance.new("weapon_gatling",player)
	gun.is_evolved=true
	gun.fire()
	var effect = gun.effect_node
	for i in 4: effect._apply_gatling_stack(enemy)
	suite.check(effect.gatling_stacks[enemy.get_instance_id()]["count"]==4,"gatling requires four slow stacks")
	suite.check(float(enemy.get_meta("gatling_vulnerability_until",-1))<100,"fourth hit does not prematurely stun")
	effect._apply_gatling_stack(enemy)
	suite.check(enemy.get_meta("gatling_vulnerability_until")==106,"fifth consecutive hit stuns for six seconds")
	GameManager.game_time=101
	effect._apply_gatling_stack(enemy)
	suite.check(enemy.get_meta("gatling_vulnerability_until")==106,"sustained firing cannot indefinitely refresh stun")
	GameManager.game_time=107
	effect._apply_gatling_stack(enemy)
	GameManager.game_time=112
	effect._apply_gatling_stack(enemy)
	suite.check(effect.gatling_stacks[enemy.get_instance_id()]["count"]==1,"gatling slow stacks expire after four seconds without hits")
	gun.level=5
	player.current_stats["area_multiplier"]=1.5
	gun.update(0)
	suite.check(effect.config["radius"]==292.5 and effect.config["damage"]==115,"active gatling updates area and evolution once")
	suite.clear_combat()
	enemy.remove_meta("gatling_vulnerability_until")
	enemy.status_effects.clear_all()
	player.current_stats["area_multiplier"]=1
	var poison := WeaponInstance.new("weapon_paw_poison",player)
	poison.level=5
	poison.last_trail_position=player.global_position-Vector2(30,0)
	poison.fire()
	var cloud = poison.poison_clouds[0]
	suite.check(cloud.config["damage"]==18.75,"poison level five deals one quarter of 75 DPS per tick")
	enemy.global_position=cloud.global_position
	var hp: float = enemy.current_health
	for i in 4:
		GameManager.game_time=120+i*0.25
		cloud._damage_tick("area")
		cloud._damage_tick("area")
	suite.check(enemy.current_health==hp-76,"four poison ticks per second, rounded once per hit, duplicate callbacks ignored")
	suite.clear_combat()
	var robot := WeaponInstance.new("weapon_yuumibot",player)
	robot.fire()
	suite.check(robot.effect_node.config["pickup_radius"]==60,"YuumiBot pickup area uses baseline 300 reference units without invented flat bonus")
	player.set_meta("yuumibot_heal_progress",85.0)
	robot.effect_node._advance_drone_healing(232)
	suite.check(player.get_meta("yuumibot_heal_progress")==17,"YuumiBot retains fractional healing progress after crossing several thresholds")
	var next_robot := WeaponInstance.new("weapon_yuumibot",player)
	next_robot.fire()
	next_robot.effect_node._advance_drone_healing(10)
	suite.check(player.get_meta("yuumibot_heal_progress")==27,"YuumiBot healing progress carries between summons")
	player.remove_meta("yuumibot_heal_progress")
	suite.clear_combat()
	enemy.global_position=pos
	GameManager.game_time=time
	player.recalculate_stats()

static func capture(suite: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer=1000
	suite.add_child(layer)
	layer.add_child(preload("res://tests/jinx_item_gallery.gd").new())
	await suite.get_tree().process_frame
	await RenderingServer.frame_post_draw
	suite.get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/jinx-item-gallery.png")
	layer.queue_free()

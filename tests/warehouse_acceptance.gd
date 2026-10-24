extends Node

const Layout = preload("res://scripts/maps/warehouse_layout.gd")
const Art = preload("res://scripts/maps/warehouse_art.gd")
var checks := 0
var failures: Array[String] = []
var temporary_id := "warehouse_acceptance_"+str(Time.get_ticks_usec())

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var saved_slots := ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume = 0
	SaveManager.save_profile(SaveManager.create_default_profile(temporary_id,"Warehouse test"))
	for i in 4:
		ProfileManager.player_slots[i]["active"] = true
		ProfileManager.player_slots[i]["profile_id"] = temporary_id
		ProfileManager.player_slots[i]["character_id"] = ["jankz","seraföhn","löwina","rübenrambo"][i]
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode = true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	var layout: Layout = map.layout
	var field: Flowfield = map.spawner.flowfield
	map.spawner.set_physics_process(false)
	map.get_node("EventDirector").set_process(false)
	for player in GameManager.active_player_nodes:
		player.set_meta("god_mode",true)
		player.weapon_controller.set_process(false)
		player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(layout.walls.size()==53,"all original static regions")
	check(map.obstacles_container.get_child_count()==53,"no old placeholder containers")
	for number in [6,11,12,13,14,15,16,17]:
		var surface: Polygon2D = map.district_art.get_node("Square_Wall%d_RestrictedWater" % number)
		check(surface.polygon==layout.wall(number)["polygon"],"restricted coast artwork matches collision "+str(number))
	check(map.district_art.get_node_or_null("Square_Wall29_DistrictRoof")!=null,"east city exclusion is visibly built up")
	for wall in layout.walls:
		var body = map.obstacles_container.get_node_or_null(wall["id"])
		check(body is StaticBody2D and body.collision_layer==16,"physics body "+wall["id"])
		check(body.get_node("CollisionPolygon2D").polygon==wall["polygon"],"unaltered polygon "+wall["id"])
	for player in GameManager.active_player_nodes:
		check(layout.is_clear(player.global_position,24.0),"four-player spawn has body clearance")
		var visual_size := 94.5 if player.character_id=="jankz" else float(player.sprite.texture.get_width())
		if player.character_id in ["seraföhn","löwina"]: visual_size=48.0
		check(is_equal_approx(player.sprite.get_rect().size.x*player.sprite.scale.x,visual_size*0.55),"calibrated actor artwork size independent from atlas resolution")
		check(is_equal_approx(player.actor_scale,0.55),"player ring and shield share actor scale")
		check(is_equal_approx(player.get_node("CollisionShape2D").shape.radius,13.2),"player body follows visual scale")
		check(is_equal_approx(player.get_node("HitboxArea/CollisionShape2D").shape.radius,14.3),"player hitbox follows visual scale")
		player._update_visuals()
		check(is_equal_approx(player.get_node("CollisionShape2D").shape.radius,13.2),"repeated visual setup does not compound size")
	# Exercise actual input movement and ability movement at the warehouse scale.
	var runner = GameManager.active_player_nodes[0]
	var runner_start: Vector2 = runner.global_position
	var saved_device: int = ProfileManager.player_slots[0]["device_id"]
	ProfileManager.player_slots[0]["device_id"] = -1
	Input.action_press("move_right")
	runner._physics_process(1.0/60.0)
	check(is_equal_approx(runner.velocity.length(),runner.get_stat("movement_speed")*0.342),"walking uses reduced world speed with character modifiers")
	Input.action_release("move_right")
	runner.start_dash(Vector2.RIGHT,800,0.3)
	runner._physics_process(1.0/60.0)
	check(is_equal_approx(runner.velocity.length(),273.6),"ability dash uses movement scale exactly once")
	runner.dash_timer = 0.0
	runner.dash_velocity = Vector2.ZERO
	runner.velocity = Vector2.ZERO
	runner.global_position = runner_start
	ProfileManager.player_slots[0]["device_id"] = saved_device
	check(is_equal_approx(map.camera.max_zoom,2.2),"warehouse camera has closer default framing")
	var fountain_sprite: Sprite2D = map.district_art.get_node("HealingFountainArt")
	for number in [7,8,9,10,26]:
		var prop: Sprite2D = map.district_art.get_node("Square_Wall"+str(number)+"_Art")
		check(prop.texture != null and not prop.region_enabled,"complete custom texture "+str(number))
		check(is_equal_approx(prop.scale.x,prop.scale.y),"custom prop keeps native proportions "+str(number))
		check(map.district_art.get_node_or_null("Square_Wall"+str(number)+"_Surface")==null,"no collision mask clips building "+str(number))
	check(fountain_sprite.texture.resource_path.ends_with("custom/fountain-core.res"),"only fountain core is drawn above existing ground plinth")
	check(is_equal_approx(fountain_sprite.scale.x,fountain_sprite.scale.y),"fountain preserves native image aspect ratio")
	var fountain_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/warehouse/presentation.json"))["fountain"]
	check(is_equal_approx(fountain_sprite.scale.x,float(fountain_config["basin_width_world"])/float(fountain_config["basin_width_pixels"])),"fountain scales by basin diameter, not collision bounds")
	var basin_anchor := Vector2(fountain_config["basin_center_pixels"][0],fountain_config["basin_center_pixels"][1])
	check((fountain_sprite.position+basin_anchor*fountain_sprite.scale).is_equal_approx(map.fountain_pos),"fountain basin is centered on original locator")
	var anchors := {"NW-Park":Vector2(245,190),"Parkmitte":Vector2(210,460),"SW-Park":Vector2(190,610),"Nordplatz":Vector2(620,315),"Oststrasse":Vector2(790,430),"Industriegasse":Vector2(830,650),"Suedost":Vector2(885,800),"Suedflaeche":Vector2(550,740)}
	for label in anchors:
		var position_test: Vector2 = anchors[label]/1024.0*3600.0-Vector2(1800,1800)
		check(layout.is_clear(position_test,18.0),"walkable reference anchor "+label)
		check(_near_reachable(field,position_test),"horde route reaches "+label)
	var floor_mesh: Polygon2D = map.district_art.get_node("RegisteredOriginalGround")
	for i in floor_mesh.polygon.size():
		var source_point := floor_mesh.uv[i]/floor_mesh.texture.get_size()*1024.0
		if source_point.distance_to(Vector2(510,474))<=100.01:
			var expected: Vector2 = (source_point-Vector2(510,474))/1024.0*3600.0+map.fountain_pos
			check(floor_mesh.polygon[i].distance_to(expected)<0.01,"local fountain plinth stays circular")
	for triangle: PackedInt32Array in floor_mesh.polygons:
		var a := floor_mesh.polygon[triangle[1]]-floor_mesh.polygon[triangle[0]]
		var b := floor_mesh.polygon[triangle[2]]-floor_mesh.polygon[triangle[0]]
		var ua := floor_mesh.uv[triangle[1]]-floor_mesh.uv[triangle[0]]
		var ub := floor_mesh.uv[triangle[2]]-floor_mesh.uv[triangle[0]]
		check(a.cross(b)*ua.cross(ub)>0,"ground registration has no folded triangles")
	var minimap := Minimap.new()
	add_child(minimap)
	check(minimap.world_to_map(Vector2(-1800,-1800)).is_equal_approx(Vector2(8,8)),"minimap uses actual map origin")
	check(minimap.world_to_map(Vector2(1800,1800)).is_equal_approx(Vector2(152,152)),"minimap uses actual map extent")
	minimap.free()
	var valid_spawns := 0
	for i in 80:
		var point: Vector2 = map.spawner.valid_spawn()
		if point.is_finite():
			valid_spawns += 1
			check(layout.is_clear(point,18.0),"horde spawns outside walls")
	check(valid_spawns>=75,"horde can find enough entrances")
	for kind in ["mission","trial","supply"]:
		for i in 10:
			var position_event: Vector2 = map.get_event_position(kind,Vector2.ZERO)
			check(layout.is_clear(position_event,28.0),"reachable "+kind+" marker")
	var player = GameManager.active_player_nodes[0]
	for i in range(1,4):
		GameManager.active_player_nodes[i].is_downed = true
	player.global_position = map.fountain_pos + Vector2(205,0)
	player.current_health = 100
	map._process(4.1)
	check(map.fountain_cooldown>59,"fountain can charge from walkable ring")
	var healed: float = player.current_health
	map._process(0.1)
	check(healed>100 and player.current_health==healed,"fountain heals once then cools down")
	map.set_process(false)
	# A real CharacterBody2D must traverse the park around the pond and benches.
	player.global_position = anchors["SW-Park"]/1024.0*3600.0-Vector2(1800,1800)
	map.spawner._update_horde_systems()
	var start: Vector2 = anchors["NW-Park"]/1024.0*3600.0-Vector2(1800,1800)
	map.spawner._spawn_single_enemy("standard_grunt",start)
	var pursuer: Enemy = map.spawner.active_enemies.back()
	check(is_equal_approx(pursuer.sprite.get_rect().size.x*pursuer.sprite.scale.x,36*0.55*1.1),"enemy artwork follows calibrated actor size")
	check(is_equal_approx(pursuer.collision_shape.shape.radius,9.9),"enemy body follows visual scale")
	pursuer._setup_from_registry()
	check(is_equal_approx(pursuer.collision_shape.shape.radius,9.9),"enemy setup is idempotent")
	pursuer.move_speed = 260
	var began := start.distance_to(player.global_position)
	for frame in 900:
		if frame%21==0:
			map.spawner._update_horde_systems()
		await get_tree().physics_frame
		if pursuer.global_position.distance_to(player.global_position)<75:
			break
	check(pursuer.global_position.distance_to(player.global_position)<100,"physical enemy traverses entire park without wall sticking")
	print("WAREHOUSE PURSUIT: ",began," -> ",pursuer.global_position.distance_to(player.global_position))
	GameManager.spawn_map_boss()
	check(GameManager.current_boss_node.flowfield_ref==map.boss_flowfield,"boss uses separate body clearance")
	check(layout.is_clear(GameManager.current_boss_node.global_position,48),"boss appears outside scenery")
	var boss: BossController = GameManager.current_boss_node
	check(is_equal_approx(boss.collision_shape.shape.radius,26.4),"boss body shares actor scale")
	for label in anchors:
		var position_test: Vector2 = anchors[label]/1024.0*3600.0-Vector2(1800,1800)
		check(_near_reachable(map.boss_flowfield,position_test),"large boss route reaches "+label)
	# Exercise actual boss movement in the narrow industrial streets, without attack teleports.
	pursuer.set_physics_process(false)
	player.global_position = Vector2(1000,-200)
	boss.global_position = map.get_safe_position(Vector2(850,1080),70)
	boss.attack_timer = -10000
	boss.move_speed = 300
	for frame in 1050:
		if frame%21==0: map.spawner._update_horde_systems()
		await get_tree().physics_frame
		if boss.global_position.distance_to(player.global_position)<110: break
	check(boss.global_position.distance_to(player.global_position)<140,"physical boss navigates industrial blocks")
	var enemies_before: int = map.spawner.active_enemies.size()
	boss._spawn_reksai_tunnels(player.global_position)
	check(map.spawner.active_enemies.size()>enemies_before,"RekSai tunnel reinforcements use valid spawn API")
	boss._trigger_phase_transition()
	await get_tree().physics_frame
	check(layout.is_clear(boss.global_position,boss.collision_shape.shape.radius),"growing boss retains wall clearance")
	for frame in 40: await get_tree().physics_frame
	check(is_equal_approx(boss.sprite.get_rect().size.x*boss.sprite.scale.x,120*0.55*1.1*1.35),"boss phase growth preserves calibrated artwork size")
	check(is_equal_approx(boss.collision_shape.shape.radius,26.4*1.3),"boss phase body grows from scaled baseline")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture_views(world,map)
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots = saved_slots
	SaveManager.delete_profile(temporary_id)
	print("WAREHOUSE ACCEPTANCE: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("WAREHOUSE ACCEPTANCE PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

func _near_reachable(field: Flowfield, point: Vector2) -> bool:
	var cell := field.world_to_grid(point)
	for dy in range(-2,3):
		for dx in range(-2,3):
			var p := cell+Vector2i(dx,dy)
			if not field.is_blocked(p.x,p.y) and field.cost_field[p.y*field.grid_width+p.x]<Flowfield.INFINITE_COST:
				return true
	return false

func capture_views(_world: Node, map: Node2D) -> void:
	for enemy in map.spawner.active_enemies:
		if is_instance_valid(enemy): enemy.set_physics_process(false)
	var camera: Camera2D = map.camera
	camera.set_process(false)
	var locations := {"fountain-gameplay":map.fountain_pos+Vector2(0,70),"park-gameplay":Vector2(-1000,-650),"pavilion-gameplay":Vector2(-760,30),"industry-gameplay":Vector2(850,450),"coast-gameplay":Vector2(120,1120),"east-edge-gameplay":Vector2(1750,150),"southeast-edge-gameplay":Vector2(1630,1150)}
	for label in locations:
		print("CAPTURE VIEW: ",label)
		camera.global_position = locations[label]
		camera.zoom = Vector2.ONE * camera.max_zoom
		for player in GameManager.active_player_nodes:
			player.is_downed = false
			player.global_position = map.get_safe_position(camera.position+Vector2(100+player.player_slot_index*80,140),28)
		for frame in 4:
			await get_tree().process_frame
			RenderingServer.force_draw(false,1.0/60.0)
		get_viewport().get_texture().get_image().save_png("res://output/warehouse-implementation/"+label+".png")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048,2048)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var art := Art.new()
	viewport.add_child(art)
	art.build(map.layout)
	var overview_camera := Camera2D.new()
	overview_camera.zoom = Vector2(0.54,0.54)
	viewport.add_child(overview_camera)
	overview_camera.make_current()
	for frame in 4:
		await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60.0)
	viewport.get_texture().get_image().save_png("res://output/warehouse-implementation/warehouse-overview.png")
	# Unobstructed detail plates use the same runtime art, without a HUD hiding roofs.
	viewport.size = Vector2i(1600,1400)
	var details := {"industry-clean":[Vector2(880,430),1.0],"fountain-clean":[map.fountain_pos+Vector2(0,-80),1.5],"pavilion-clean":[Vector2(-760,0),2.0],"coast-clean":[Vector2(120,1120),1.7]}
	for label in details:
		overview_camera.position = details[label][0]
		overview_camera.zoom = Vector2.ONE * details[label][1]
		for frame in 4:
			await get_tree().process_frame
			RenderingServer.force_draw(false,1.0/60.0)
		viewport.get_texture().get_image().save_png("res://output/warehouse-implementation/"+label+".png")
	viewport.queue_free()
	await get_tree().process_frame
	print("WAREHOUSE VISUAL CAPTURE COMPLETE")

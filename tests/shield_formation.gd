extends Node
const Timeline = preload("res://scripts/game/warehouse_timeline.gd")
var checks := 0
var failures: Array[String] = []
var test_id := "shield_ring_"+str(Time.get_ticks_usec())

class OpenGround extends Node2D:
	func get_safe_position(point: Vector2, _radius: float = 0) -> Vector2: return point

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func run_tests() -> void:
	var saved_slots := ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Shield test"))
	for i in 4:
		ProfileManager.player_slots[i]["active"]=i==0
		ProfileManager.player_slots[i]["profile_id"]=test_id
		ProfileManager.player_slots[i]["character_id"]="jankz"
		ProfileManager.player_slots[i]["device_id"]=-1
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode=true
	var world=load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map=world.current_map_node
	map.spawner.set_physics_process(false)
	map.set_process(false)
	map.get_node("EventDirector").set_process(false)
	var player=GameManager.active_player_nodes[0]
	player.set_physics_process(false)
	player.weapon_controller.set_process(false)
	player.global_position=Vector2(8000,8000)
	player.current_stats["max_health"]=100000.0
	player.current_health=100000.0
	var ground := OpenGround.new()
	add_child(ground)
	var spawner := EnemySpawner.new()
	ground.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.max_concurrent_enemies=0
	var timeline=Timeline.new()
	GameManager.game_time=224.99
	timeline._tick_shield_rings(spawner)
	check(get_tree().get_nodes_in_group("shield_formations").is_empty(),"ring does not appear early")
	GameManager.game_time=225
	timeline._tick_shield_rings(spawner)
	var rings := get_tree().get_nodes_in_group("shield_formations")
	check(rings.size()==1,"Story ring starts at 3:45 even when normal arena budget is full")
	var ring=rings[0]
	ring.set_physics_process(false)
	check(ring.soldier_count==60 and ring.slots.size()==60 and ring.radius==260,"first ring retains all sixty exact positions and original scaled radius")
	check(not ring.deployed,"arrival is warned before soldiers block or damage")
	var saved_center: Vector2=ring.center
	player.global_position+=Vector2(30,0)
	timeline._tick_shield_rings(spawner)
	check(get_tree().get_nodes_in_group("shield_formations").size()==1 and ring.center==saved_center,"repeated ticks and movement cannot duplicate or drag the ring")
	GameManager.game_time=225.59
	ring._physics_process(0.01)
	check(not ring.deployed,"warning lasts six tenths of a second")
	GameManager.game_time=225.61
	ring._physics_process(0.02)
	check(ring.deployed and ring.soldiers.size()==60,"all soldiers deploy together after the warning")
	for soldier in ring.soldiers:
		soldier.set_physics_process(false)
		check(absf(soldier.global_position.distance_to(saved_center)-260)<0.001,"terrain-free ring retains an exact circle")
		check(soldier.collision_layer==34 and soldier.collision_mask==0,"soldiers block only the dedicated player mask and remain targetable")
		var before: Vector2=soldier.global_position
		soldier.apply_knockback(Vector2(400,200))
		soldier._physics_process(1.0)
		check(soldier.global_position==before and soldier.knockback_velocity==Vector2.ZERO,"soldiers neither chase nor separate nor accept knockback")
	var first=ring.soldiers[0]
	check(first.enemy_id=="shield_soldier" and first.armor==0 and first.max_health>=750,"ring uses its own shield-soldier stats rather than ordinary heavy tanks")
	player.global_position=first.global_position+Vector2(-40,0)
	await get_tree().physics_frame
	check(player.test_move(player.global_transform,Vector2(80,0)),"player physics cannot cross an intact segment")
	var ordinary: Enemy=load("res://scenes/enemies/enemy_base.tscn").instantiate()
	ground.add_child(ordinary)
	ordinary.set_physics_process(false)
	ordinary.global_position=saved_center+Vector2(-220,0)
	check(not ordinary.test_move(ordinary.global_transform,Vector2(-80,0)),"ordinary monsters can enter through the ring")
	ordinary.free()
	# One touch is capped per player, including where multiple sentries overlap.
	player.global_position=first.global_position
	var health: float=player.current_health
	ring._contact_damage()
	check(player.current_health<health,"walking against a soldier deals damage")
	var damaged: float=player.current_health
	ring._contact_damage()
	check(player.current_health==damaged,"overlapping soldiers cannot multiply contact damage in one frame")
	GameManager.game_time+=0.66
	player._runtime_update(0.66)
	ring._contact_damage()
	check(player.current_health<damaged,"continued contact damages again after the cooldown")
	# Killing a local portion opens a real physical exit while other slots remain.
	for index in [0,1,59]:
		var soldier=ring.soldiers[index]
		soldier.receive_damage(soldier.current_health+1,false,player)
	await get_tree().physics_frame
	player.global_position=saved_center+Vector2(220,0)
	check(not player.test_move(player.global_transform,Vector2(80,0)),"destroyed soldiers create a traversable opening")
	check(is_instance_valid(ring.soldiers[30]) and not ring.soldiers[30].death_started,"destroying an exit does not destroy the opposite wall")
	# Real second actor: damage lockouts belong to each player, not the whole team.
	var teammate=load("res://scenes/characters/player.tscn").instantiate()
	ground.add_child(teammate)
	teammate.setup(1,test_id,"jankz")
	teammate.set_physics_process(false)
	teammate.weapon_controller.set_process(false)
	GameManager.active_player_nodes.append(teammate)
	player.global_position=ring.soldiers[30].global_position
	teammate.global_position=player.global_position
	GameManager.game_time+=0.66
	player.damage_grace=0
	var player_before: float=player.current_health
	var teammate_before: float=teammate.current_health
	ring._contact_damage()
	check(player.current_health<player_before and teammate.current_health<teammate_before,"both players receive their own contact hit on the same frame")
	player_before=player.current_health
	teammate_before=teammate.current_health
	ring._contact_damage()
	check(player.current_health==player_before and teammate.current_health==teammate_before,"both player cooldowns independently reject duplicate contact")
	var positioning_probe=preload("res://scripts/game/shield_formation.gd").new()
	ground.add_child(positioning_probe)
	teammate.is_downed=true
	teammate.global_position=Vector2(-8000,-8000)
	positioning_probe.begin(spawner,Timeline.reference_data()["phases"][5]["waves"][2])
	check(positioning_probe.center==player.global_position,"provisional living-team policy excludes a downed teammate from its fixed centre")
	positioning_probe.free()
	GameManager.active_player_nodes.erase(teammate)
	teammate.free()
	var kills := GameManager.total_run_kills
	GameManager.game_time=259.99
	ring._physics_process(0.01)
	check(not ring.is_queued_for_deletion(),"ring survives until its 35-second deadline")
	GameManager.game_time=260
	ring._physics_process(0.01)
	check(ring.is_queued_for_deletion() and GameManager.total_run_kills==kills,"timeout removes ring without kill rewards")
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("shield_formations").is_empty(),"timeout leaves no invisible wall")
	# Second event remains seventy segments regardless of multiplayer density.
	for i in 4: ProfileManager.player_slots[i]["active"]=true
	GameManager.game_time=450
	timeline._tick_shield_rings(spawner)
	ring=get_tree().get_nodes_in_group("shield_formations")[0]
	ring.set_physics_process(false)
	check(ring.soldier_count==70 and ring.radius==280,"second ring is seventy units at 7:30 even with four active slots")
	GameManager.set_state(GameManager.GameState.PAUSED)
	GameManager.game_time=451
	ring._physics_process(1)
	check(not ring.deployed,"paused game cannot deploy the wall")
	GameManager.set_state(GameManager.GameState.GAMEPLAY)
	ring._physics_process(0.01)
	check(ring.soldiers.size()==70,"second ring deploys its complete independent formation")
	var token: String=GameManager.run_id
	GameManager.run_id="changed_test_run"
	ring._physics_process(0.01)
	check(ring.is_queued_for_deletion(),"run change retires old formation")
	GameManager.run_id=token
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--capture"):
		for i in 4: ProfileManager.player_slots[i]["active"]=i==0
		player.global_position=map.get_safe_position(Vector2(0,850),24)
		player.current_stats["max_health"]=1000.0
		player.current_health=1000
		GameManager.game_time=225
		var demo=preload("res://scripts/game/shield_formation.gd").new()
		map.add_child(demo)
		demo.begin(map.spawner,Timeline.reference_data()["phases"][5]["waves"][2])
		GameManager.game_time=225.61
		demo._physics_process(0.01)
		map.camera._process(1)
		map.camera.set_process(false)
		for frame in 4: await get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
		get_viewport().get_texture().get_image().save_png("res://output/repair/shield-formation-native.png")
		demo.free()
	ground.free()
	world.free()
	GameManager.active_player_nodes.clear()
	GameManager.current_map=null
	ProfileManager.player_slots=saved_slots
	SaveManager.delete_profile(test_id)
	print("SHIELD FORMATION: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("SHIELD FORMATION PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)

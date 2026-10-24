extends Node

var profile_id := "jinx_weapon_run_"+str(Time.get_ticks_usec())
var slots: Array = []
var world: Node
var player: Node2D
var elapsed := 0.0
var window_time := 0.0
var phase := -1
var ids: Array[String] = []
var peak_projectiles := 0
var peak_effects := 0

func _ready() -> void:
	set_process(false)
	call_deferred("begin")

func begin() -> void:
	slots=ProfileManager.player_slots.duplicate(true)
	SaveManager.save_profile(SaveManager.create_default_profile(profile_id,"Jinx weapon integration"))
	for index in 4:
		ProfileManager.player_slots[index]["active"]=index==0
		ProfileManager.player_slots[index]["profile_id"]=profile_id
		ProfileManager.player_slots[index]["character_id"]="jankz"
	AudioManager.sfx_volume=0
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode=true
	GameManager.team_level=20
	world=load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	player=GameManager.active_player_nodes[0]
	player.set_meta("god_mode",true)
	world.current_map_node.spawner.set_physics_process(false)
	world.current_map_node.get_node("EventDirector").set_process(false)
	world.current_map_node.set_process(false)
	player.global_position=world.current_map_node.get_safe_position(Vector2(0,850),24)
	for index in 36:
		world.current_map_node.spawner._spawn_single_enemy("standard_grunt",player.global_position+Vector2.from_angle(index*TAU/36)*120)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.max_health=1000000
		enemy.current_health=1000000
	ids=WeaponRegistry.get_general_weapon_ids()
	ids.append("weapon_meow_meow")
	advance()
	set_process(true)

func advance() -> void:
	for group in ["projectiles","runtime_effects"]:
		for effect in get_tree().get_nodes_in_group(group): effect.queue_free()
	player.set_meta("iceblast_armed",false)
	player.remove_meta("iceblast_weapon")
	player.weapon_controller.equipped_weapons.clear()
	phase+=1
	if phase>=ids.size():
		finish.call_deferred()
		set_process(false)
		return
	var weapon := WeaponInstance.new(ids[phase],player)
	weapon.level=5
	weapon.is_evolved=true
	player.weapon_controller.equipped_weapons.append(weapon)
	window_time=0
	print("LIVE WEAPON ",phase+1,"/",ids.size()," ",ids[phase])
	if phase%5==0:
		player._activate_ability_e()
		player._activate_ability_r()

func _process(delta: float) -> void:
	elapsed+=delta
	window_time+=delta
	player.global_position=world.current_map_node.get_safe_position(Vector2(sin(elapsed*0.7)*100,850+cos(elapsed)*60),24)
	peak_projectiles=maxi(peak_projectiles,get_tree().get_nodes_in_group("projectiles").size())
	peak_effects=maxi(peak_effects,get_tree().get_nodes_in_group("runtime_effects").size())
	if window_time>=3.6: advance()

func finish() -> void:
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=slots
	SaveManager.delete_profile(profile_id)
	await get_tree().process_frame
	print("JINX LIVE RUN PASSED: ",ids.size()," evolved weapons, ",roundi(elapsed)," simulated seconds; peak projectiles ",peak_projectiles,", effects ",peak_effects)
	get_tree().quit()

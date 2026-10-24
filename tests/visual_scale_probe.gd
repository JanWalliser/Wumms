extends Node2D

var test_id := "scale_probe_"+str(Time.get_ticks_usec())

func _ready() -> void: call_deferred("capture")

func capture() -> void:
	var original := ProfileManager.player_slots.duplicate(true)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Scale probe"))
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
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	var map = world.current_map_node
	map.spawner.set_physics_process(false)
	map.set_process(false)
	var p: PlayerController = GameManager.active_player_nodes[0]
	p.set_physics_process(false)
	p.weapon_controller.set_process(false)
	p.global_position=map.fountain_pos+Vector2(-25,390)
	p.visual_animator.facing_sector=2
	p.visual_animator.update(0,false,Vector2.DOWN)
	# Keep the original diagnosis reproducible after its visual factor is installed.
	var installed_factor: float=p.visual_animator.VISUAL_MULTIPLIERS.get("jankz",1.0)
	var base_scale: Vector2=p.sprite.scale/installed_factor
	var base_position: Vector2=p.sprite.position/installed_factor
	map.camera.set_process(false)
	var metrics: Array = []
	for entry in [["current",2.2,1.0],["zoom-only",2.4,1.0],["proposed",2.2,1.8]]:
		map.camera.zoom=preload("res://scripts/maps/world_projection.gd").ground_scale()*float(entry[1])
		map.camera.global_position=p.global_position-(get_viewport_rect().size*Vector2(0.505,0.515)-get_viewport_rect().size*0.5)/map.camera.zoom
		p.sprite.scale=base_scale*float(entry[2])
		p.sprite.position=base_position*float(entry[2])
		map.camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/repair/scale-"+entry[0]+".png")
		var picture: Image=p.sprite.texture.get_image()
		var used: Rect2i=picture.get_used_rect()
		var item := {"variant":entry[0],"viewport":[get_viewport_rect().size.x,get_viewport_rect().size.y],"zoom":entry[1],"sprite_multiplier":entry[2],"painted_jinx_size_screen":[used.size.x*p.sprite.scale.x*map.camera.zoom.x,used.size.y*p.sprite.scale.y*map.camera.zoom.y],"fountain_core_width_screen":330*map.camera.zoom.x,"camera_position":[map.camera.global_position.x,map.camera.global_position.y],"player_position":[p.global_position.x,p.global_position.y]}
		metrics.append(item)
		print(JSON.stringify(item))
	var output := FileAccess.open("res://output/repair/scale-metrics.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics,"  "))
	output.close()
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=original
	SaveManager.delete_profile(test_id)
	GameManager.set_process(true)
	await get_tree().process_frame
	print("VISUAL SCALE PROBE COMPLETE")
	get_tree().quit()

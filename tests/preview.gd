extends Node

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	var saved = ProfileManager.player_slots.duplicate(true)
	var id = "preview_"+str(Time.get_ticks_usec())
	SaveManager.save_profile(SaveManager.create_default_profile(id,"Preview"))
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = true
		ProfileManager.player_slots[i]["profile_id"] = id
		ProfileManager.player_slots[i]["character_id"] = ["jankz","seraföhn","löwina","rübenrambo"][i]
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode = true
	GameManager.team_level = 8
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	for i in range(4):
		var p = GameManager.active_player_nodes[i]
		p.global_position = Vector2((i-1.5)*170,0)
		p.set_meta("god_mode",true)
	for n in range(40): world.current_map_node.spawner._spawn_single_enemy("standard_grunt",Vector2.from_angle(TAU*n/40)*400)
	GameManager.spawn_map_boss()
	for frame in range(5): await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/repair/gameplay.png")
	GameManager.trigger_access_card()
	for frame in range(3): await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/repair/selection.png")
	GameManager.return_to_menu()
	world.free()
	var settings = load("res://scenes/ui/settings_menu.tscn").instantiate()
	add_child(settings)
	for frame in range(3): await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/repair/settings.png")
	settings.free()
	ProfileManager.player_slots = saved
	SaveManager.delete_profile(id)
	print("VISUAL CAPTURE COMPLETE")
	get_tree().quit()

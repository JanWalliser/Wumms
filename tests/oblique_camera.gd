extends Node2D

const ViewProjection = preload("res://scripts/maps/world_projection.gd")
var failures: Array[String] = []
var checks := 0
var test_id := "projection_"+str(Time.get_ticks_usec())

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _ready() -> void: call_deferred("run_tests")

func run_tests() -> void:
	var original := ProfileManager.player_slots.duplicate(true)
	var old_size := get_window().size
	var old_scale := get_window().content_scale_size
	var old_mouse: Vector2=InputManager.mouse_viewport_position
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=Vector2i(1920,1080)
	SaveManager.save_profile(SaveManager.create_default_profile(test_id,"Oblique"))
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
	map.camera.set_process(false)
	var p: PlayerController=GameManager.active_player_nodes[0]
	p.set_physics_process(false)
	p.weapon_controller.set_process(false)
	p.global_position=map.fountain_pos+Vector2(0,440)
	p.visual_animator.facing_sector=2
	p.visual_animator.update(0,false,Vector2.DOWN)
	map.camera._process(1)
	map.camera.force_update_scroll()
	await get_tree().process_frame
	check(is_equal_approx(map.camera.zoom.y/map.camera.zoom.x,0.72),"floor depth is foreshortened")
	var image: Image=p.sprite.texture.get_image()
	var height: float=image.get_used_rect().size.y*p.sprite.scale.y*map.camera.zoom.y
	check(height>=88 and height<=105,"Jinx stays upright at the calibrated height")
	check(is_equal_approx(p.get_node("CollisionShape2D").shape.radius,13.2),"projection does not alter world collision")
	var viewport_transform: Transform2D=get_viewport().get_canvas_transform()
	var center: Vector2=viewport_transform*p.global_position
	check(absf(center.y-1080*0.52)<2,"solo player is framed near reference vertical center")
	for index in 16:
		var desired := Vector2.from_angle(TAU*index/16)
		InputManager.mouse_viewport_position=center+desired*200
		var aim: Vector2=InputManager.get_aim_vector(0,p.global_position,get_viewport())
		check(ViewProjection.screen_direction(aim).dot(desired)>0.999,"mouse aim matches visible direction "+str(index))
		check(ViewProjection.screen_direction(ViewProjection.world_direction(desired)).dot(desired)>0.999,"stick conversion matches visible direction "+str(index))
		check(is_equal_approx(ViewProjection.world_direction(desired*0.5).length(),0.5),"analog strength preserved "+str(index))
	Input.action_press("move_right")
	Input.action_press("move_down")
	var move: Vector2=InputManager.get_movement_vector(0)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(ViewProjection.screen_direction(move).dot(Vector2.ONE.normalized())>0.999 and is_equal_approx(move.length(),1),"diagonal movement is screen-aligned without speed multiplication")
	for wall in map.layout.walls:
		var body: StaticBody2D=map.obstacles_container.get_node(wall["id"])
		var point: Vector2=wall["polygon"][0]
		var screen: Vector2=body.get_global_transform_with_canvas()*point
		check((viewport_transform.affine_inverse()*screen).distance_to(point)<0.01,"visible terrain and physical polygon share transform: "+str(wall["id"]))
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		get_window().size=resolution
		for frame in 3: await get_tree().process_frame
		world.hud._layout_hud()
		map.camera._process(1)
		map.camera.force_update_scroll()
		var minimap: Minimap=world.hud.get_node("Minimap")
		check(absf(minimap.size.y-resolution.y*0.285)<1,"minimap follows reference screen proportion: "+str(resolution))
		check(is_equal_approx(minimap.size.x,minimap.size.y),"minimap stays square")
		for panel in world.hud.players_hud_container.get_children():
			check(not panel.get_global_rect().intersects(minimap.get_global_rect()),"player HUD leaves room for larger minimap")
		check(minimap.view_outline().size()==5,"minimap includes camera view outline")
	if OS.get_cmdline_user_args().has("--capture"):
		get_window().size=Vector2i(1920,1080)
		for frame in 4: await get_tree().process_frame
		world.hud._layout_hud()
		map.camera._process(1)
		map.camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/repair/oblique-camera-minimap.png")
	GameManager.return_to_menu()
	world.free()
	InputManager.mouse_viewport_position=old_mouse
	ProfileManager.player_slots=original
	SaveManager.delete_profile(test_id)
	GameManager.set_process(true)
	get_window().content_scale_size=old_scale
	get_window().size=old_size
	await get_tree().process_frame
	print("OBLIQUE CAMERA: ",checks," checks, ",failures.size()," failed")
	if failures.is_empty(): print("OBLIQUE CAMERA PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)


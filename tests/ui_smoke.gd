extends Node

func _ready() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var old = ProfileManager.player_slots.duplicate(true)
	var id = "ui_test_"+str(Time.get_ticks_usec())
	SaveManager.save_profile(SaveManager.create_default_profile(id,"UI test"))
	AudioManager.sfx_volume = 0
	for i in range(4):
		ProfileManager.player_slots[i]["active"] = true
		ProfileManager.player_slots[i]["profile_id"] = id
		ProfileManager.player_slots[i]["device_id"] = i
	for name in ["main_menu","profile_select","lobby","character_select","quest_menu","shop","settings_menu","stats_menu"]:
		var scene = load("res://scenes/ui/"+name+".tscn").instantiate()
		add_child(scene)
		await get_tree().process_frame
		scene.free()
	GameManager.start_new_run("map_warehouse","story")
	GameManager.practice_mode = true
	var world = load("res://scenes/game/game_world.tscn").instantiate()
	add_child(world)
	GameManager.trigger_access_card()
	var modal = world.level_up_modal
	var motion = InputEventJoypadButton.new()
	motion.device = 2
	motion.button_index = JOY_BUTTON_DPAD_DOWN
	motion.pressed = true
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var ok = modal.player_focus_indices[2] == 1 and modal.player_focus_indices[1] == 0
	var select = InputEventJoypadButton.new()
	select.device = 2
	select.button_index = JOY_BUTTON_A
	select.pressed = true
	Input.parse_input_event(select)
	await get_tree().process_frame
	ok = ok and not modal.player_choices_data.has(2) and modal.player_choices_data.has(1)
	GameManager.return_to_menu()
	world.free()
	await get_tree().process_frame
	ProfileManager.player_slots = old
	SaveManager.delete_profile(id)
	print("UI SMOKE: 8 menus and synthetic device routing, ",0 if ok else 1," failed")
	get_tree().quit(0 if ok else 1)

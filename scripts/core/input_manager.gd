extends Node

# InputManager - Unified input routing for 1 to 4 local players (Keyboard/Mouse & Gamepads)

signal auto_aim_toggled(slot_index: int, enabled: bool)

var ability_edges: Dictionary = {}
var auto_aim_states: Array[bool] = [true, true, true, true]
var mouse_viewport_position := Vector2.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(func(): mouse_viewport_position=Vector2.INF)
	GameManager.game_state_changed.connect(func(state):
		if state != GameManager.GameState.GAMEPLAY: ability_edges.clear())
	var preferences = ConfigFile.new()
	preferences.load("user://settings.cfg")
	var defaults = {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}
	for action in defaults:
		if preferences.has_section_key("input",action): continue
		InputMap.action_erase_events(action)
		var physical = InputEventKey.new()
		physical.physical_keycode = defaults[action][0]
		var arrow = InputEventKey.new()
		arrow.keycode = defaults[action][1]
		InputMap.action_add_event(action,physical)
		InputMap.action_add_event(action,arrow)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_viewport_position=event.position
		return
	if event is InputEventKey and event.echo: return
	if not event is InputEventKey and not event is InputEventJoypadButton: return
	if not event.pressed or GameManager.current_state != GameManager.GameState.GAMEPLAY: return
	for i in range(ProfileManager.player_slots.size()):
		var slot = ProfileManager.player_slots[i]
		if not slot["active"]: continue
		if event is InputEventKey and slot["device_id"] == -1:
			if event.is_action_pressed("ability_e"): ability_edges[str(i)+"e"] = Engine.get_physics_frames()
			if event.is_action_pressed("ability_r"): ability_edges[str(i)+"r"] = Engine.get_physics_frames()
			if event.is_action_pressed("toggle_auto_aim"): toggle_auto_aim(i)
		elif event is InputEventJoypadButton and slot["device_id"] == event.device:
			if event.button_index == JOY_BUTTON_A: ability_edges[str(i)+"e"] = Engine.get_physics_frames()
			if event.button_index == JOY_BUTTON_B: ability_edges[str(i)+"r"] = Engine.get_physics_frames()
			if event.button_index == JOY_BUTTON_RIGHT_SHOULDER: toggle_auto_aim(i)

func toggle_auto_aim(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < auto_aim_states.size():
		auto_aim_states[slot_index] = not auto_aim_states[slot_index]
		emit_signal("auto_aim_toggled", slot_index, auto_aim_states[slot_index])

func is_auto_aim_enabled(slot_index: int) -> bool:
	if slot_index >= 0 and slot_index < auto_aim_states.size():
		return auto_aim_states[slot_index]
	return true

func get_movement_vector(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= ProfileManager.player_slots.size():
		return Vector2.ZERO

	var slot = ProfileManager.player_slots[slot_index]
	if not slot["active"]:
		return Vector2.ZERO

	var device_id: int = slot["device_id"]
	var move := Vector2.ZERO
	if device_id <= -100:
		return NetworkManager.remote_movement(slot_index)

	if device_id == -1: # Keyboard & Mouse
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	else: # Gamepad
		var lx := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		var stick := Vector2(lx, ly)
		if stick.length() > 0.2:
			move = stick

		# D-Pad fallback
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_LEFT):
			move.x -= 1.0
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_RIGHT):
			move.x += 1.0
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP):
			move.y -= 1.0
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_DOWN):
			move.y += 1.0

	return preload("res://scripts/maps/world_projection.gd").world_direction(move)

func get_aim_vector(slot_index: int, player_world_pos: Vector2, viewport: Viewport) -> Vector2:
	if slot_index < 0 or slot_index >= ProfileManager.player_slots.size():
		return Vector2.RIGHT

	var slot = ProfileManager.player_slots[slot_index]
	var device_id: int = slot["device_id"]

	if device_id == -1 and viewport: # Keyboard & Mouse
		if NetworkManager.is_client(): return Vector2.ZERO
		var mouse_world := get_mouse_world_position(viewport)
		var dir := (mouse_world - player_world_pos).normalized()
		return dir if dir != Vector2.ZERO else Vector2.RIGHT
	elif device_id <= -100:
		return NetworkManager.remote_aim(slot_index, player_world_pos)
	elif device_id >= 0: # Gamepad Right Stick
		var rx := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var rstick := Vector2(rx, ry)
		if rstick.length() > 0.25:
			return preload("res://scripts/maps/world_projection.gd").world_direction(rstick).normalized()

	return Vector2.ZERO # Zero means fall back to movement or auto-aim

func get_mouse_world_position(viewport: Viewport) -> Vector2:
	var point := mouse_viewport_position if mouse_viewport_position.is_finite() else viewport.get_mouse_position()
	return viewport.get_canvas_transform().affine_inverse()*point

func is_ability_e_just_pressed(slot_index: int) -> bool:
	return _consume_edge(str(slot_index)+"e")

func is_ability_r_just_pressed(slot_index: int) -> bool:
	return _consume_edge(str(slot_index)+"r")


func _consume_edge(key: String) -> bool:
	var frame = ability_edges.get(key, -100)
	ability_edges.erase(key)
	return Engine.get_physics_frames() - frame <= 1

func slot_for_device(device: int) -> int:
	for i in range(ProfileManager.player_slots.size()):
		if ProfileManager.player_slots[i]["active"] and ProfileManager.player_slots[i]["device_id"] == device: return i
	return -1

extends Node2D

# GameWorld - Master gameplay scene holding the current Map, HUD, Modals, and End Screen

@onready var map_container: Node2D = $MapContainer
@onready var hud: Control = $CanvasLayer/HUD
@onready var level_up_modal: Control = $CanvasLayer/LevelUpModal
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var debug_overlay: Control = $CanvasLayer/DebugOverlay

var current_map_node: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if map_container:
		map_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_selected_map()
	GameManager.players_ready.emit()

	GameManager.game_state_changed.connect(_on_game_state_changed)
	Input.joy_connection_changed.connect(_on_joy_connection)
	NetworkManager.world_ready(current_map_node)

func _load_selected_map() -> void:
	if current_map_node:
		current_map_node.queue_free()

	var map_path := "res://scenes/maps/map_warehouse.tscn"
	match GameManager.selected_map_id:
		"map_outskirts":
			map_path = "res://scenes/maps/map_outskirts.tscn"
		"map_lab":
			map_path = "res://scenes/maps/map_lab.tscn"
		"map_beach":
			map_path = "res://scenes/maps/map_beach.tscn"

	var map_scene: PackedScene = load(map_path)
	if map_scene:
		current_map_node = map_scene.instantiate()
		map_container.add_child(current_map_node)

func _input(event: InputEvent) -> void:
	if NetworkManager.is_client(): return
	if event.is_echo(): return
	if event.is_action_pressed("pause_game") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and InputManager.slot_for_device(event.device) >= 0):
		if GameManager.current_state == GameManager.GameState.GAMEPLAY:
			GameManager.set_state(GameManager.GameState.PAUSED)
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.set_state(GameManager.GameState.GAMEPLAY)

	if OS.get_cmdline_user_args().has("--developer") and event.is_action_pressed("debug_toggle"):
		if debug_overlay:
			debug_overlay.visible = not debug_overlay.visible

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state==GameManager.GameState.PAUSED and is_instance_valid(hud): hud.set_tab_visible(false)
	if pause_menu:
		var is_paused := (new_state == GameManager.GameState.PAUSED)
		pause_menu.visible = is_paused
		if is_paused and pause_menu.has_method("on_shown"):
			pause_menu.on_shown()

	if game_over_screen:
		if new_state == GameManager.GameState.RUN_VICTORY or new_state == GameManager.GameState.RUN_DEFEAT:
			hud.tab_stats_panel.hide()
			hud.set_tab_visible(false)
			level_up_modal.hide()
			pause_menu.hide()
			game_over_screen.setup(new_state == GameManager.GameState.RUN_VICTORY)
			game_over_screen.show()

func _on_joy_connection(device: int, connected: bool) -> void:
	if connected: return
	for slot in ProfileManager.player_slots:
		if slot["active"] and slot["device_id"] == device and GameManager.current_state == GameManager.GameState.GAMEPLAY:
			GameManager.set_state(GameManager.GameState.PAUSED)

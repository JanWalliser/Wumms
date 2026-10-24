extends Control

# DebugOverlay - Developer test panel for rapid testing, god mode, spawning, and fast-forwarding

@onready var god_mode_btn: CheckButton = $Panel/VBoxContainer/GodModeButton
@onready var add_exp_btn: Button = $Panel/VBoxContainer/GridContainer/AddExpButton
@onready var add_gold_btn: Button = $Panel/VBoxContainer/GridContainer/AddGoldButton
@onready var fast_forward_btn: Button = $Panel/VBoxContainer/GridContainer/FastForwardButton
@onready var spawn_boss_btn: Button = $Panel/VBoxContainer/GridContainer/SpawnBossButton
@onready var evolve_weapons_btn: Button = $Panel/VBoxContainer/GridContainer/EvolveWeaponsButton
@onready var kill_all_btn: Button = $Panel/VBoxContainer/GridContainer/KillAllButton
@onready var fps_label: Label = $Panel/VBoxContainer/FpsLabel

var god_mode_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	god_mode_btn.toggled.connect(_on_god_mode_toggled)
	add_exp_btn.pressed.connect(_on_add_exp_pressed)
	add_gold_btn.pressed.connect(_on_add_gold_pressed)
	fast_forward_btn.pressed.connect(_on_fast_forward_pressed)
	spawn_boss_btn.pressed.connect(_on_spawn_boss_pressed)
	evolve_weapons_btn.pressed.connect(_on_evolve_weapons_pressed)
	kill_all_btn.pressed.connect(_on_kill_all_pressed)

func _process(_delta: float) -> void:
	if visible:
		var enemies_count := get_tree().get_nodes_in_group("enemies").size()
		var proj_count := get_tree().get_nodes_in_group("projectiles").size()
		fps_label.text = "FPS: %d | Urviecher: %d | Projektile: %d" % [Engine.get_frames_per_second(), enemies_count, proj_count]



func _on_god_mode_toggled(enabled: bool) -> void:
	god_mode_enabled = enabled
	GameManager.practice_mode = true
	for p in GameManager.active_player_nodes:
		if is_instance_valid(p): p.set_meta("god_mode",enabled)

func _on_add_exp_pressed() -> void:
	GameManager.practice_mode = true
	GameManager.add_team_exp(150)

func _on_add_gold_pressed() -> void:
	GameManager.practice_mode = true
	GameManager.team_gold_earned += 1000
	AudioManager.play_sfx("coin")

func _on_fast_forward_pressed() -> void:
	GameManager.practice_mode = true
	GameManager.game_time = 890.0 # 10 seconds before boss spawn

func _on_spawn_boss_pressed() -> void:
	GameManager.practice_mode = true
	GameManager.spawn_map_boss()

func _on_evolve_weapons_pressed() -> void:
	GameManager.practice_mode = true
	for p in GameManager.active_player_nodes:
		if is_instance_valid(p) and p.weapon_controller:
			for w in p.weapon_controller.equipped_weapons:
				w.level = 5
				w.evolve()

func _on_kill_all_pressed() -> void:
	GameManager.practice_mode = true
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is Enemy and not e.is_boss:
			e.take_hit(99999.0, true, null)

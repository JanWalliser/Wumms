extends Control

const PlayerPanel = preload("res://scripts/ui/swarm_player_panel.gd")
const TabOverlay = preload("res://scripts/ui/swarm_tab_overlay.gd")
var tab_overlay: Control
var xp_notice: Label
var xp_batch := 0
var xp_notice_until := 0

# HUD - Main gameplay heads-up display showing team progression, timer, player states, and boss health

@onready var timer_label: Label = $TopBar/HBoxContainer/TimerLabel
@onready var map_label: Label = $TopBar/HBoxContainer/MapLabel
@onready var gold_label: Label = $TopBar/HBoxContainer/GoldLabel
@onready var team_exp_bar: ProgressBar = $TopBar/TeamExpBar
@onready var team_level_label: Label = $TopBar/TeamLevelLabel

@onready var players_hud_container: HBoxContainer = $BottomBar/PlayersContainer
@onready var boss_bar_container: VBoxContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossBarContainer/BossHealthBar

@onready var tab_stats_panel: PanelContainer = $TabStatsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	xp_notice = Label.new()
	xp_notice.name = "XPNotice"
	xp_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_notice.add_theme_color_override("font_color",Color("8cd8ff"))
	xp_notice.add_theme_color_override("font_outline_color",Color("08151e"))
	xp_notice.add_theme_constant_override("outline_size",5)
	add_child(xp_notice)
	GameManager.experience_collected.connect(_on_experience_collected)
	add_to_group("game_hud")
	resized.connect(_layout_hud)
	map_label.hide()
	team_level_label.hide()
	team_exp_bar.reparent(self)
	gold_label.reparent($TopBar)
	gold_label.add_theme_font_size_override("font_size",17)
	var timer_frame := StyleBoxFlat.new()
	timer_frame.bg_color = Color("0b1b25")
	timer_frame.border_color = Color("a68e53")
	timer_frame.set_border_width_all(1)
	timer_frame.set_corner_radius_all(7)
	timer_label.add_theme_stylebox_override("normal",timer_frame)
	timer_label.add_theme_font_size_override("font_size",27)
	timer_label.custom_minimum_size = Vector2(112,42)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.85,0.15,0.2)
	boss_health_bar.add_theme_stylebox_override("fill",fill)
	var exp_fill = StyleBoxFlat.new()
	exp_fill.bg_color = Color(0.15,0.65,1)
	team_exp_bar.add_theme_stylebox_override("fill",exp_fill)
	boss_bar_container.hide()
	tab_stats_panel.hide()
	tab_overlay=TabOverlay.new()
	tab_overlay.name="SwarmTabOverlay"
	tab_overlay.hud=self
	var tab_layer := CanvasLayer.new()
	tab_layer.name="TabDisplayLayer"
	tab_layer.layer=20
	add_child(tab_layer)
	tab_layer.add_child(tab_overlay)

	GameManager.run_timer_updated.connect(_on_timer_updated)
	GameManager.team_exp_changed.connect(_on_exp_changed)
	GameManager.boss_created.connect(_bind_boss)
	GameManager.players_ready.connect(_rebuild_players_hud)
	GameManager.boss_defeated.connect(_on_boss_defeated)

	# Wrap the growing team summary in a scroll view.
	var content = $TabStatsPanel/VBoxContainer/StatsContent
	var scroll = ScrollContainer.new()
	scroll.name="ScrollContainer"
	scroll.custom_minimum_size = Vector2(750,450)
	$TabStatsPanel/VBoxContainer.remove_child(content)
	$TabStatsPanel/VBoxContainer.add_child(scroll)
	scroll.add_child(content)
	_setup_map_info()
	_rebuild_players_hud()
	_on_exp_changed(GameManager.current_team_exp, GameManager.required_team_exp, GameManager.team_level)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats") and not event.is_echo():
		set_tab_visible(not tab_overlay.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_BACK:
		for slot in 4:
			if ProfileManager.player_slots[slot]["active"] and ProfileManager.player_slots[slot]["device_id"]==event.device:
				var close: bool = tab_overlay.visible and tab_overlay.selected_slot==slot
				tab_overlay.select_player(slot)
				set_tab_visible(not close)
				get_viewport().set_input_as_handled()
				break

func set_tab_visible(open: bool) -> void:
	if open and GameManager.run_finalized: return
	tab_overlay.visible=open
	if open:
		_update_tab_stats()
		tab_overlay.call_deferred("layout_display")

func _setup_map_info() -> void:
	var m_name := "Warenhaus-Wahnsinn"
	match GameManager.selected_map_id:
		"map_outskirts": m_name = "Außen-Kekse"
		"map_lab": m_name = "Untergrund-Laberatorium"
		"map_beach": m_name = "Badestrand des Verderbens"

	var d_name := "Story"
	match GameManager.selected_difficulty:
		"hard": d_name = "Aua-Akademie (Hard)"
		"extreme": d_name = "Warum-tun-wir-uns-das-an?! (Extreme)"

	map_label.text = "%s | %s" % [m_name, d_name]

func _on_timer_updated(t: float) -> void:
	var mins := int(t / 60.0)
	var secs := int(fmod(t, 60.0))
	timer_label.text = "%02d:%02d" % [mins, secs]
	gold_label.text = "◈ %d   × %d" % [GameManager.team_gold_earned,GameManager.total_run_kills]

func _on_exp_changed(curr: int, req: int, lvl: int) -> void:
	team_level_label.text = "TEAM STUFE %d" % lvl
	team_exp_bar.max_value = req
	team_exp_bar.value = curr

func _on_boss_spawned(b_name: String) -> void:
	boss_bar_container.show()
	boss_name_label.text = "OBER-OBERMACKER: " + b_name.to_upper()
	boss_health_bar.max_value = 100.0
	boss_health_bar.value = 100.0

	if GameManager.current_boss_node and GameManager.current_boss_node.has_signal("boss_health_updated"):
		GameManager.current_boss_node.boss_health_updated.connect(func(c, m):
			boss_health_bar.max_value = m
			boss_health_bar.value = c
		)

func _on_boss_defeated(_name: String) -> void:
	boss_bar_container.hide()

func _rebuild_players_hud() -> void:
	for child in players_hud_container.get_children():
		players_hud_container.remove_child(child)
		child.queue_free()

	for p in GameManager.active_player_nodes:
		if is_instance_valid(p):
			var card := _create_player_hud_card(p)
			players_hud_container.add_child(card)
	_layout_hud()

func _create_player_hud_card(player: PlayerController) -> Control:
	var panel := PlayerPanel.new()
	panel.player = player
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	return panel

func _layout_hud() -> void:
	var viewport_size := get_viewport_rect().size
	var count := maxi(1,GameManager.active_player_nodes.size())
	var map_size := minimap_side(viewport_size)
	var available := maxf(240,viewport_size.x-map_size-64)
	var panel_width := minf(640,(available-(count-1)*12)/count)
	var panel_height := panel_width/640.0*184
	$BottomBar.offset_top = -(maxf(panel_height,200)+22)
	players_hud_container.add_theme_constant_override("separation",12)
	players_hud_container.offset_left = 16
	players_hud_container.offset_right = -map_size-36
	players_hud_container.offset_bottom = -12
	for panel in players_hud_container.get_children():
		panel.custom_minimum_size = Vector2(panel_width,panel_height)
	team_exp_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	team_exp_bar.offset_top = -9
	team_exp_bar.offset_bottom = 0
	$Minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	$Minimap.offset_left = -map_size-16
	$Minimap.offset_right = -16
	$Minimap.offset_top = -map_size-22
	$Minimap.offset_bottom = -22
	$TopBar/HBoxContainer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	$TopBar/HBoxContainer.offset_left = -130
	$TopBar/HBoxContainer.offset_right = 130
	$TopBar/HBoxContainer.offset_bottom = 45
	gold_label.position = Vector2(viewport_size.x-260,12)
	gold_label.size = Vector2(240,30)
	$TopBar/EventBannerLabel.size.x = viewport_size.x
	if is_instance_valid(tab_overlay): tab_overlay.call_deferred("layout_display")

func get_playfield_rect(viewport_size: Vector2) -> Rect2:
	var bottom_reserved := maxf(absf($BottomBar.offset_top),minimap_side(viewport_size)+22)+16
	return Rect2(Vector2(16,88),Vector2(maxf(64,viewport_size.x-32),maxf(64,viewport_size.y-bottom_reserved-88)))

static func minimap_side(viewport_size: Vector2) -> float:
	return roundf(clampf(viewport_size.y*0.285,160,minf(400,viewport_size.x*0.28)))

func _update_tab_stats() -> void:
	if is_instance_valid(tab_overlay): tab_overlay.refresh()

func _bind_boss(boss: Node2D) -> void:
	boss_bar_container.show()
	boss_name_label.text = EnemyRegistry.get_enemy_data(boss.enemy_id)["display_name"]
	boss.boss_health_updated.connect(func(c,m):
		boss_health_bar.max_value = m
		boss_health_bar.value = c)
	boss_health_bar.max_value = boss.max_health
	boss_health_bar.value = boss.current_health

func _get_compass_arrow(v: Vector2) -> String:
	var angle := fposmod(v.angle(), TAU)
	var octant := int(round(angle / (PI * 0.25))) % 8
	match octant:
		0: return "▶"
		1: return "▼▶"
		2: return "▼"
		3: return "▼◀"
		4: return "◀"
		5: return "▲◀"
		6: return "▲"
		7: return "▲▶"
	return "●"

func _process(_delta: float) -> void:
	xp_notice.visible = Time.get_ticks_msec()<xp_notice_until
	xp_notice.position = Vector2((size.x-400)*0.5,size.y-absf($BottomBar.offset_top)-32)
	xp_notice.size = Vector2(400,26)
	if is_instance_valid(GameManager.current_map):
		var director = GameManager.current_map.get_node_or_null("EventDirector")
		var banner = get_node_or_null("TopBar/EventBannerLabel")
		if director and not director.message.is_empty():
			var ev_info: String = director.message
			var target_pos := Vector2.INF
			if not director.active.is_empty():
				target_pos = director.active.get("position", Vector2.INF)
			elif director.supply_pos.is_finite():
				target_pos = director.supply_pos

			if target_pos.is_finite() and not GameManager.active_player_nodes.is_empty():
				var ref_p: Node2D = GameManager.active_player_nodes[0]
				if is_instance_valid(ref_p):
					var diff := target_pos - ref_p.global_position
					var dist := int(diff.length() / 10.0)
					var arrow := _get_compass_arrow(diff)
					ev_info += " | %s %dm" % [arrow, dist]
			if banner:
				banner.text = ev_info
		else:
			if banner:
				banner.text = ""

	gold_label.text = "◈ %d   × %d" % [GameManager.team_gold_earned,GameManager.total_run_kills]
	if is_instance_valid(GameManager.current_boss_node) and GameManager.is_boss_active:
		boss_name_label.text = "%s · %d" % [EnemyRegistry.get_enemy_data(GameManager.current_boss_node.enemy_id)["display_name"],GameManager.current_boss_node.boss_phase]

func _on_experience_collected(amount: int, reason: String) -> void:
	if Time.get_ticks_msec()>xp_notice_until: xp_batch=0
	xp_batch+=amount
	xp_notice_until=Time.get_ticks_msec()+2500
	xp_notice.text = "+%d XP · %s" % [xp_batch,reason]

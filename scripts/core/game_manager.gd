extends Node

# GameManager - Master orchestrator of game state, run progression, time scaling and player synchronization

enum GameState {
	MENU,
	LOBBY,
	GAMEPLAY,
	LEVEL_UP_PAUSE,
	PAUSED,
	RUN_VICTORY,
	RUN_DEFEAT
}

signal game_state_changed(new_state: GameState)
signal run_timer_updated(game_time: float)
signal team_exp_changed(current_exp: int, required_exp: int, team_level: int)
signal level_up_triggered(team_level: int)
signal access_card_triggered
signal player_downed(player_index: int)
signal player_revived(player_index: int)
signal boss_spawned(boss_name: String)
signal players_ready
signal boss_created(boss: Node2D)
signal selection_requested(event: Dictionary)
signal combat_event(kind: String, payload: Dictionary)
signal boss_enraged
signal boss_defeated(boss_name: String)
signal experience_collected(amount: int, reason: String)

var quest_notes: Dictionary = {}
var profile_enabled = OS.get_cmdline_user_args().has("--profile")
var profile_totals: Dictionary = {}
var run_id: String = ""
var run_finalized := true
var practice_mode := false
var final_result: Dictionary = {}
var selection_queue: Array[Dictionary] = []
var current_selection: Dictionary = {}
var selection_serial := 0
var gold_carry := 0.0
var exp_carry := 0.0
var warehouse_xp_carry := 0.0
var total_xp_collected := 0
var evolved_count := 0
var current_map: Node2D
var _quest_second := -1
var _finish_scheduled := false
var _boss_won := false

var current_state: GameState = GameState.MENU

# Run configuration
var selected_map_id: String = "map_warehouse"
var selected_difficulty: String = "story" # story, hard, extreme

# Run session variables
var game_time: float = 0.0 # Active gameplay seconds (excludes pause and levelup)
var is_boss_active: bool = false
var boss_timer: float = 0.0
var boss_spawn_game_time := 0.0
var boss_enraged_state: bool = false
var current_boss_node: Node = null

# Team Progression
var team_level: int = 1
var current_team_exp: int = 0
var required_team_exp: int = 5
var team_gold_earned: int = 0
var total_run_kills: int = 0
var total_damage_dealt: float = 0.0

# Synchronized Level-Up State
# Stores which players still have a pending level-up choice
var pending_level_up_players: Dictionary = {} # player_index -> count of choices

# Player references in scene
var active_player_nodes: Array[Node2D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	QuestManager.quest_completed.connect(func(id,title,reward): quest_notes[id] = title+": "+reward)

func _process(delta: float) -> void:
	if NetworkManager.is_client(): return
	if current_state == GameState.GAMEPLAY:
		game_time += delta
		if int(game_time) != _quest_second:
			_quest_second = int(game_time)
			QuestManager.notify_event("time_survived", game_time)
			if selected_difficulty!="story": QuestManager.notify_event("hard_time_survived",game_time)
		emit_signal("run_timer_updated", game_time)

		# Check for 15-minute boss spawn
		if game_time >= 900.0 and not is_boss_active and current_boss_node == null:
			spawn_map_boss()

		# Boss enrage timer (5 minutes after spawn = 300 seconds)
		if is_boss_active and not boss_enraged_state:
			boss_timer = maxf(0,game_time-boss_spawn_game_time)
			if boss_timer >= 300.0:
				boss_enraged_state = true
				emit_signal("boss_enraged")
				AudioManager.play_sfx("boss_spawn", 1.2)

func set_state(new_state: GameState) -> void:
	if NetworkManager.is_client() and not NetworkManager.applying:
		if new_state in [GameState.GAMEPLAY, GameState.PAUSED]: NetworkManager.request_pause()
		return
	if new_state == GameState.GAMEPLAY and (run_finalized or not current_selection.is_empty()):
		return
	if current_state == new_state:
		return
	current_state = new_state
	match new_state:
		GameState.MENU, GameState.LOBBY, GameState.GAMEPLAY:
			get_tree().paused = false
		GameState.LEVEL_UP_PAUSE, GameState.PAUSED:
			get_tree().paused = true
		GameState.RUN_VICTORY, GameState.RUN_DEFEAT:
			get_tree().paused = true
	emit_signal("game_state_changed", new_state)

func start_new_run(map_id: String, difficulty: String) -> void:
	quest_notes.clear()
	run_id = str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec())
	run_finalized = false
	practice_mode = false
	final_result.clear()
	selection_queue.clear()
	current_selection.clear()
	selection_serial = 0
	gold_carry = 0
	exp_carry = 0
	warehouse_xp_carry = 0
	total_xp_collected = 0
	evolved_count = 0
	_quest_second = -1
	_finish_scheduled = false
	_boss_won = false
	selected_map_id = map_id
	selected_difficulty = difficulty
	game_time = 0.0
	is_boss_active = false
	boss_timer = 0.0
	boss_enraged_state = false
	current_boss_node = null

	team_level = 1
	current_team_exp = 0
	required_team_exp = calculate_required_exp_for_level(1)
	team_gold_earned = 0
	total_run_kills = 0
	total_damage_dealt = 0.0
	pending_level_up_players.clear()
	active_player_nodes.clear()

	set_state(GameState.GAMEPLAY)

func get_difficulty_multipliers() -> Dictionary:
	match selected_difficulty:
		"hard":
			return {"enemy_hp": 3.0, "phys_dmg": 2.0, "magic_dmg": 1.5, "gold_mult": 1.5}
		"extreme":
			return {"enemy_hp": 7.0, "phys_dmg": 3.0, "magic_dmg": 2.0, "gold_mult": 2.25}
		_: # story
			return {"enemy_hp": 1.0, "phys_dmg": 1.0, "magic_dmg": 1.0, "gold_mult": 1.0}

func get_player_count_hp_multiplier(enemy_id: String = "") -> float:
	var count := get_active_player_count()
	if selected_map_id=="map_warehouse": return preload("res://scripts/game/warehouse_balance.gd").hp(count,enemy_id)
	match count:
		2: return 1.6
		3: return 2.2
		4: return 2.8
		_: return 1.0

func get_warehouse_density() -> float:
	return preload("res://scripts/game/warehouse_balance.gd").density(get_active_player_count())

func normalized_warehouse_xp(raw: int, scale: float) -> int:
	if raw<=0: return 0
	var total := raw*scale+warehouse_xp_carry
	var result := floori(total+0.0000001)
	warehouse_xp_carry=maxf(0.0,total-result)
	return result

func get_enemy_time_multipliers(at_time: float = -1.0) -> Vector2:
	var seconds := clampf(game_time if at_time<0 else at_time,0,900)
	# Explicit at_time remains the reference curve; live Warehouse Story strength
	# follows the same twenty-second grace period as its enemy phase transitions.
	if at_time<0 and selected_map_id=="map_warehouse" and selected_difficulty=="story":
		seconds=maxf(0,seconds-20)
	var curve: Array = preload("res://scripts/core/swarm_balance.gd").data()["enemy_time_scaling"]
	for index in range(1,curve.size()):
		var previous: Dictionary = curve[index-1]
		var next: Dictionary = curve[index]
		if seconds <= float(next["time"]):
			var fraction := (seconds-float(previous["time"]))/float(next["time"]-previous["time"])
			return Vector2(lerpf(previous["hp"],next["hp"],fraction),lerpf(previous["damage"],next["damage"],fraction))
	return Vector2(curve.back()["hp"],curve.back()["damage"])

func get_active_player_count() -> int:
	var count := 0
	for s in ProfileManager.player_slots:
		if s["active"]:
			count += 1
	return maxi(1, count)

func calculate_required_exp_for_level(lvl: int) -> int:
	var tuning: Dictionary = preload("res://scripts/core/swarm_balance.gd").progression_tuning()
	return ceili(calculate_reference_exp_for_level(lvl)*float(tuning["level_cost_multipliers"].get(str(lvl),1.0)))

func calculate_reference_exp_for_level(lvl: int) -> int:
	var curve: Array = preload("res://scripts/game/warehouse_timeline.gd").reference_data()["experience"]["cumulative"]
	var index := clampi(lvl-1,0,curve.size()-1)
	return int(curve[index])-int(curve[index-1] if index>0 else 0)

func add_team_exp(amount: int) -> void:
	if run_finalized or amount <= 0 or team_level >= StatCalculator.MAX_LEVEL:
		return
	current_team_exp += amount
	total_xp_collected += amount
	AudioManager.play_sfx("coin", 1.4)

	# Swarm exceeds the displayed threshold: 5/5, then one additional XP.
	while current_team_exp > required_team_exp and team_level < StatCalculator.MAX_LEVEL:
		current_team_exp -= required_team_exp + 1
		team_level += 1
		required_team_exp = calculate_required_exp_for_level(team_level)
		# Team gold bonus (+10 gold for level-ups)
		team_gold_earned += 10
		_trigger_team_level_up()

	emit_signal("team_exp_changed", current_team_exp, required_team_exp, team_level)

func _trigger_team_level_up() -> void:
	QuestManager.notify_event("char_level", team_level)
	for p in active_player_nodes:
		if is_instance_valid(p):
			QuestManager.notify_event("char_milestone_" + p.character_id, team_level, false, {"profile_id": p.profile_id})
	combat_event.emit("level_up", {"level": team_level})
	enqueue_selection("level", team_level)

func trigger_access_card() -> void:
	if run_finalized: return
	combat_event.emit("card", {})
	enqueue_selection("card", team_level)

func player_completed_level_up_selection(player_index: int, expected_id: int = -1) -> void:
	if expected_id >= 0 and expected_id != current_selection.get("id",-2): return
	if current_selection.is_empty() or not pending_level_up_players.has(player_index): return
	pending_level_up_players.erase(player_index)
	if pending_level_up_players.is_empty():
		current_selection.clear()
		call_deferred("_show_next_selection",run_id)

func spawn_map_boss() -> void:
	if run_finalized or is_boss_active or is_instance_valid(current_boss_node): return
	is_boss_active = true
	boss_spawn_game_time = game_time
	boss_timer = 0.0
	boss_enraged_state = false
	AudioManager.play_sfx("boss_spawn")

	var boss_name: String = ""
	match selected_map_id:
		"map_warehouse":
			boss_name = "Urzeit-Rexi"
		"map_outskirts":
			boss_name = "Ur-Brioche"
		"map_lab":
			boss_name = "Bella-Viech Prime"
		"map_beach":
			boss_name = "Aua-Trox, der Endgegner"
		_:
			boss_name = "Urzeit-Rexi"

	emit_signal("boss_spawned", boss_name)

func on_boss_killed(boss_name: String) -> void:
	if run_finalized or _boss_won: return
	_boss_won = true
	team_gold_earned += int(EnemyRegistry.get_enemy_data(current_map.boss_id).get("gold_drop", 500)) if is_instance_valid(current_map) else 500
	is_boss_active = false
	emit_signal("boss_defeated", boss_name)
	AudioManager.play_sfx("evolve")

	# Notify quests
	QuestManager.notify_event("boss_defeated", 1.0, true)
	match selected_map_id:
		"map_warehouse":
			QuestManager.notify_event("boss_kill", 1.0)
			if selected_difficulty != "story":
				QuestManager.notify_event("boss_hard_reksai", 1.0)
			if selected_difficulty == "extreme":
				QuestManager.notify_event("boss_extreme_reksai",1.0)
		"map_outskirts":
			QuestManager.notify_event("boss_kill_briar", 1.0)
		"map_lab":
			QuestManager.notify_event("boss_kill_belveth", 1.0)
			if selected_difficulty != "story":
				QuestManager.notify_event("boss_hard_belveth", 1.0)
		"map_beach":
			QuestManager.notify_event("boss_kill_aatrox", 1.0)
			if selected_difficulty != "story":
				QuestManager.notify_event("boss_hard_aatrox", 1.0)

	# End run in victory
	request_end(true)

func check_all_players_downed() -> void:
	if NetworkManager.is_client(): return
	if not has_living_players() and not active_player_nodes.is_empty():
		request_end(false)

func has_living_players() -> bool:
	for p in active_player_nodes:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and not p.is_downed and p.current_health > 0:
			return true
	return false

func end_run(victory: bool) -> void:
	if NetworkManager.is_client(): return
	if run_finalized: return
	victory = victory or _boss_won
	run_finalized = true
	selection_queue.clear()
	current_selection.clear()
	pending_level_up_players.clear()
	var final_gold = int(team_gold_earned * float(get_difficulty_multipliers()["gold_mult"]))
	final_result = {"run_id": run_id, "victory": victory, "gold": final_gold, "practice": practice_mode}
	if not practice_mode:
		QuestManager.notify_event("run_finished", 1.0, true)
		QuestManager.flush()
		final_result["saved"] = ProfileManager.record_run_stats_for_all(victory, game_time, total_run_kills, total_damage_dealt, final_gold, evolved_count, victory)
	set_state(GameState.RUN_VICTORY if victory else GameState.RUN_DEFEAT)


func enqueue_selection(kind: String, level: int = 1) -> void:
	if run_finalized: return
	selection_serial += 1
	selection_queue.append({"id": selection_serial, "run_id": run_id, "type": kind, "level": level})
	if current_selection.is_empty():
		_show_next_selection()

func _show_next_selection(token: String = "") -> void:
	if not token.is_empty() and token != run_id: return
	if run_finalized or not current_selection.is_empty(): return
	if selection_queue.is_empty():
		set_state(GameState.GAMEPLAY)
		return
	current_selection = selection_queue.pop_front()
	pending_level_up_players.clear()
	for p in active_player_nodes:
		if is_instance_valid(p): pending_level_up_players[p.player_slot_index] = 1
	if pending_level_up_players.is_empty():
		current_selection.clear()
		return
	set_state(GameState.LEVEL_UP_PAUSE)
	selection_requested.emit(current_selection.duplicate(true))

func request_end(victory: bool) -> void:
	if run_finalized: return
	_boss_won = _boss_won or victory
	if not _finish_scheduled:
		_finish_scheduled = true
		call_deferred("_resolve_end",run_id)

func _resolve_end(token: String) -> void:
	if token != run_id: return
	end_run(_boss_won)

func return_to_menu() -> void:
	if not run_finalized: end_run(false)
	QuestManager.flush()
	active_player_nodes.clear()
	current_boss_node = null
	current_map = null
	set_state(GameState.MENU)

func register_boss(boss: Node2D) -> void:
	current_boss_node = boss
	boss_created.emit(boss)

func retry_settlement() -> bool:
	if not run_finalized or practice_mode or final_result.is_empty(): return false
	QuestManager.flush()
	final_result["saved"] = ProfileManager.record_run_stats_for_all(final_result["victory"],game_time,total_run_kills,total_damage_dealt,final_result["gold"],evolved_count,final_result["victory"])
	return final_result["saved"]

func profile_elapsed(label: String, start_us: int) -> void:
	if profile_enabled: profile_totals[label] = float(profile_totals.get(label,0))+Time.get_ticks_usec()-start_us

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not run_finalized: end_run(false)

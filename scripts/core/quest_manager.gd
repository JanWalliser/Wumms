extends Node

# QuestManager - Event-driven objectives for the single-map release catalog.
# Synchronizes unlocks across all active player profiles without duplication.

signal quest_completed(quest_id: String, title: String, reward_desc: String)

var dirty_profiles: Dictionary = {}
var metric_index: Dictionary = {}
var flush_timer := 0.0
var all_quests: Dictionary = {}

func _ready() -> void:
	_init_quest_database()

func _init_quest_database() -> void:
	all_quests.clear()
	metric_index.clear()
	for objective in preload("res://scripts/progression/warehouse_progression.gd").OBJECTIVES:
		_add_quest(objective["id"],objective["title"],objective["reward_desc"],objective["metric"],objective["target"],objective["reward_type"],objective["reward_value"])

func _add_quest(id: String, title: String, reward_desc: String, metric: String, target: float, reward_type: String, reward_value: String) -> void:
	if not metric_index.has(metric): metric_index[metric] = []
	metric_index[metric].append(id)
	all_quests[id] = {
		"id": id,
		"title": title,
		"reward_desc": reward_desc,
		"metric": metric,
		"target": target,
		"reward_type": reward_type,
		"reward_value": reward_value
	}

# Event notification from gameplay
func notify_event(metric: String, value: float = 1.0, is_cumulative: bool = false, _context: Dictionary = {}) -> void:
	if not metric_index.has(metric) or GameManager.practice_mode: return
	var seen: Dictionary = {}
	var slots: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("ProfileManager"):
		var pm = tree.root.get_node("ProfileManager")
		slots = pm.player_slots

	for slot in slots:
		if not slot["active"]:
			continue
		var profile_id: String = slot["profile_id"]
		if seen.has(profile_id) or (_context.has("profile_id") and _context["profile_id"] != profile_id): continue
		seen[profile_id] = true
		var profile_data: Dictionary = {}
		if tree.root.has_node("SaveManager"):
			var sm = tree.root.get_node("SaveManager")
			profile_data = sm.load_profile(profile_id)

		if profile_data.is_empty():
			continue

		var completed: Array = profile_data.get("completed_quests", [])
		var progress: Dictionary = profile_data.get("quest_progress", {})
		var profile_modified := false

		for q_id in metric_index[metric]:
			if completed.has(q_id):
				continue
			var quest: Dictionary = all_quests[q_id]
			if quest["metric"] != metric:
				continue

			var current_val: float = float(progress.get(q_id, 0.0))
			if is_cumulative:
				current_val += value
			else:
				current_val = maxf(current_val, value)
			if current_val != float(progress.get(q_id, 0)): profile_modified = true
			progress[q_id] = current_val

			if current_val >= quest["target"]:
				completed.append(q_id)
				_apply_quest_reward(profile_data, quest)
				profile_modified = true
				emit_signal("quest_completed", q_id, quest["title"], quest["reward_desc"])

		if profile_modified and tree.root.has_node("SaveManager"):
			profile_data["completed_quests"] = completed
			profile_data["quest_progress"] = progress
			var sm = tree.root.get_node("SaveManager")
			sm.cache_profile(profile_data)
			dirty_profiles[profile_id] = true
			if tree.root.has_node("ProfileManager"):
				var pm = tree.root.get_node("ProfileManager")
				pm._update_slot_cache(profile_id, profile_data)

func _apply_quest_reward(profile: Dictionary, quest: Dictionary) -> void:
	var r_type: String = quest["reward_type"]
	var r_val: String = quest["reward_value"]

	match r_type:
		"weapon":
			var unlocked: Array = profile.get("unlocked_weapons", [])
			if not unlocked.has(r_val):
				unlocked.append(r_val)
				profile["unlocked_weapons"] = unlocked
		"passive":
			var unlocked: Array = profile.get("unlocked_passives", [])
			if not unlocked.has(r_val):
				unlocked.append(r_val)
				profile["unlocked_passives"] = unlocked
		"character":
			var unlocked: Array = profile.get("unlocked_characters", [])
			if not unlocked.has(r_val):
				unlocked.append(r_val)
				profile["unlocked_characters"] = unlocked
		"char_and_map":
			var parts := r_val.split(":")
			if parts.size() == 2:
				var c := parts[0]
				var m := parts[1]
				var unl_c: Array = profile.get("unlocked_characters", [])
				if not unl_c.has(c):
					unl_c.append(c)
					profile["unlocked_characters"] = unl_c
				var unl_m: Array = profile.get("unlocked_maps", [])
				if not unl_m.has(m):
					unl_m.append(m)
					profile["unlocked_maps"] = unl_m
		"map":
			var unlocked: Array = profile.get("unlocked_maps", [])
			if not unlocked.has(r_val):
				unlocked.append(r_val)
				profile["unlocked_maps"] = unlocked
		"difficulty":
			var unlocked: Array = profile.get("unlocked_difficulties", [])
			if not unlocked.has(r_val):
				unlocked.append(r_val)
				profile["unlocked_difficulties"] = unlocked
		"slot":
			var count := 3
			for objective in preload("res://scripts/progression/warehouse_progression.gd").SLOT_OBJECTIVES:
				if profile.get("completed_quests",[]).has(objective) or quest["id"]==objective: count+=1
			profile["passive_slots"] = maxi(int(profile.get("passive_slots",3)),mini(6,count))
		"gold":
			profile["gold"] = int(profile.get("gold", 0)) + int(r_val)
		"shop":
			var unlocks: Array = profile.get("unlocked_shop", [])
			if not unlocks.has(r_val): unlocks.append(r_val)
			profile["unlocked_shop"] = unlocks
		"feature":
			var features: Array = profile.get("features", [])
			if not features.has(r_val): features.append(r_val)
			profile["features"] = features
			if r_val == "extreme_and_anima":
				var unl_d: Array = profile.get("unlocked_difficulties", [])
				if not unl_d.has("extreme"):
					unl_d.append("extreme")
					profile["unlocked_difficulties"] = unl_d

func _process(delta: float) -> void:
	flush_timer += delta
	if flush_timer >= 5.0:
		flush_timer = 0.0
		flush()

func flush() -> void:
	for id in dirty_profiles.keys():
		if SaveManager.save_profile(SaveManager.load_profile(id)): dirty_profiles.erase(id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: flush()

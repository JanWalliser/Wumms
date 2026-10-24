extends Node

const PROFILES_DIR = "user://profiles/"
const CURRENT_SCHEMA_VERSION = 4
signal profile_saved(profile_id: String)
signal profile_loaded(profile_id: String)
signal save_failed(message: String)
var _cache: Dictionary = {}
var _unsupported: Dictionary = {}

func _ready() -> void:
	_ensure_profiles_directory()
	save_failed.connect(_show_save_error)

func _ensure_profiles_directory() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILES_DIR)

func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 100: return false
	for ch in id:
		if not ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return false
	return true

func get_profile_path(id: String) -> String:
	return PROFILES_DIR + id + ".json"

func get_backup_path(id: String) -> String:
	return get_profile_path(id) + ".bak"

func list_profile_ids() -> Array[String]:
	_ensure_profiles_directory()
	var result: Array[String] = []
	for name in DirAccess.get_files_at(PROFILES_DIR):
		if name.ends_with(".json") and valid_id(name.get_basename()): result.append(name.get_basename())
	result.sort()
	return result

func create_default_profile(profile_id: String, display_name: String) -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"id": profile_id,
		"name": display_name,
		"gold": 0,
		"created_at": Time.get_datetime_string_from_system(),
		"last_played": Time.get_datetime_string_from_system(),
		# Starter unlocks according to Swarm 2024 specifications:
		# Jankz (Jinx) and Sera-Föhn (Seraphine) available by default
		"unlocked_characters": ["jankz", "seraföhn"],
		# Standard weapons unlocked at start
		"unlocked_weapons": [
			"weapon_uwu_blaster",
			"weapon_slicers",
			"weapon_gatling",
			"weapon_shortbow",
			"weapon_lioness"
		],
		# Swarm starts with three passive types, separately from three inventory slots.
		"unlocked_passives": [
			"armor",
			"damage",
			"max_health"
		],
		"unlocked_augments": [],
		"unlocked_maps": ["map_warehouse"],
		"unlocked_difficulties": ["story"],
		"passive_slots": 3, # Starts at 3, can expand up to 6 via quests
		"shop_upgrades": {
			"damage": 0,
			"armor": 0,
			"max_health": 0,
			"health_regen": 0,
			"movement_speed": 0,
			"pickup_radius": 0,
			"area_size": 0,
			"duration": 0,
			"crit_chance": 0,
			"ability_haste": 0,
			"exp_gain": 0,
			"projectile_count": 0,
			"gold_multiplier": 0,
			"boon_duration": 0,
			"anima_power": 0
		},
		"completed_quests": [],
		"features": [],
		"unlocked_shop": [],
		"settled_runs": [],
		"story_chapters": {},
		"quest_progress": {},
		"stats": {
			"runs_played": 0,
			"runs_won": 0,
			"total_kills": 0,
			"total_boss_kills": 0,
			"total_damage_dealt": 0,
			"total_gold_earned": 0,
			"max_survival_time": 0.0,
			"weapons_evolved": 0
		}
	}


func _read_valid(path: String, id: String) -> Dictionary:
	_unsupported.erase(id)
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary: return {}
	var data: Dictionary = json.data
	if data.get("id", "") != id or not data.get("schema_version", 0) is float and not data.get("schema_version", 0) is int: return {}
	if int(data.get("schema_version", 0)) > CURRENT_SCHEMA_VERSION:
		_unsupported[id] = true
		return {}
	return _validate_and_migrate_profile(data)

func load_profile(id: String) -> Dictionary:
	var network = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if network and network.is_client() and network.remote_profiles.has(id):
		return network.remote_profiles[id].duplicate(true)
	if not valid_id(id): return {}
	if _cache.has(id): return _cache[id].duplicate(true)
	var data = _read_valid(get_profile_path(id), id)
	if _unsupported.has(id):
		_failed("Profil aus neuerer Spielversion bleibt unverändert: "+id)
		return {}
	if data.is_empty():
		data = _read_valid(get_backup_path(id), id)
		if _unsupported.has(id):
			_failed("Sicherung aus neuerer Spielversion bleibt unverändert: "+id)
			return {}
		if not data.is_empty():
			# Repair the primary before any later backup rotation.
			var file = FileAccess.open(get_profile_path(id), FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(data, "\t"))
				file.close()
	if not data.is_empty():
		_cache[id] = data.duplicate(true)
		profile_loaded.emit(id)
	return data.duplicate(true)

func cache_profile(data: Dictionary) -> void:
	if valid_id(str(data.get("id", ""))): _cache[data["id"]] = data.duplicate(true)

func invalidate_cache(id: String = "") -> void:
	if id.is_empty(): _cache.clear()
	else: _cache.erase(id)

func save_profile(profile_data: Dictionary) -> bool:
	var network = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if network and network.is_client(): return false
	var id = str(profile_data.get("id", ""))
	if not valid_id(id): return false
	var data = _validate_and_migrate_profile(profile_data.duplicate(true))
	if data.is_empty(): return false
	_ensure_profiles_directory()
	data["last_played"] = Time.get_datetime_string_from_system()
	var path = get_profile_path(id)
	var temp = path + ".tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if not file: return _failed("Profil konnte nicht geschrieben werden: " + id)
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var err = file.get_error()
	file.close()
	if err != OK: return _failed("Schreibfehler: " + id)
	var existing = _read_valid(path,id)
	if _unsupported.has(id): return _failed("Neuere Profilversion wird nicht überschrieben: "+id)
	if not existing.is_empty():
		if DirAccess.copy_absolute(path, get_backup_path(id)) != OK: return _failed("Sicherung fehlgeschlagen: " + id)
	if DirAccess.rename_absolute(temp,path) != OK: return _failed("Profil konnte nicht ersetzt werden: " + id)
	_cache[id] = data.duplicate(true)
	profile_saved.emit(id)
	return true

func _failed(message: String) -> bool:
	save_failed.emit(message)
	push_warning(message)
	return false

func _validate_and_migrate_profile(data: Dictionary) -> Dictionary:
	if not data.get("id",null) is String or not valid_id(data["id"]): return {}
	if not str(data.get("schema_version", 0)).is_valid_float() or int(data.get("schema_version",0)) > CURRENT_SCHEMA_VERSION: return {}
	var old_schema = int(data.get("schema_version",0))
	var defaults = create_default_profile(data["id"], str(data.get("name", "Spieler")))
	for key in defaults:
		if not data.has(key) or typeof(data[key]) != typeof(defaults[key]) and not (defaults[key] is int and data[key] is float):
			data[key] = defaults[key]
	if old_schema < 3:
		# Earlier defaults accidentally granted objective rewards. Remove only those
		# grants without completed-objective evidence; keep earned progress and gold.
		var gated := {"unlocked_weapons":{"weapon_blade_o_rang":"survive_2_min","weapon_crossbow":"yasüff_lvl_30","weapon_statikk":"reach_level_20","weapon_radiant_field":"fountain_4","weapon_iceblast":"lab_freeze","weapon_ani_mines":"trial_first","weapon_mega_blast":"lab_fuel","weapon_tibbers":"five_max_weapons"},"unlocked_passives":{"ability_haste":"blade_lvl_2","area_size":"elites_15","crit_chance":"vortex_lvl_4","health_regen":"survive_5_min","pickup_radius":"vacuums_5","exp_gain":"boxes_200"}}
		for key in gated:
			for id in gated[key]:
				if not data["completed_quests"].has(gated[key][id]): data[key].erase(id)
		var earned_slots := 3
		for objective in ["select_3_passives","belveth_hard","passives_hard_4"]:
			if data["completed_quests"].has(objective): earned_slots+=1
		data["passive_slots"] = earned_slots
	data["gold"] = maxi(0, int(data["gold"]))
	data["passive_slots"] = clampi(int(data["passive_slots"]),3,6)
	for key in defaults["shop_upgrades"]:
		var value = data["shop_upgrades"].get(key,0)
		data["shop_upgrades"][key] = clampi(int(value) if str(value).is_valid_float() else 0,0,int(ShopUpgradeRegistry.upgrades[key]["max_level"]))
	for key in defaults["stats"]:
		var value = data["stats"].get(key,0)
		data["stats"][key] = maxf(0,float(value)) if str(value).is_valid_float() else 0
	if data["unlocked_weapons"].has("weapon_cross_bow"):
		data["unlocked_weapons"].erase("weapon_cross_bow")
		if not data["unlocked_weapons"].has("weapon_crossbow"): data["unlocked_weapons"].append("weapon_crossbow")
	# Always guarantee standard starter unlocks exist even if an older or corrupted schema 2 file was saved
	for key in ["unlocked_weapons", "unlocked_passives", "unlocked_characters"]:
		for id in defaults[key]:
			if not data[key].has(id): data[key].append(id)
	var registries = {"unlocked_weapons": WeaponRegistry.weapons, "unlocked_passives": PassiveRegistry.passives, "unlocked_characters": CharacterRegistry.characters}
	for key in registries:
		data[key] = data[key].filter(func(id): return id is String and registries[key].has(id))
	if data["unlocked_characters"].is_empty(): data["unlocked_characters"] = ["jankz"]
	var retroactive = {"survive_hard_5_min":["features","belveth_trials"],"reach_level_30":["unlocked_shop","exp_gain"],"seraföhn_lvl_25":["unlocked_shop","projectile_count"],"survive_15_min":["features","boons_unlocked"],"kills_15k":["features","yuumi_quests"],"kills_40k":["features","reroll"],"aatrox_hard":["features","extreme_and_anima"]}
	for quest in retroactive:
		var reward = retroactive[quest]
		if data["completed_quests"].has(quest) and not data[reward[0]].has(reward[1]): data[reward[0]].append(reward[1])
	var allowed_arrays = {"unlocked_maps":["map_warehouse","map_outskirts","map_lab","map_beach"],"unlocked_difficulties":["story","hard","extreme"],"unlocked_shop":ShopUpgradeRegistry.upgrades.keys(),"unlocked_augments":AugmentRegistry.augments.keys(),"features":["boons_unlocked","yuumi_quests","belveth_trials","reroll","extreme_and_anima"]}
	for key in allowed_arrays:
		data[key] = data[key].filter(func(value): return value is String and allowed_arrays[key].has(value))
	for key in ["settled_runs","completed_quests"]: data[key] = data[key].filter(func(value): return value is String)
	for key in data["quest_progress"].keys():
		var value = data["quest_progress"][key]
		if not key is String or not str(value).is_valid_float(): data["quest_progress"].erase(key)
		else: data["quest_progress"][key] = maxf(0,float(value))
	for key in data["story_chapters"].keys():
		var value = data["story_chapters"][key]
		data["story_chapters"][key] = clampi(int(value),0,3) if str(value).is_valid_float() else 0
	preload("res://scripts/progression/warehouse_progression.gd").restore_unlocks(data,old_schema)
	data["schema_version"] = CURRENT_SCHEMA_VERSION
	return data

func delete_profile(id: String) -> bool:
	if not valid_id(id): return false
	var path = get_profile_path(id)
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK: return false
	for suffix in [".bak", ".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	_cache.erase(id)
	return true

func _show_save_error(message: String) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var label = Label.new()
	label.text = "Speichern fehlgeschlagen: " + message
	label.add_theme_color_override("font_color",Color(1,0.4,0.3))
	label.position = Vector2(30,100)
	layer.add_child(label)
	get_tree().create_timer(8).timeout.connect(layer.queue_free)

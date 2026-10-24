extends Node

# ProfileManager - Manages player profiles and assigns them to the 4 local player slots

signal player_slots_changed
signal profile_data_updated(profile_id: String)

const DEFAULT_PLAYER_COLORS := [
	Color(0.2, 0.6, 1.0, 1.0),  # Player 1: Cyan/Blue
	Color(1.0, 0.3, 0.3, 1.0),  # Player 2: Coral Red
	Color(0.3, 0.9, 0.4, 1.0),  # Player 3: Emerald Green
	Color(0.9, 0.7, 0.2, 1.0)   # Player 4: Golden Yellow
]

# Stores 4 player slots for local multiplayer
# Each entry is a Dictionary:
# {
#   "active": bool,
#   "profile_id": String,
#   "profile_data": Dictionary,
#   "device_id": int, # -1 = keyboard/mouse, 0..7 = gamepad id
#   "character_id": String, # selected character id
#   "color": Color,
#   "is_ready": bool
# }
var player_slots: Array[Dictionary] = []

func _ready() -> void:
	_init_player_slots()
	_ensure_default_profiles_exist()

func _init_player_slots() -> void:
	player_slots.clear()
	for i in range(4):
		player_slots.append({
			"active": (i == 0), # Player 1 is active by default
			"profile_id": "",
			"profile_data": {},
			"device_id": -1 if i == 0 else (i - 1),
			"character_id": "jankz",
			"color": DEFAULT_PLAYER_COLORS[i],
			"is_ready": true # Ready by default so start is never blocked
		})

func _ensure_default_profiles_exist() -> void:
	var profiles := SaveManager.list_profile_ids()
	for existing_id in profiles:
		if not SaveManager.load_profile(existing_id).is_empty():
			set_player_profile(0,existing_id)
			return
	# Preserve corrupt files and create a separate usable recovery profile.
	if not profiles.is_empty():
		var recovered_id = create_new_profile("Kartoffel-Rekrut")
		if not recovered_id.is_empty(): set_player_profile(0,recovered_id)
		return
	if profiles.is_empty():
		# Create initial profile
		var default_data := SaveManager.create_default_profile("profile_1", "Kartoffel-Krieger")
		SaveManager.save_profile(default_data)
		profiles = ["profile_1"]

	# Assign first profile to slot 0
	set_player_profile(0, profiles[0])

func get_all_profiles() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var ids := SaveManager.list_profile_ids()
	for id in ids:
		var data := SaveManager.load_profile(id)
		if not data.is_empty():
			list.append(data)
	return list

func create_new_profile(display_name: String) -> String:
	var base_id := "profile_" + str(int(Time.get_unix_time_from_system()))
	var id := base_id
	var counter := 1
	while SaveManager.list_profile_ids().has(id):
		id = "%s_%d" % [base_id, counter]
		counter += 1

	var data := SaveManager.create_default_profile(id, display_name)
	if not SaveManager.save_profile(data): return ""
	return id

func set_player_profile(slot_index: int, profile_id: String) -> void:
	if slot_index < 0 or slot_index >= player_slots.size():
		return

	var profile_data := SaveManager.load_profile(profile_id)
	if profile_data.is_empty():
		return

	player_slots[slot_index]["profile_id"] = profile_id
	player_slots[slot_index]["profile_data"] = profile_data
	# Validate selected character is unlocked
	var unlocked_chars: Array = profile_data.get("unlocked_characters", ["jankz"])
	if not unlocked_chars.has(player_slots[slot_index]["character_id"]):
		player_slots[slot_index]["character_id"] = unlocked_chars[0]

	emit_signal("player_slots_changed")

func set_slot_active(slot_index: int, is_active: bool) -> void:
	if slot_index < 0 or slot_index >= player_slots.size():
		return

	# Slot 0 must remain active if it's the only one
	if slot_index == 0 and not is_active:
		return

	player_slots[slot_index]["active"] = is_active
	if is_active and (player_slots[slot_index]["profile_id"] == "" or player_slots[slot_index]["profile_data"].is_empty()):
		var profiles := SaveManager.list_profile_ids()
		if not profiles.is_empty():
			var chosen := profiles[slot_index % profiles.size()]
			set_player_profile(slot_index, chosen)
		else:
			set_player_profile(slot_index, "profile_1")

	emit_signal("player_slots_changed")

func set_slot_device(slot_index: int, device_id: int) -> void:
	if slot_index >= 0 and slot_index < player_slots.size():
		player_slots[slot_index]["device_id"] = device_id
		emit_signal("player_slots_changed")

func set_slot_character(slot_index: int, character_id: String) -> void:
	if slot_index < 0 or slot_index >= player_slots.size() or not CharacterRegistry.characters.has(character_id): return
	if not SaveManager.load_profile(player_slots[slot_index]["profile_id"]).get("unlocked_characters",[]).has(character_id): return
	if slot_index >= 0 and slot_index < player_slots.size():
		player_slots[slot_index]["character_id"] = character_id
		emit_signal("player_slots_changed")

func set_slot_ready(slot_index: int, is_ready: bool) -> void:
	if slot_index >= 0 and slot_index < player_slots.size():
		player_slots[slot_index]["is_ready"] = is_ready
		emit_signal("player_slots_changed")

func are_all_active_slots_ready() -> bool:
	for slot in player_slots:
		if slot["active"] and not slot["is_ready"]:
			return false
	return true

func get_active_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in player_slots:
		if slot["active"]:
			result.append(slot)
	return result

func add_gold_to_profile(profile_id: String, amount: int) -> void:
	var data := SaveManager.load_profile(profile_id)
	if data.is_empty():
		return
	data["gold"] = max(0, int(data.get("gold", 0)) + amount)
	var stats: Dictionary = data.get("stats", {})
	if amount > 0:
		stats["total_gold_earned"] = int(stats.get("total_gold_earned", 0)) + amount
	data["stats"] = stats
	SaveManager.save_profile(data)
	_update_slot_cache(profile_id, data)
	emit_signal("profile_data_updated", profile_id)

func spend_gold(profile_id: String, amount: int) -> bool:
	var data := SaveManager.load_profile(profile_id)
	if data.is_empty():
		return false
	var current_gold: int = int(data.get("gold", 0))
	if amount < 0 or current_gold < amount:
		return false
	data["gold"] = current_gold - amount
	if not SaveManager.save_profile(data): return false
	_update_slot_cache(profile_id, data)
	emit_signal("profile_data_updated", profile_id)
	return true

func record_run_stats_for_all(victory: bool, survival_time: float, kills: int, damage_dealt: float, gold_earned: int, evolved_count: int, boss_killed: bool) -> bool:
	var success := true
	var seen: Dictionary = {}
	for slot in player_slots:
		if not slot["active"]:
			continue
		var profile_id: String = slot["profile_id"]
		var data := SaveManager.load_profile(profile_id)
		if data.is_empty():
			success = false
			continue
		if seen.has(profile_id): continue
		seen[profile_id] = true
		var ledger: Array = data.get("settled_runs", [])
		if ledger.has(GameManager.run_id): continue
		ledger.append(GameManager.run_id)
		data["settled_runs"] = ledger.slice(-100)
		if data.is_empty():
			continue

		var stats: Dictionary = data.get("stats", {})
		stats["runs_played"] = int(stats.get("runs_played", 0)) + 1
		if victory:
			stats["runs_won"] = int(stats.get("runs_won", 0)) + 1
		stats["total_kills"] = int(stats.get("total_kills", 0)) + kills
		if boss_killed:
			stats["total_boss_kills"] = int(stats.get("total_boss_kills", 0)) + 1
		stats["total_damage_dealt"] = float(stats.get("total_damage_dealt", 0.0)) + damage_dealt
		stats["total_gold_earned"] = int(stats.get("total_gold_earned", 0)) + gold_earned
		stats["weapons_evolved"] = int(stats.get("weapons_evolved", 0)) + evolved_count
		stats["max_survival_time"] = max(float(stats.get("max_survival_time", 0.0)), survival_time)

		data["stats"] = stats
		data["gold"] = int(data.get("gold", 0)) + gold_earned
		if not SaveManager.save_profile(data):
			success = false
			continue
		_update_slot_cache(profile_id, data)
		emit_signal("profile_data_updated", profile_id)
	return success

func _update_slot_cache(profile_id: String, new_data: Dictionary) -> void:
	for slot in player_slots:
		if slot["profile_id"] == profile_id:
			slot["profile_data"] = new_data

func buy_upgrade(profile_id: String, upgrade_id: String) -> bool:
	var data = SaveManager.load_profile(profile_id)
	if data.is_empty() or not ShopUpgradeRegistry.upgrades.has(upgrade_id): return false
	if not ShopUpgradeRegistry.is_unlocked_for_profile(upgrade_id,data): return false
	var rank = int(data["shop_upgrades"].get(upgrade_id,0))
	if rank >= int(ShopUpgradeRegistry.upgrades[upgrade_id]["max_level"]): return false
	var cost = ShopUpgradeRegistry.get_cost(upgrade_id,rank)
	if cost < 0 or int(data["gold"]) < cost: return false
	data["gold"] -= cost
	data["shop_upgrades"][upgrade_id] = rank+1
	if not SaveManager.save_profile(data): return false
	_update_slot_cache(profile_id,data)
	profile_data_updated.emit(profile_id)
	return true

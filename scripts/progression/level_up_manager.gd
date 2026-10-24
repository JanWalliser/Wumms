extends Node

# LevelUpManager - Generates valid 3-card choices for weapons, passives, evolutions, and fallback consumables

class_name LevelUpManager
const Evolution = preload("res://scripts/progression/evolution_rules.gd")

static func generate_choices_for_player(player: PlayerController, is_access_card: bool = false, exclude_ids: Array = []) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not is_instance_valid(player):
		return choices

	var profile := SaveManager.load_profile(player.profile_id)
	var unlocked_weapons: Array = profile.get("unlocked_weapons", [])
	var unlocked_passives: Array = profile.get("unlocked_passives", [])

	var defaults: Dictionary = SaveManager.create_default_profile("default", "Default")
	if unlocked_weapons.is_empty():
		unlocked_weapons = defaults["unlocked_weapons"]
	if unlocked_passives.is_empty():
		unlocked_passives = defaults["unlocked_passives"]

	var wc: WeaponController = player.weapon_controller

	# =========================================================================
	# 1. ACCESS CARD LOGIC (Strictly separated from standard level-up)
	# =========================================================================
	if is_access_card:
		var card_candidates: Array[Dictionary] = []
		if wc:
			# Prioritize weapon evolutions (equipped weapon Lv 5 + matching passive)
			for w in wc.equipped_weapons:
				if not w.is_evolved and w.level >= 5:
					var req_passive: String = w.data.get("evolution_requires", "")
					if Evolution.weapon_state(player,w.weapon_id)["ready"]:
						card_candidates.append({
							"type": "evolution",
							"id": w.weapon_id,
							"title": w.data.get("evolution_name", "Evolution"),
							"sub": "EVOLUTION!",
							"desc": w.data.get("evolution_desc", "Mächtige Weiterentwicklung"),
							"icon": "evolution"
						})
					else:
						print_verbose("[LevelUpManager] P%d excluded evolution '%s': missing required passive '%s'" % [player.player_slot_index + 1, w.weapon_id, req_passive])
				elif w.is_evolved:
					print_verbose("[LevelUpManager] P%d excluded evolution '%s': already evolved" % [player.player_slot_index + 1, w.weapon_id])
				else:
					print_verbose("[LevelUpManager] P%d excluded evolution '%s': level %d < 5" % [player.player_slot_index + 1, w.weapon_id, w.level])

			# If fewer than 3 choices, offer upgrades to existing equipped weapons (< 5)
			if card_candidates.size() < 3:
				for w in wc.equipped_weapons:
					if not w.is_evolved and w.level < 5:
						card_candidates.append({
							"type": "weapon_upgrade",
							"id": w.weapon_id,
							"title": w.data.get("display_name", "Waffe"),
							"sub": "Stufe %d -> %d" % [w.level, w.level + 1],
							"desc": "Erhöht Schaden und Geschosse",
							"icon": "weapon"
						})
						if card_candidates.size() >= 3: break

			# If still fewer than 3 choices, offer upgrades to equipped passives (< 5)
			if card_candidates.size() < 3:
				for p_id in player.passives.keys():
					var p_lvl: int = int(player.passives[p_id])
					if p_lvl < 5:
						var p_data := PassiveRegistry.get_passive_data(p_id)
						card_candidates.append({
							"type": "passive_upgrade",
							"id": p_id,
							"title": p_data.get("display_name", "Passiv"),
							"sub": "Stufe %d -> %d" % [p_lvl, p_lvl + 1],
							"desc": p_data.get("description", ""),
							"icon": "passive"
						})
						if card_candidates.size() >= 3: break

		# Filter excluded options when rerolling
		# Evolutions stay ahead of upgrades even if the previous roll showed them.
		var evolution_choices: Array[Dictionary] = []
		var evolution_fallback: Array[Dictionary] = []
		for candidate in card_candidates:
			if candidate.get("type","")!="evolution": continue
			if exclude_ids.has(candidate["id"]) or exclude_ids.has("evolution:"+str(candidate["id"])):
				evolution_fallback.append(candidate)
			else: evolution_choices.append(candidate)
		evolution_choices.append_array(evolution_fallback)
		for candidate in evolution_choices:
			choices.append(candidate) # At most five; never hide an eligible evolution.
		var card_preferred: Array[Dictionary] = []
		var card_fallback: Array[Dictionary] = []
		for c in card_candidates:
			if c.get("type","")=="evolution": continue
			var cid: String = c.get("id", "")
			var typed_id: String = c.get("type", "") + ":" + cid
			if exclude_ids.has(cid) or exclude_ids.has(typed_id):
				card_fallback.append(c)
			else:
				card_preferred.append(c)

		for c in card_preferred:
			if choices.size()>=3: break
			choices.append(c)
			if choices.size() >= 3: break
		if choices.size() < 3:
			for c in card_fallback:
				choices.append(c)
				if choices.size() >= 3: break

		# Fill remaining with fallback consumables so the 3-card modal always has 3 options
		while choices.size() < 3:
			if choices.size() % 2 == 0:
				choices.append({
					"type": "gold",
					"id": "gold_25",
					"title": "25 Dönerdublonen einsacken",
					"sub": "+25 Gold",
					"desc": "Bonus-Beute aus der Zugangskarte.",
					"icon": "gold"
				})
			else:
				choices.append({
					"type": "heal",
					"id": "heal_25",
					"title": "Notfall-Senfdusche",
					"sub": "+25% Heilung",
					"desc": "Stellt sofort 25% deines maximalen Lebens wieder her.",
					"icon": "heal"
				})

		return choices

	# =========================================================================
	# 2. STANDARD LEVEL-UP LOGIC
	# =========================================================================

	# A. Upgrade existing equipped weapons (if < 5 and not evolved)
	if wc:
		for w in wc.equipped_weapons:
			if not w.is_evolved and w.level < 5:
				choices.append({
					"type": "weapon_upgrade",
					"id": w.weapon_id,
					"title": w.data.get("display_name", "Waffe"),
					"sub": "Stufe %d -> %d" % [w.level, w.level + 1],
					"desc": "Erhöht Schaden und Geschosse",
					"icon": "weapon"
				})
			else:
				print_verbose("[LevelUpManager] P%d excluded weapon upgrade '%s': max level or evolved" % [player.player_slot_index + 1, w.weapon_id])

	# B. Add new weapon if slots available (< 5)
	if wc and not wc.is_full():
		for w_id in unlocked_weapons:
			if not wc.has_weapon(w_id):
				var w_data := WeaponRegistry.get_weapon_data(w_id)
				if not w_data.is_empty():
					choices.append({
						"type": "new_weapon",
						"id": w_id,
						"title": w_data.get("display_name", "Neue Waffe"),
						"sub": "NEUE WAFFE",
						"desc": w_data.get("description", ""),
						"icon": "weapon"
					})
			else:
				print_verbose("[LevelUpManager] P%d excluded new weapon '%s': already equipped" % [player.player_slot_index + 1, w_id])
	elif wc and wc.is_full():
		print_verbose("[LevelUpManager] P%d excluded all new weapons: 5/5 weapon slots full" % [player.player_slot_index + 1])

	# C. Upgrade existing passives (if < 5)
	for p_id in player.passives.keys():
		var p_lvl: int = int(player.passives[p_id])
		if p_lvl < 5:
			var p_data := PassiveRegistry.get_passive_data(p_id)
			choices.append({
				"type": "passive_upgrade",
				"id": p_id,
				"title": p_data.get("display_name", "Passiv"),
				"sub": "Stufe %d -> %d" % [p_lvl, p_lvl + 1],
				"desc": p_data.get("description", ""),
				"icon": "passive"
			})
		else:
			print_verbose("[LevelUpManager] P%d excluded passive upgrade '%s': max level 5" % [player.player_slot_index + 1, p_id])

	# D. Add new passives if passive slots available (< max_passive_slots)
	if player.passives.size() < player.max_passive_slots:
		for p_id in unlocked_passives:
			if not player.passives.has(p_id):
				var p_data := PassiveRegistry.get_passive_data(p_id)
				if not p_data.is_empty():
					choices.append({
						"type": "new_passive",
						"id": p_id,
						"title": p_data.get("display_name", "Neues Passiv"),
						"sub": "NEUES PASSIV",
						"desc": p_data.get("description", ""),
						"icon": "passive"
					})
			else:
				print_verbose("[LevelUpManager] P%d excluded new passive '%s': already equipped" % [player.player_slot_index + 1, p_id])
	else:
		print_verbose("[LevelUpManager] P%d excluded new passives: %d/%d slots full" % [player.player_slot_index + 1, player.passives.size(), player.max_passive_slots])

	# Partition valid options into preferred (not in exclude_ids) and fallback (in exclude_ids)
	var preferred: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for c in choices:
		var cid: String = c.get("id", "")
		var typed_id: String = c.get("type", "") + ":" + cid
		if exclude_ids.has(cid) or exclude_ids.has(typed_id):
			fallback.append(c)
		else:
			preferred.append(c)

	preferred.shuffle()
	fallback.shuffle()

	# Pick up to 3 from preferred, then fill from fallback if preferred has fewer than 3
	var result: Array[Dictionary] = []
	for c in preferred:
		result.append(c)
		if result.size() >= 3:
			break

	if result.size() < 3:
		for c in fallback:
			result.append(c)
			if result.size() >= 3:
				break

	# Fill remaining with fallback consumables ONLY if fewer than 3 valid options were found
	while result.size() < 3:
		if result.size() % 2 == 0:
			result.append({
				"type": "gold",
				"id": "gold_25",
				"title": "25 Dönerdublonen einsacken",
				"sub": "+25 Gold",
				"desc": "Sofortiger Goldbonus für den Run.",
				"icon": "gold"
			})
		else:
			result.append({
				"type": "heal",
				"id": "heal_25",
				"title": "Notfall-Senfdusche",
				"sub": "+25% Heilung",
				"desc": "Stellt sofort 25% deines maximalen Lebens wieder her.",
				"icon": "heal"
			})

	return result

static func apply_choice_to_player(player: PlayerController, choice: Dictionary) -> bool:
	if not is_instance_valid(player) or GameManager.run_finalized: return false
	var kind = choice.get("type", "")
	var id = choice.get("id", "")
	var profile = SaveManager.load_profile(player.profile_id)
	var unlocked_weapons: Array = profile.get("unlocked_weapons", [])
	var unlocked_passives: Array = profile.get("unlocked_passives", [])
	var defaults: Dictionary = SaveManager.create_default_profile("default", "Default")
	if unlocked_weapons.is_empty():
		unlocked_weapons = defaults["unlocked_weapons"]
	if unlocked_passives.is_empty():
		unlocked_passives = defaults["unlocked_passives"]

	match kind:
		"evolution":
			if GameManager.current_selection.get("type","")!="card": return false
			return player.weapon_controller.evolve_weapon(id)
		"weapon_upgrade": return player.weapon_controller.upgrade_weapon(id)
		"new_weapon":
			if not unlocked_weapons.has(id) or not WeaponRegistry.weapons.has(id) or player.weapon_controller.has_weapon(id): return false
			return player.weapon_controller.add_weapon(id)
		"passive_upgrade":
			if not player.passives.has(id) or int(player.passives[id]) >= 5: return false
			player.passives[id] += 1
		"new_passive":
			if player.passives.has(id) or player.passives.size() >= player.max_passive_slots or not unlocked_passives.has(id) or not PassiveRegistry.passives.has(id): return false
			player.passives[id] = 1
			QuestManager.notify_event("passives_in_run", player.passives.size(),false,{"profile_id":player.profile_id})
			if GameManager.selected_difficulty != "story": QuestManager.notify_event("passives_in_hard_run",player.passives.size(),false,{"profile_id":player.profile_id})
		"augment":
			if player.augments.size() >= 4 or player.augments.has(id) or not AugmentRegistry.augments.has(id): return false
			player.augments.append(id)
			player.register_augment(id)
			player._update_visuals()
		"gold": GameManager.team_gold_earned += 25
		"heal": player.heal(player.get_stat("max_health") * 0.25)
		_: return false
	player.recalculate_stats()
	return true

static func augment_choices(player: PlayerController, exclude_ids: Array = []) -> Array[Dictionary]:
	if not SaveManager.load_profile(player.profile_id).get("features",[]).has("yuumi_quests"):
		return [{"type":"gold","id":"gold_25","title":"25 Dönerdublonen","sub":"MISSIONSBELOHNUNG","desc":"Miezi-Augments werden durch die Kill-Meilensteine freigeschaltet."}]
	var ids = AugmentRegistry.get_all_augment_ids()
	ids.shuffle()
	var preferred: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for id in ids:
		if player.augments.has(id): continue
		var data = AugmentRegistry.get_augment_data(id)
		var entry = {"type":"augment","id":id,"title":data["display_name"],"sub":"MIEZI-AUGMENT","desc":data["description"]}
		if exclude_ids.has(id) or exclude_ids.has("augment:" + id):
			fallback.append(entry)
		else:
			preferred.append(entry)

	var result: Array[Dictionary] = []
	for c in preferred:
		result.append(c)
		if result.size() >= 3: break
	if result.size() < 3:
		for c in fallback:
			result.append(c)
			if result.size() >= 3: break
	return result if player.augments.size() < 4 else [{"type":"gold","id":"gold_25","title":"25 Dönerdublonen","sub":"VOLL AUSGEBAUT","desc":"Alle Augmentplätze belegt."}]

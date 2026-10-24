extends RefCounted
static var _recipes: Dictionary = {}

static func recipe_data(id: String) -> Dictionary:
	if not _recipes.has(id): _recipes[id]=WeaponRegistry.get_weapon_data(id)
	return _recipes[id]

# One source of truth for offers, validation, recipes and live HUD status.
static func weapon_state(player, id: String) -> Dictionary:
	var data := recipe_data(id)
	var passive: String = data.get("evolution_requires","")
	var rank := 0
	var evolved := false
	if is_instance_valid(player) and player.weapon_controller:
		for weapon in player.weapon_controller.equipped_weapons:
			if weapon.weapon_id==id:
				rank=weapon.level
				evolved=weapon.is_evolved
	var passive_rank := int(player.passives.get(passive,0)) if is_instance_valid(player) else 0
	var ready: bool = not evolved and rank>=5 and passive_rank>=1 and not passive.is_empty() and not str(data.get("evolution_id","")).is_empty()
	var status := "Evolviert" if evolved else ("Evolution bereit · Zugangskarte sammeln" if ready else ("Waffe auf Stufe 5 bringen" if passive_rank>=1 else ("Passive fehlt" if rank>=5 else "Stufe 5 und Passive fehlen")))
	return {"ready":ready,"evolved":evolved,"rank":rank,"passive_rank":passive_rank,"passive":passive,"status":status,"data":data}

static func weapon_recipe(player, id: String) -> String:
	var state := weapon_state(player,id)
	var data: Dictionary = state["data"]
	var passive_name: String = PassiveRegistry.get_passive_data(state["passive"]).get("display_name",state["passive"])
	return "%s · Stufe %d/5\n+ %s · Stufe %d/1\n→ %s\n%s" % [data.get("display_name",id),state["rank"],passive_name,mini(1,state["passive_rank"]),data.get("evolution_name","Evolution"),state["status"]]

static func passive_matches(player, id: String, equipped_only: bool = false) -> Array[String]:
	var owned: Array[String] = []
	var other: Array[String] = []
	for weapon_id in WeaponRegistry.get_all_weapon_ids():
		var state := weapon_state(player,weapon_id)
		if state["passive"]!=id: continue
		if state["rank"]>0: owned.append(weapon_id)
		elif not equipped_only and WeaponRegistry.get_general_weapon_ids().has(weapon_id): other.append(weapon_id)
	owned.append_array(other)
	return owned

static func choice_recipe(player, choice: Dictionary) -> String:
	var id: String = choice.get("id","")
	if choice.get("type","") in ["new_weapon","weapon_upgrade","evolution"]:
		var state := weapon_state(player,id)
		var passive_name: String = PassiveRegistry.get_passive_data(state["passive"]).get("display_name",state["passive"])
		return "Stufe 5 + %s (1)\n→ %s\n%s" % [passive_name,state["data"].get("evolution_name","Evolution"),state["status"]]
	if choice.get("type","") in ["new_passive","passive_upgrade"]:
		var names: Array[String] = []
		var matches := passive_matches(player,id,true)
		if matches.is_empty(): matches=passive_matches(player,id)
		for weapon_id in matches:
			var state := weapon_state(player,weapon_id)
			names.append(str(state["data"].get("display_name",weapon_id))+(" (ausgerüstet)" if state["rank"]>0 else ""))
		if names.is_empty(): return "Kein Evolutionsrezept für deine Waffen."
		return "Ermöglicht Evolution ab Waffenstufe 5:\n"+", ".join(names)+"\nEine Passivstufe genügt · Zugangskarte nötig"
	return ""

static func passive_tooltip(player, id: String) -> String:
	var text: String = PassiveRegistry.get_passive_data(id).get("display_name",id)
	for weapon_id in passive_matches(player,id,true): text+="\n\n"+weapon_recipe(player,weapon_id)
	return text

static func recipe_book(player) -> String:
	var text := "REZEPTBUCH · Waffenstufe 5 + Passive Stufe 1 + Zugangskarte\n"
	var ids := WeaponRegistry.get_general_weapon_ids()
	if player.weapon_controller:
		for weapon in player.weapon_controller.equipped_weapons:
			if not ids.has(weapon.weapon_id): ids.push_front(weapon.weapon_id)
	for id in ids:
		var data := recipe_data(id)
		var passive_name: String = PassiveRegistry.get_passive_data(data.get("evolution_requires","")).get("display_name","")
		text+="%s + %s → %s\n" % [data.get("display_name",id),passive_name,data.get("evolution_name","")]
	return text

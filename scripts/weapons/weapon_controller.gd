extends Node2D

# WeaponController - Manages up to 5 weapons (1 starter + 4 slots) on a PlayerController

class_name WeaponController

signal weapon_added(weapon_id: String, level: int)
signal weapon_upgraded(weapon_id: String, level: int)
signal weapon_evolved(weapon_id: String, evolution_id: String)

const MAX_WEAPONS: int = 5

var equipped_weapons: Array[WeaponInstance] = []
var host_player: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	host_player = get_parent()

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		return
	if not host_player or host_player.is_downed:
		return
	for w in equipped_weapons:
		w.update(delta)

func add_weapon(weapon_id: String) -> bool:
	if not WeaponRegistry.weapons.has(weapon_id): return false
	if has_weapon(weapon_id):
		return upgrade_weapon(weapon_id)

	if equipped_weapons.size() >= MAX_WEAPONS:
		return false

	var instance := WeaponInstance.new(weapon_id, host_player)
	equipped_weapons.append(instance)
	emit_signal("weapon_added", weapon_id, 1)
	QuestManager.notify_event("weapon_level_reached", 1.0)
	return true

func upgrade_weapon(weapon_id: String) -> bool:
	for w in equipped_weapons:
		if w.weapon_id == weapon_id:
			var upgraded := w.upgrade()
			if upgraded:
				emit_signal("weapon_upgraded", weapon_id, w.level)
				QuestManager.notify_event("weapon_level_reached", float(w.level))
				var maxed := 0
				for equipped in equipped_weapons:
					if equipped.level>=5: maxed+=1
				var context := {"profile_id":host_player.profile_id}
				QuestManager.notify_event("max_weapons_in_run",maxed,false,context)
				if weapon_id=="weapon_blade_o_rang": QuestManager.notify_event("weapon_level_blade",w.level,false,context)
				if weapon_id=="weapon_vortex_glove": QuestManager.notify_event("weapon_level_vortex",w.level,false,context)
				if weapon_id == "weapon_shortbow" and w.level >= 2:
					QuestManager.notify_event("weapon_level_shortbow", 2.0,false,{"profile_id":host_player.profile_id})
				elif weapon_id == "weapon_radiant_field" and w.level >= 4:
					QuestManager.notify_event("weapon_level_radiant", 4.0,false,{"profile_id":host_player.profile_id})
			return upgraded
	return false

func evolve_weapon(weapon_id: String) -> bool:
	for w in equipped_weapons:
		if w.weapon_id == weapon_id:
			if not preload("res://scripts/progression/evolution_rules.gd").weapon_state(host_player,weapon_id)["ready"]: return false
			w.evolve()
			GameManager.evolved_count += 1
			emit_signal("weapon_evolved", weapon_id, w.data.get("evolution_id", ""))
			QuestManager.notify_event("weapon_evolved", 1.0, true)
			QuestManager.notify_event("evolve_weapon", 1.0)
			return true
	return false

func has_weapon(weapon_id: String) -> bool:
	for w in equipped_weapons:
		if w.weapon_id == weapon_id:
			return true
	return false

func get_weapon_level(weapon_id: String) -> int:
	for w in equipped_weapons:
		if w.weapon_id == weapon_id:
			return w.level
	return 0

func is_weapon_evolved(weapon_id: String) -> bool:
	for w in equipped_weapons:
		if w.weapon_id == weapon_id:
			return w.is_evolved
	return false

func is_full() -> bool:
	return equipped_weapons.size() >= MAX_WEAPONS

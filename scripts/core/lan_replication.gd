extends RefCounted

## Only the host simulates. Replicas keep the existing drawing code, but never
## execute combat, timers, collisions, random choices or profile settlement.
const SCENES := {
	"enemy": "res://scenes/enemies/enemy_base.tscn",
	"boss": "res://scenes/enemies/boss_base.tscn",
	"projectile": "res://scenes/combat/projectile_base.tscn",
	"drop": "res://scenes/combat/drop_item.tscn",
	"crate": "res://scenes/combat/loot_crate.tscn",
	"soldier": "res://scenes/enemies/enemy_base.tscn",
	"vase": "res://scenes/combat/loot_crate.tscn"
}
const SCRIPTS := {
	"effect": "res://scripts/combat/runtime_effect.gd",
	"challenge": "res://scripts/game/swarm_challenge.gd",
	"formation": "res://scripts/game/shield_formation.gd",
	"soldier": "res://scripts/enemies/shield_soldier.gd",
	"vase": "res://scripts/game/challenge_vase.gd"
}
const GAME_FIELDS := ["game_time", "team_level", "current_team_exp", "required_team_exp", "team_gold_earned", "total_run_kills", "total_damage_dealt", "is_boss_active", "boss_enraged_state", "run_finalized", "final_result", "quest_notes", "evolved_count", "practice_mode", "current_selection", "pending_level_up_players"]
const PLAYER_FIELDS := ["current_health", "current_shield", "current_stats", "passives", "max_passive_slots", "augments", "temp_buffs", "ability_e_cd", "ability_r_cd", "is_downed", "downed_timer", "auto_respawn_timer", "death_count", "last_aim_direction", "frenzy_time", "wall_time", "wall_direction", "echo_charges", "riven_charges", "feathers", "jinx_excited_until", "is_invulnerable_active", "invulnerable_timer", "actor_scale", "velocity"]
var replicas: Dictionary = {}

func kind(node: Node) -> String:
	if node is PlayerController: return "player"
	if node is BossController: return "boss"
	if node is Enemy: return "soldier" if node.get_script().resource_path.ends_with("shield_soldier.gd") else "enemy"
	if node is Projectile: return "projectile"
	if node is DropItem: return "drop"
	if node is LootCrate: return "vase" if node.get_script().resource_path.ends_with("challenge_vase.gd") else "crate"
	if node is RuntimeEffect: return "effect"
	if node.get_script():
		for id in ["challenge", "formation"]:
			if node.get_script().resource_path == SCRIPTS[id]: return id
	return ""

func read_fields(node: Object, fields: Array) -> Dictionary:
	var result := {}
	for field in fields: result[field] = node.get(field)
	return result

func write_fields(node: Object, fields: Dictionary) -> void:
	for field in fields:
		var current = node.get(field)
		if current is Array and fields[field] is Array: current.assign(fields[field])
		elif current is Dictionary and fields[field] is Dictionary: current.assign(fields[field])
		else: node.set(field, fields[field])

func plain(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal or value is NodePath: return false
	if value is Array:
		for item in value:
			if not plain(item): return false
	if value is Dictionary:
		for key in value:
			if not plain(key) or not plain(value[key]): return false
	return true

func visual_vars(node: Node) -> Dictionary:
	var data := {}
	for property in node.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var key: String = property.name
		if key in ["profile_id", "char_data", "base_stats", "player_slot_index", "character_id", "pending_shots", "hit_ids", "hit_entities", "damage_lockouts", "shared_hit_ids", "accounted", "carried", "entities", "soldiers"]: continue
		var value = node.get(key)
		if plain(value): data[key] = value
	return data

func capture(map: Node) -> Dictionary:
	var entities: Array = []
	_collect(map, entities)
	return {"game": read_fields(GameManager, GAME_FIELDS), "state": GameManager.current_state,
		"entities": entities, "map": read_fields(map, ["fountain_charge", "fountain_cooldown"]),
		"director": visual_vars(map.get_node("EventDirector"))}

func _collect(parent: Node, entities: Array) -> void:
	for child in parent.get_children():
		if child.is_queued_for_deletion(): continue
		var type := kind(child)
		if not type.is_empty():
			var data := {"id": child.get_instance_id(), "kind": type, "position": child.global_position,
				"rotation": child.rotation, "scale": child.scale, "modulate": child.modulate,
				"vars": read_fields(child, PLAYER_FIELDS) if type == "player" else visual_vars(child)}
			if type == "player":
				data["slot"] = child.player_slot_index
				data["weapons"] = []
				for weapon in child.weapon_controller.equipped_weapons:
					data["weapons"].append([weapon.weapon_id, weapon.level, weapon.is_evolved, weapon.cooldown_timer])
			if type == "effect":
				var config: Dictionary = child.config.duplicate()
				for key in config.keys():
					if not plain(config[key]): config.erase(key)
				data["vars"]["config"] = config
			data["refs"] = {}
			for field in ["source", "source_owner", "orbit_center_node"]:
				if field in child and is_instance_valid(child.get(field)):
					data["refs"][field] = child.get(field).get_instance_id()
			if child is PlayerController or child is Enemy:
				data["animation"] = read_fields(child.visual_animator, ["clock", "recoil", "fire_clock", "fire_direction", "facing_sector"])
				data["frozen"] = child.status_effects.is_stunned_or_frozen()
			if "sprite" in child and is_instance_valid(child.sprite):
				var sprite: Sprite2D = child.sprite
				data["sprite"] = [sprite.visible, sprite.modulate, sprite.scale]
				if not (child is PlayerController or child is Enemy):
					data["texture"] = sprite.texture.resource_path if sprite.texture else ""
			if type == "projectile" and child.missile_texture: data["missile"] = child.missile_texture.resource_path
			entities.append(data)
		# Challenges may own vases; players own only local presentation components.
		if type != "player": _collect(child, entities)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Area2D:
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
	for child in node.get_children(): freeze(child)

func prepare_client(map: Node) -> void:
	replicas.clear()
	freeze(map)
	map.camera.set_process(true)
	# Crates are also supplied by the host, including their destruction.
	for crate in map.get_tree().get_nodes_in_group("crates"): crate.queue_free()

func apply(map: Node, snapshot: Dictionary) -> void:
	write_fields(GameManager, snapshot["game"])
	write_fields(map, snapshot["map"])
	map.queue_redraw()
	var director := map.get_node("EventDirector")
	write_fields(director, snapshot["director"])
	director.queue_redraw()
	var present := {}
	for entity in snapshot["entities"]:
		var id: int = entity["id"]
		present[id] = true
		var node = replicas.get(id)
		if not is_instance_valid(node):
			node = _create(map, entity)
			if not is_instance_valid(node): continue
			replicas[id] = node
		write_fields(node, entity["vars"])
		var target: Vector2 = entity["position"]
		if not node.has_meta("lan_target") or node.global_position.distance_to(target) > 250:
			node.global_position = target
		node.set_meta("lan_target", target)
		node.rotation = entity["rotation"]
		node.scale = entity["scale"]
		node.modulate = entity["modulate"]
		if entity.has("animation"):
			write_fields(node.visual_animator, entity["animation"])
			node.visual_animator.update(0, node.velocity.length_squared() > 1, node.velocity.normalized(), entity["frozen"])
		if entity.has("sprite"):
			node.sprite.visible = entity["sprite"][0]
			node.sprite.modulate = entity["sprite"][1]
			node.sprite.scale = entity["sprite"][2]
		if entity.has("texture") and not entity["texture"].is_empty(): node.sprite.texture = load(entity["texture"])
		if entity.has("missile"): node.missile_texture = load(entity["missile"])
		if node is PlayerController:
			_sync_weapons(node, entity["weapons"])
			node.sync_health()
		if node is BossController: node.boss_health_updated.emit(node.current_health, node.max_health)
		node.queue_redraw()
	for id in replicas.keys():
		if not present.has(id):
			if is_instance_valid(replicas[id]):
				if replicas[id] is PlayerController:
					GameManager.active_player_nodes.erase(replicas[id])
					GameManager.players_ready.emit()
				replicas[id].queue_free()
			replicas.erase(id)
	for entity in snapshot["entities"]:
		var node = replicas.get(entity["id"])
		if not is_instance_valid(node): continue
		for field in entity["refs"]: node.set(field, replicas.get(entity["refs"][field]))
		if entity["kind"] == "challenge":
			director.challenge = node
			node.network_visual_update()
	GameManager.run_timer_updated.emit(GameManager.game_time)
	GameManager.team_exp_changed.emit(GameManager.current_team_exp, GameManager.required_team_exp, GameManager.team_level)
	GameManager.set_state(snapshot["state"])

func interpolate(delta: float) -> void:
	var weight := 1.0 - exp(-30.0 * delta)
	for node in replicas.values():
		if is_instance_valid(node) and node.has_meta("lan_target"):
			node.global_position = node.global_position.lerp(node.get_meta("lan_target"), weight)

func _create(map: Node, data: Dictionary) -> Node2D:
	var type: String = data["kind"]
	if type == "player":
		for player in GameManager.active_player_nodes:
			if player.player_slot_index == data["slot"]: return player
		return null
	var node: Node2D
	if SCENES.has(type):
		node = load(SCENES[type]).instantiate()
		if type in ["soldier", "vase"]: node.set_script(load(SCRIPTS[type]))
	elif SCRIPTS.has(type):
		var factory: Variant = load(SCRIPTS[type])
		node = factory.new()
	else: return null
	write_fields(node, data["vars"])
	map.add_child(node)
	freeze(node)
	if node is BossController: GameManager.register_boss(node)
	return node

func _sync_weapons(player: PlayerController, data: Array) -> void:
	var weapons: Array = player.weapon_controller.equipped_weapons
	while weapons.size() > data.size(): weapons.pop_back()
	for i in data.size():
		var item: Array = data[i]
		if i >= weapons.size():
			var weapon := WeaponInstance.new(item[0], player)
			weapons.append(weapon)
		var weapon: WeaponInstance = weapons[i]
		if weapon.weapon_id != item[0] or weapon.level != item[1] or weapon.is_evolved != item[2]:
			weapon.weapon_id = item[0]
			weapon.level = item[1]
			weapon.is_evolved = item[2]
			weapon.data = WeaponRegistry.get_weapon_data(weapon.weapon_id)
		weapon.cooldown_timer = item[3]

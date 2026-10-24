extends CharacterBody2D

# PlayerController - 1 of 1-4 local players. Controls character abilities, stats, weapons, downed/revive loop.

class_name PlayerController

signal health_changed(current_hp: float, max_hp: float, shield: float)
signal ability_e_cooldown_updated(current_cd: float, max_cd: float)
signal ability_r_cooldown_updated(current_cd: float, max_cd: float)
signal player_became_downed
signal player_revived_signal

@export var player_slot_index: int = 0

var last_aim_direction := Vector2.RIGHT
var aim_cached_until := -1.0
var aim_cached_target: Node2D
var magnet_clock := 0.0
var damage_grace := 0.0
var dash_timer := 0.0
var dash_velocity := Vector2.ZERO
var shield_layers: Array[Dictionary] = []
var frenzy_time := 0.0
var wall_time := 0.0
var wall_direction := Vector2.RIGHT
var echo_charges := 0
var riven_charges := 0
var boosted_attacks: Dictionary = {}
var life_generation := 0
var jinx_kills := 0
var jinx_excited_until := -1.0
var _jinx_last_speed_bonus := 0.0
var _jinx_last_active := false
var pending_jinx_abilities: Array[Dictionary] = []
var augment_state: Dictionary = {}
var augment_distance := 0.0
var augment_last_position := Vector2.INF
var immobile_clock := 0.0
var immobile_stacks := 0
var feathers: Array[Dictionary] = []
var passive_clock := 0.0
var vacuum_clock := 0.0
var effect_clock := 0.0
var crit_stacks: Array[float] = []
var moving_time := 0.0
var solar_marks: Dictionary = {}
var aura_hits: Dictionary = {}
var _last_dynamic: Dictionary = {}
var _flash: Tween
var profile_id: String = ""
var character_id: String = "jankz"
var actor_scale: float = 1.0
var visual_animator = preload("res://scripts/characters/actor_animator.gd").new()
var char_data: Dictionary = {}

# Stats
var base_stats: Dictionary = {}
var current_stats: Dictionary = {}
var current_health: float = 450.0
var current_shield: float = 0.0

# Progression slots
var passives: Dictionary = {} # passive_id -> level (1..5)
var max_passive_slots: int = 3 # 3 to 6
var augments: Array = [] # max 4
var temp_buffs: Dictionary = {} # buff_name -> { "duration": float, "stats": Dictionary }

# Abilities
var ability_e_cd: float = 0.0
var ability_e_max_cd: float = 10.0
var ability_r_cd: float = 0.0
var ability_r_max_cd: float = 35.0

# Downed & Revive Mechanics
var is_downed: bool = false
var death_count: int = 0
var downed_timer: float = 0.0
var downed_revive_delay: float = 10.0 # 10s before teammates can revive
var auto_respawn_timer: float = 0.0
var auto_respawn_duration: float = 15.0 # Starts at 15s, increases by 9s per death up to 60s
var living_collision_layer := 1
var living_collision_mask := 49
var is_invulnerable_active: bool = false
var invulnerable_timer: float = 0.0

# Subcomponents
var weapon_controller: WeaponController = null
var status_effects: StatusEffectSystem = null

# Visual elements
@onready var sprite: Sprite2D = $Sprite2D
@onready var color_ring: Sprite2D = $ColorRing
@onready var health_bar: ProgressBar = $HealthBar
@onready var revive_zone: Area2D = $ReviveZone

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("players")
	status_effects = StatusEffectSystem.new(self)
	_setup_weapon_controller()
	_apply_initial_character_data()

func setup(slot_idx: int, p_id: String, c_id: String) -> void:
	player_slot_index = slot_idx
	if p_id.is_empty():
		var ids := SaveManager.list_profile_ids()
		profile_id = ids[0] if not ids.is_empty() else "profile_1"
	else:
		profile_id = p_id
	character_id = c_id if not c_id.is_empty() else "jankz"
	if is_node_ready():
		_apply_initial_character_data()

func _setup_weapon_controller() -> void:
	weapon_controller = WeaponController.new()
	add_child(weapon_controller)

func _apply_initial_character_data() -> void:
	_reset_jinx_passive()
	char_data = CharacterRegistry.get_character_data(character_id)
	base_stats = char_data.get("base_stats", {}).duplicate()
	base_stats["character_id"] = character_id

	# Read passive slot cap from profile if present
	var profile := SaveManager.load_profile(profile_id)
	max_passive_slots = clamp(int(profile.get("passive_slots", 3)), 3, 6)

	ability_e_max_cd = float(char_data.get("ability_e", {}).get("cooldown", 10.0))
	ability_r_max_cd = float(char_data.get("ability_r", {}).get("cooldown", 35.0))

	# Recalculate stats
	recalculate_stats()
	current_health = current_stats.get("max_health", 500.0)

	# Equip starting weapon
	var starter_weapon: String = char_data.get("starter_weapon", "weapon_meow_meow")
	if weapon_controller and not weapon_controller.has_weapon(starter_weapon):
		weapon_controller.add_weapon(starter_weapon)

	_update_visuals()

func recalculate_stats() -> void:
	var profile := SaveManager.load_profile(profile_id)
	max_passive_slots = clampi(int(profile.get("passive_slots",3)),3,6)
	var shop_upgrades: Dictionary = profile.get("shop_upgrades", {})

	# Flatten active temp buff values
	var flat_buffs: Dictionary = {}
	for b_name in temp_buffs.keys():
		var b_stats: Dictionary = temp_buffs[b_name].get("stats", {})
		for s_key in b_stats.keys():
			if s_key in ["damage_pct","area_pct","max_health_pct","speed_pct"]: flat_buffs[s_key]=(1+float(flat_buffs.get(s_key,0)))*(1+float(b_stats[s_key]))-1
			else: flat_buffs[s_key] = float(flat_buffs.get(s_key, 0.0)) + float(b_stats[s_key])

	# Passive lifetime is owned by the passive, never by refreshable/duration-scaled buffs.
	if is_jinx_excited():
		flat_buffs["jinx_speed_pct"] = _jinx_speed_bonus()
		flat_buffs["ability_haste"] = float(flat_buffs.get("ability_haste",0))+150.0
	current_stats = StatCalculator.compute_player_stats(
		base_stats,
		shop_upgrades,
		passives,
		augments,
		flat_buffs
	)

	# Keep health within new bounds
	var max_hp: float = float(current_stats.get("max_health", 500.0))
	current_health = clampf(current_health, 0.0, max_hp)
	emit_signal("health_changed", current_health, max_hp, current_shield)

func get_stat(stat_name: String, default_val: float = 0.0) -> float:
	return float(current_stats.get(stat_name, default_val))

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		velocity = Vector2.ZERO
		return

	# Status effects update
	if status_effects:
		status_effects.update(delta)

	# Invulnerability timer
	if is_invulnerable_active:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0:
			is_invulnerable_active = false
			modulate.a = 1.0

	_runtime_update(delta)
	_update_temporary_buffs(delta)
	_process_abilities(delta)
	# Downed logic
	if is_downed:
		queue_redraw()
		_process_downed_state(delta)
		return

	# Health Regeneration
	var regen: float = float(current_stats.get("health_regen", 0.0))
	if regen > 0.0 and current_health < current_stats.get("max_health", 500.0):
		# Registry and upgrade regen values are HP per five seconds, not HP/second.
		current_health = minf(current_stats.get("max_health", 500.0), current_health + regen * delta / 5.0)
		emit_signal("health_changed", current_health, current_stats.get("max_health", 500.0), current_shield)


	# Movement
	var move_vec := InputManager.get_movement_vector(player_slot_index)
	var speed: float = float(current_stats.get("movement_speed", 350.0))
	if status_effects:
		speed *= status_effects.get_speed_multiplier()

	if temp_buffs.has("bonus_cruise"):
		var avoid = Vector2.ZERO
		for projectile in get_tree().get_nodes_in_group("projectiles"):
			if projectile.target_group == "players":
				var away = global_position-projectile.global_position
				if away.length_squared()<40000: avoid += away.normalized()*(1-away.length()/200)
		move_vec = (move_vec+avoid*2).limit_length(1)
	# Convert movement into this map's world scale once, including ability dashes.
	velocity = (dash_velocity if dash_timer > 0 else move_vec * speed) * _get_movement_scale()
	move_and_slide()

	global_position = global_position.clamp(Vector2(-1800,-1800),Vector2(1800,1800))
	sync_health()
	queue_redraw()
	visual_animator.update(delta,velocity.length_squared()>1,velocity.normalized(),status_effects.is_stunned_or_frozen())


	# Pull nearby pickups within pickup_radius
	_process_pickup_magnet(delta)

func _process_abilities(delta: float) -> void:
	if ability_e_cd > 0.0:
		ability_e_cd -= delta
		emit_signal("ability_e_cooldown_updated", ability_e_cd, ability_e_max_cd)

	if ability_r_cd > 0.0:
		ability_r_cd -= delta
		emit_signal("ability_r_cooldown_updated", ability_r_cd, ability_r_max_cd)

	if character_id == "brioche" and frenzy_time > 0 and InputManager.is_ability_e_just_pressed(player_slot_index):
		_end_frenzy()
	if is_downed: return
	# E ability trigger (unlocked at team level 3)
	if GameManager.team_level >= 3 and ability_e_cd <= 0.0:
		if InputManager.is_ability_e_just_pressed(player_slot_index):
			_activate_ability_e()

	# R ability trigger (unlocked at team level 6)
	if GameManager.team_level >= 6 and ability_r_cd <= 0.0:
		if InputManager.is_ability_r_just_pressed(player_slot_index):
			_activate_ability_r()

func _activate_ability_e() -> void:
	ability_e_cd = StatCalculator.calculate_effective_cooldown(ability_e_max_cd, get_stat("ability_haste", 0.0)) * get_stat("cooldown_multiplier",1)
	AudioManager.play_sfx("shoot", 1.4)
	_on_ability()
	QuestManager.notify_event("ability_used", 1.0, true)

	match character_id:
		"jankz":
			_queue_jinx_ability("e")
		"seraföhn": # Surround-Schnitzel: Team shield + slow
			RuntimeEffect.spawn(get_parent(),self,global_position,{"visual":"sound","radius":350,"damage":0,"duration":0.6,"scale_duration":false})
			for ally in GameManager.active_player_nodes:
				if is_instance_valid(ally) and not ally.is_downed: ally.grant_shield(120,4)
			_slow_nearby_enemies(350.0, 3.0, 0.4)
		"löwina": # Eierklipse: 35 armor, explosion after 3s
			apply_temporary_buff("eclipse",3,{"armor":35})
			RuntimeEffect.spawn(get_parent(),self,global_position,{"visual":"eclipse","radius":40,"damage":0,"duration":3,"follow":true})
			var cast_life := life_generation
			var cast_run := GameManager.run_id
			get_tree().create_timer(3.0*get_stat("duration_multiplier",1), false).timeout.connect(func():
				if cast_life == life_generation and cast_run == GameManager.run_id and not is_downed and not GameManager.run_finalized:
					_trigger_radial_stun_explosion(200.0, 160.0)
			)
		"illaupsi": # Tentakel-Taschenschlag: giant tentacle smash
			_spawn_tentacle_smash(get_ability_aim_direction(), 180.0)
		"brioche": # Fisch-Fressflash: dash forward, frenzy
			frenzy_time = 6*get_stat("duration_multiplier",1)
			apply_temporary_buff("frenzy",6,{"speed_pct":0.4,"damage_pct":0.3})
			start_dash(get_ability_aim_direction(),800,0.3)
		"yasüff": # Wischmopp-Klinge: dash through enemies
			start_dash(get_ability_aim_direction(),750,0.3)
			_trigger_radial_damage(global_position, 120.0, 90.0)
		"rübenrambo": # Heldenmumpitz: dash & shield
			grant_shield(150,2.5)
			start_dash(get_ability_aim_direction(),650,0.3)
		"auarora": # Durch den Duschvorhang: leap back, 2s invulnerable
			is_invulnerable_active = true
			invulnerable_timer = 2.0
			start_dash(get_ability_aim_direction(),600,0.25)
			apply_temporary_buff("veil",2,{"speed_pct":0.5})
			modulate.a = 0.5
		"xayaya": # Feder-Fang-Furie: recall feathers, damage and root
			_trigger_bladecaller()

func _activate_ability_r() -> void:
	ability_r_cd = StatCalculator.calculate_effective_cooldown(ability_r_max_cd, get_stat("ability_haste", 0.0) + (100.0 if augments.has("augment_ultimate_speed_up") else 0.0)) * get_stat("cooldown_multiplier",1)
	AudioManager.play_sfx("evolve", 1.2)
	_on_ability()
	QuestManager.notify_event("ability_used", 1.0, true)

	match character_id:
		"jankz": # Super-Mega-Todesgurke
			_queue_jinx_ability("r")
		"seraföhn": # Die perfekte Furznote: charm & stun all on screen
			_screen_wide_stun_and_damage(250.0, 3.0)
		"löwina": # Sonnenexplodierter Käsekuchen: solar beam
			_spawn_solar_flare()
		"illaupsi": # Glaubens-Gummisprung: leap & 4 tentacles
			_leap_and_spawn_tentacles()
		"brioche": # Brioche-Bombardement: dive bomb across arena
			_dive_bomb(get_ability_aim_direction())
		"yasüff": # Windel-Wand: blocks projectiles
			_spawn_wind_wall(get_ability_aim_direction())
		"rübenrambo": # Klinge des Exzesses: giant wind cone
			_spawn_wind_slash_cone(get_ability_aim_direction())
		"auarora": # Zwischen zwei Waffeln: realm portal
			_spawn_spirit_domain()
		"xayaya": # Besteck-Bombardement: feather storm
			_spawn_featherstorm()

func get_ability_aim_direction() -> Vector2:
	# Active abilities are always manual; auto-aim belongs only to weapons.
	var manual := InputManager.get_aim_vector(player_slot_index,global_position,get_viewport())
	if manual.length_squared()>0.001:
		last_aim_direction=manual.normalized()
	return last_aim_direction

func get_ability_target_position(max_range: float) -> Vector2:
	if ProfileManager.player_slots[player_slot_index]["device_id"] <= -100:
		var point: Vector2 = NetworkManager.remote_inputs.get(player_slot_index, {}).get("mouse", global_position + last_aim_direction * max_range)
		return global_position + (point - global_position).limit_length(max_range)
	if ProfileManager.player_slots[player_slot_index]["device_id"] == -1:
		return global_position+(InputManager.get_mouse_world_position(get_viewport())-global_position).limit_length(max_range)
	return global_position+get_ability_aim_direction()*max_range

func get_aim_direction() -> Vector2:
	var is_auto := InputManager.is_auto_aim_enabled(player_slot_index)
	if is_auto:
		var target := _find_closest_enemy()
		if target:
			return (target.global_position - global_position).normalized()

	var aim_input := InputManager.get_aim_vector(player_slot_index, global_position, get_viewport())
	if aim_input != Vector2.ZERO:
		last_aim_direction = aim_input
		return aim_input

	if velocity.length_squared() > 1.0: last_aim_direction = velocity.normalized()
	return last_aim_direction

func _find_closest_enemy() -> Node2D:
	if GameManager.game_time < aim_cached_until and is_instance_valid(aim_cached_target) and not aim_cached_target.is_queued_for_deletion(): return aim_cached_target
	aim_cached_until = GameManager.game_time+0.15
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_d := 800.0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			var d := global_position.distance_to(enemy.global_position)
			if d < min_d:
				min_d = d
				closest = enemy
	aim_cached_target = closest
	return closest

func receive_damage(amount: float, is_crit: bool, attacker: Node2D = null) -> bool:
	if is_invulnerable():
		return false

	current_health -= amount
	_hit_flash()
	AudioManager.play_sfx("hit", 0.9)

	if current_health <= 0.0:
		current_health = 0.0
		sync_health()
		_enter_downed_state()
		return true

	emit_signal("health_changed", current_health, current_stats.get("max_health", 500.0), current_shield)
	return false

func absorb_shield(damage_in: float) -> float:
	var absorbed = minf(current_shield,damage_in)
	current_shield -= absorbed
	var left = absorbed
	for layer in shield_layers:
		var part = minf(float(layer["amount"]),left)
		layer["amount"] -= part
		left -= part
	sync_health()
	return damage_in-absorbed

func heal(amount: float) -> void:
	if is_downed:
		return
	var max_hp: float = float(current_stats.get("max_health", 500.0))
	var actual = minf(max_hp-current_health,maxf(0,amount))
	if actual <= 0: return
	current_health += actual
	if GameManager.game_time>=float(get_meta("next_heal_visual",-1)):
		set_meta("next_heal_visual",GameManager.game_time+1.0)
		RuntimeEffect.spawn(get_parent(),self,global_position,{"visual":"heal","radius":22*actor_scale,"damage":0,"duration":0.45,"scale_duration":false,"scale_area":false,"follow":true})
	DamageSystem.spawn_damage_number(global_position,actual,false,true)
	emit_signal("health_changed", current_health, max_hp, current_shield)

func _enter_downed_state() -> void:
	if is_downed or NetworkManager.is_client(): return
	is_downed = true
	current_health = 0
	velocity = Vector2.ZERO
	living_collision_layer = collision_layer
	living_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	life_generation += 1
	echo_charges = 0
	riven_charges = 0
	boosted_attacks.clear()
	solar_marks.clear()
	aura_hits.clear()
	feathers.clear()
	# Retire owned persistent casts even if a teammate revives us before their next tick.
	for effect in get_tree().get_nodes_in_group("runtime_effects"):
		if effect.source == self:
			effect.done = true
			effect.queue_free()
	_reset_jinx_passive()
	recalculate_stats()
	pending_jinx_abilities.clear()
	set_meta("iceblast_armed",false)
	if has_meta("iceblast_shield_weapon"): remove_meta("iceblast_shield_weapon")
	if weapon_controller:
		for weapon in weapon_controller.equipped_weapons: weapon.pending_shots.clear()
	dash_timer = 0
	frenzy_time = 0
	wall_time = 0
	temp_buffs.erase("frenzy")
	temp_buffs.erase("eclipse")
	temp_buffs.erase("veil")
	temp_buffs.erase("exile")
	recalculate_stats()
	death_count += 1
	downed_timer = downed_revive_delay
	auto_respawn_duration = minf(60.0, 15.0 + (death_count - 1) * 9.0)
	auto_respawn_timer = auto_respawn_duration

	modulate = Color(0.5, 0.5, 0.5, 0.7)
	AudioManager.play_sfx("death")
	GameManager.emit_signal("player_downed", player_slot_index)

	# Check wipe
	GameManager.check_all_players_downed()
	_refresh_enemy_targets()

func _process_downed_state(delta: float) -> void:
	if NetworkManager.is_client() or GameManager.run_finalized: return
	if not GameManager.has_living_players():
		GameManager.check_all_players_downed()
		return
	if downed_timer > 0.0:
		downed_timer = maxf(0, downed_timer - delta)

	auto_respawn_timer = maxf(0, auto_respawn_timer - delta)
	if auto_respawn_timer <= 0.0:
		revive_player()
		return

	# If downed_timer has elapsed, check if a teammate is in revive zone
	if downed_timer <= 0.0:
		var players := get_tree().get_nodes_in_group("players")
		for p in players:
			if p != self and is_instance_valid(p) and not p.is_downed:
				if global_position.distance_to(p.global_position) <= 80.0:
					revive_player()
					return

func revive_player() -> void:
	if NetworkManager.is_client() or not is_downed or GameManager.run_finalized or not GameManager.has_living_players(): return
	status_effects.clear_all()
	is_downed = false
	collision_layer = living_collision_layer
	collision_mask = living_collision_mask
	velocity = Vector2.ZERO
	downed_timer = 0
	auto_respawn_timer = 0
	var max_hp: float = float(current_stats.get("max_health", 500.0))
	current_health = max_hp * 0.5 # 50% HP
	current_shield = 0.0
	shield_layers.clear()
	is_invulnerable_active = true
	invulnerable_timer = 4.0 # 4s invulnerability
	modulate = Color.WHITE

	AudioManager.play_sfx("revive")
	GameManager.emit_signal("player_revived", player_slot_index)
	emit_signal("player_revived_signal")
	emit_signal("health_changed", current_health, max_hp, current_shield)
	_refresh_enemy_targets()

func _refresh_enemy_targets() -> void:
	# Rebuild immediately: an old flowfield must not keep attracting a horde to a corpse.
	var map = GameManager.current_map
	if is_instance_valid(map) and is_instance_valid(map.spawner):
		map.spawner._update_horde_systems()

func _hit_flash() -> void:
	if is_instance_valid(_flash): _flash.kill()
	var tween = create_tween()
	_flash = tween
	sprite.modulate = Color(2.0, 0.3, 0.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _process_pickup_magnet(delta: float) -> void:
	magnet_clock += delta
	if magnet_clock < 0.1: return
	magnet_clock = 0
	var radius: float = float(current_stats.get("pickup_radius", 100.0))
	var items := get_tree().get_nodes_in_group("pickups")
	for item in items:
		if not is_instance_valid(item): continue
		var vacuum_active: bool = GameManager.game_time < float(get_meta("vacuum_until",-1.0)) and item.item_type in [DropItem.ItemType.EXP_ORB,DropItem.ItemType.GOLD]
		if vacuum_active or item.global_position.distance_to(global_position) <= radius:
			if item.has_method("start_attraction"):
				item.start_attraction(self,"Magnet" if vacuum_active else "Aufnahme")

func _update_temporary_buffs(delta: float) -> void:
	var expired: Array[String] = []
	for b_name in temp_buffs.keys():
		temp_buffs[b_name]["duration"] -= delta
		if temp_buffs[b_name]["duration"] <= 0.0:
			expired.append(b_name)
	if not expired.is_empty():
		for k in expired:
			temp_buffs.erase(k)
		recalculate_stats()

func apply_temporary_buff(buff_name: String, duration: float, stats_bonus: Dictionary) -> void:
	if buff_name not in ["dynamic","celebration","xp_fanatic","armor_up","tissue"]: duration *= get_stat("duration_multiplier",1)
	temp_buffs[buff_name] = {
		"duration": duration,
		"stats": stats_bonus
	}
	recalculate_stats()

func _update_visuals() -> void:
	actor_scale = 1.0
	if is_instance_valid(GameManager.current_map) and GameManager.current_map.has_method("get_actor_scale"):
		actor_scale = GameManager.current_map.get_actor_scale()
	if augments.has("augment_bite_sized"): actor_scale*=0.7
	if augments.has("augment_larger_than_life"): actor_scale*=1.3
	if sprite:
		sprite.texture = AssetRegistry.get_character_texture(character_id)
		sprite.scale = Vector2.ONE*actor_scale
		visual_animator.setup(sprite,character_id,actor_scale)
	if color_ring:
		var col: Color = ProfileManager.DEFAULT_PLAYER_COLORS[player_slot_index % 4]
		color_ring.modulate = col
		color_ring.scale = Vector2.ONE*actor_scale
	if health_bar:
		health_bar.hide() # Draw the framed level/HP display together above the actor.
		health_bar.scale = Vector2.ONE*actor_scale
		health_bar.position = Vector2(-30,-42)*actor_scale
		if character_id=="jankz": health_bar.position=Vector2(-30,-56)*actor_scale
	# Fresh per-instance shapes prevent repeated setup and shared-resource scaling.
	for entry in [["CollisionShape2D",24.0],["HitboxArea/CollisionShape2D",26.0]]:
		var node: CollisionShape2D = get_node(entry[0])
		var shape := CircleShape2D.new()
		shape.radius = float(entry[1])*actor_scale
		node.shape = shape

# --- Character Ability Implementations ---
func _spawn_rockets(aim_dir: Vector2, count: int, dmg: float) -> void:
	var values: Dictionary = preload("res://scripts/core/swarm_balance.gd").data()["jinx_abilities"]["e"]
	var half_angle := deg_to_rad(float(values["angle_degrees"]))*0.5
	# Sweep clockwise through left / centre / right. Extra projectiles are spread
	# across these lanes and remain staggered rather than becoming a second volley.
	var shot_interval := float(values["shot_interval"])
	var lane_gap := float(values["lane_gap"])
	var delay := 0.0
	for lane in 3:
		var lane_count := count / 3 + (1 if lane < count % 3 else 0)
		for shot in lane_count:
			# Place the second rocket halfway towards the neighbouring lane, rather
			# than stacking both trajectories. Middle pair uses half a lane to right.
			var angle := (lane-1)*half_angle
			if shot%2==1: angle+=half_angle*0.5*(-1.0 if lane==2 else 1.0)
			var cast := {"remaining":delay,"ability":"e","direction":aim_dir.rotated(angle),"muzzle_offset":float(values["pair_offset"]) if shot%2==1 else 0.0,"raw_damage":dmg,"run_id":GameManager.run_id,"life_generation":life_generation}
			if delay <= 0:
				_release_jinx_ability(cast)
			else:
				pending_jinx_abilities.append(cast)
			delay += shot_interval
		delay += lane_gap

func _queue_jinx_ability(ability: String) -> void:
	var values: Dictionary = preload("res://scripts/core/swarm_balance.gd").data()["jinx_abilities"][ability]
	var cast := {"remaining":float(values["cast_time"]),"ability":ability,"direction":get_ability_aim_direction(),"level":GameManager.team_level,"run_id":GameManager.run_id,"life_generation":life_generation}
	if cast["remaining"]<=0:
		_release_jinx_ability(cast)
	else:
		pending_jinx_abilities.append(cast)

func _release_jinx_ability(cast: Dictionary) -> void:
	if is_downed or GameManager.run_finalized or cast["run_id"] != GameManager.run_id or cast["life_generation"] != life_generation:
		return
	if cast.has("raw_damage"):
		# The direction and base damage belong to the original key press; the
		# muzzle belongs to the current pose, so moving does not leave shots behind.
		var rocket := _spawn_jinx_rocket(cast["direction"],float(cast["raw_damage"]),"e")
		var direction: Vector2=cast["direction"]
		rocket.global_position+=Vector2(-direction.y,direction.x)*float(cast.get("muzzle_offset",0))
		rocket.initial_pos=rocket.global_position
		return
	var values: Dictionary = preload("res://scripts/core/swarm_balance.gd").data()["jinx_abilities"][cast["ability"]]
	var raw := float(values["damage_level_1"])+float(values["damage_per_level"])*(int(cast["level"])-1)
	if cast["ability"]=="e":
		_spawn_rockets(cast["direction"],int(values["count"])+int(get_stat("bonus_projectiles")),raw)
	else:
		_spawn_jinx_rocket(cast["direction"],raw,"r")

func _tick_jinx_abilities(delta: float) -> void:
	if is_downed or GameManager.run_finalized:
		pending_jinx_abilities.clear()
		return
	# Consume events chronologically, including newly scheduled shots. Reverse
	# array iteration would reverse the sweep on frames crossing several releases.
	var budget := maxf(0,delta)
	while not pending_jinx_abilities.is_empty():
		pending_jinx_abilities.sort_custom(func(a: Dictionary,b: Dictionary): return float(a["remaining"]) < float(b["remaining"]))
		var wait := maxf(0,float(pending_jinx_abilities[0]["remaining"]))
		if wait > budget + 0.000001: break
		for pending in pending_jinx_abilities:
			pending["remaining"] -= wait
		budget = maxf(0,budget-wait)
		var cast: Dictionary = pending_jinx_abilities.pop_front()
		_release_jinx_ability(cast)
	for pending in pending_jinx_abilities:
		pending["remaining"] -= budget

func _spawn_jinx_rocket(aim_dir: Vector2, raw: float, ability: String) -> Projectile:
	visual_animator.attack(aim_dir)
	var values: Dictionary = preload("res://scripts/core/swarm_balance.gd").data()["jinx_abilities"][ability]
	var projectile: Projectile = preload("res://scenes/combat/projectile_base.tscn").instantiate()
	get_parent().add_child(projectile)
	projectile.global_position=visual_animator.muzzle_position()
	var stats := current_stats.duplicate()
	stats["scale_projectile_duration"]=false
	stats["weapon_id"]="jinx_"+ability
	stats["can_crit"]=false
	projectile.setup(Projectile.MovementPattern.STRAIGHT,aim_dir,float(values["speed"])*0.2,raw,1,float(values["range"])/float(values["speed"])+0.05,self,stats,"rocket")
	projectile.rocket_ability=ability
	projectile.max_travel_distance=float(values["range"])*0.2
	projectile.aoe_radius=float(values["radius"])*0.2*get_stat("area_multiplier",1)
	projectile.configure_radius(float(values["width"])*0.2*0.5)
	projectile.missile_texture=load("res://assets/projectiles/jinx/"+("ultimate-rocket" if ability=="r" else "small-rocket")+".res")
	projectile.missile_display_width=float(values["display_width"])
	projectile.sprite.visible=false
	projectile.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return projectile

func _slow_nearby_enemies(radius: float, duration: float, slow_amount: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= radius:
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect("slow", duration, slow_amount, self)

func _trigger_radial_stun_explosion(radius: float, dmg: float) -> void:
	radius *= get_stat("area_multiplier",1)
	if character_id == "löwina":
		RuntimeEffect.spawn(get_parent(),self,global_position,{"visual":"solar","radius":radius,"damage":0,"duration":0.45,"scale_duration":false,"scale_area":false})
	AudioManager.play_sfx("explosion", 1.2)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= radius:
			DamageSystem.apply_damage(current_stats, enemy, dmg, true, self)
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect("stun", 1.5, 1.0, self)

func _spawn_tentacle_smash(aim_dir: Vector2, dmg: float) -> void:
	RuntimeEffect.spawn(get_parent(),self,global_position+aim_dir*80,{"mode":"cone","direction":aim_dir,"radius":220,"damage":dmg,"duration":4,"interval":1,"tentacle":true})

func _trigger_radial_damage(pos: Vector2, radius: float, dmg: float) -> void:
	radius *= get_stat("area_multiplier",1)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(pos) <= radius:
			DamageSystem.apply_damage(current_stats, enemy, dmg, true, self)

func _trigger_bladecaller() -> void:
	for feather in feathers:
		var point: Vector2 = feather["pos"]
		RuntimeEffect.spawn(get_parent(),self,point,{"mode":"beam","direction":(global_position-point).normalized(),"length":point.distance_to(global_position),"radius":25,"damage":160,"duration":0.2,"once":true,"status":"stun","status_duration":1.5,"depth":1})
	feathers.clear()

func _spawn_mega_death_rocket(aim_dir: Vector2) -> void:
	_spawn_jinx_rocket(aim_dir,500+50*(GameManager.team_level-1),"r")

func _screen_wide_stun_and_damage(dmg: float, stun_dur: float) -> void:
	RuntimeEffect.spawn(get_parent(),self,global_position,{"visual":"sound","radius":500,"damage":0,"duration":0.9,"scale_duration":false})
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			DamageSystem.apply_damage(current_stats, enemy, dmg, true, self)
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect("stun", stun_dur, 1.0, self)

func _spawn_solar_flare() -> void:
	var pos := get_ability_target_position(600.0)
	RuntimeEffect.spawn(get_parent(),self,pos,{"visual":"solar","radius":220,"damage":350,"warmup":0.5,"duration":0.7,"once":true,"status":"stun","status_duration":2})
	RuntimeEffect.spawn(get_parent(),self,pos,{"visual":"eclipse","radius":220,"damage":50,"warmup":0.7,"duration":3,"interval":0.5})

func _leap_and_spawn_tentacles() -> void:
	is_invulnerable_active = true
	invulnerable_timer = 0.7
	for i in range(4):
		var dir = Vector2.from_angle(TAU*i/4)
		RuntimeEffect.spawn(get_parent(),self,global_position+dir*80,{"mode":"cone","direction":dir,"radius":250,"damage":150,"warmup":0.7,"duration":8,"interval":1.0,"tentacle":true})

func _dive_bomb(aim_dir: Vector2) -> void:
	start_dash(aim_dir,1000,0.5)
	is_invulnerable_active = true
	invulnerable_timer = 0.5
	RuntimeEffect.spawn(get_parent(),self,global_position,{"radius":250,"damage":400,"warmup":0.5,"duration":0.7,"once":true,"follow":true})

func _spawn_wind_wall(aim_dir: Vector2) -> void:
	wall_time = 5*get_stat("duration_multiplier",1)
	wall_direction = aim_dir

func _spawn_wind_slash_cone(aim_dir: Vector2) -> void:
	apply_temporary_buff("exile",8,{"damage_pct":0.25})
	RuntimeEffect.spawn(get_parent(),self,global_position,{"mode":"cone","direction":aim_dir,"radius":550,"damage":300,"duration":0.3,"once":true})

func _spawn_spirit_domain() -> void:
	RuntimeEffect.spawn(get_parent(),self,global_position,{"mode":"portal","radius":350,"damage":60,"duration":8,"interval":1})

func _spawn_featherstorm() -> void:
	is_invulnerable_active = true
	invulnerable_timer = 1.5
	var dir = get_ability_aim_direction()
	for i in range(8):
		var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		proj.setup(0,dir.rotated((i-3.5)*0.22),750,200,5,2,self,current_stats,"feather")
		proj.leaves_feather = true

func get_armor() -> float:
	return get_stat("armor")

func is_invulnerable() -> bool:
	return is_downed or damage_grace>0 or is_invulnerable_active or (status_effects != null and status_effects.is_invulnerable()) or temp_buffs.has("bonus_kart") or temp_buffs.has("bonus_squad_shield") or (GameManager.practice_mode and get_meta("god_mode",false))

func take_hit(amount: float, _critical: bool = false, source: Node2D = null) -> bool:
	return DamageSystem.apply_damage({},self,amount,false,source)["killed"]

func apply_status_effect(kind: String, duration: float, power: float = 1.0, source: Node2D = null) -> void:
	status_effects.apply_effect(kind,duration,power,source)

func sync_health() -> void:
	queue_redraw()
	if health_bar:
		health_bar.max_value = get_stat("max_health",500)
		health_bar.value = current_health
	health_changed.emit(current_health,get_stat("max_health",500),current_shield)

func _draw() -> void:
	var passive_ratio := -1.0
	if character_id=="jankz": passive_ratio=jinx_passive_remaining()/8.0 if is_jinx_excited() else float(jinx_kills)/70.0
	preload("res://scripts/ui/overhead_health.gd").player(self,visual_animator.overhead_anchor(),GameManager.team_level,current_health,get_stat("max_health",1),current_shield,passive_ratio,is_jinx_excited(),is_downed)
	if character_id=="jankz" and visual_animator.recoil>0 and not is_downed:
		draw_set_transform(to_local(visual_animator.muzzle_position()),visual_animator.fire_direction.angle(),Vector2.ONE)
		preload("res://scripts/combat/animated_fx.gd").draw(self,"jinx_muzzle",visual_animator.fire_clock,Vector2.ZERO,Vector2.ONE*19*actor_scale,Color(1,1,1,0.9))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	var color = ProfileManager.DEFAULT_PLAYER_COLORS[player_slot_index]
	draw_arc(Vector2.ZERO,28*actor_scale,0,TAU,32,color,maxf(1.0,3*actor_scale))
	if is_downed:
		draw_arc(Vector2.ZERO,80,0,TAU,32,Color(0.3,1,0.4,0.6) if downed_timer <= 0 else Color(1,0.3,0.2,0.5),3)
	for feather in feathers:
		var local: Vector2 = feather["pos"]-global_position
		draw_line(local-Vector2(8,0),local+Vector2(8,0),Color(0.9,0.4,1),3)
	if wall_time > 0:
		var across = wall_direction.orthogonal()*180
		draw_line(wall_direction*80-across,wall_direction*80+across,Color(0.5,1,0.8,0.8),12)
	if current_shield > 0:
		preload("res://scripts/combat/arsenal_vfx.gd").draw(self,"radiant",GameManager.game_time,Vector2.ZERO,Vector2.ONE*70*actor_scale,Color(0.5,0.9,1,0.45))
		draw_arc(Vector2.ZERO,33*actor_scale,0,TAU,32,Color(0.2,0.8,1,0.5),maxf(1.0,2*actor_scale))

func begin_primary_shot(direction: Vector2) -> Vector2:
	if character_id!="jankz": return global_position
	visual_animator.attack(direction)
	queue_redraw()
	return visual_animator.muzzle_position()

func primary_aim_point(direction: Vector2) -> Vector2:
	if InputManager.is_auto_aim_enabled(player_slot_index):
		var target := _find_closest_enemy()
		if is_instance_valid(target): return target.global_position
	elif ProfileManager.player_slots[player_slot_index]["device_id"]==-1:
		return InputManager.get_mouse_world_position(get_viewport())
	elif ProfileManager.player_slots[player_slot_index]["device_id"] <= -100:
		return NetworkManager.remote_inputs.get(player_slot_index, {}).get("mouse", global_position + direction * 1000)
	return global_position+direction*1000

func _get_movement_scale() -> float:
	if is_instance_valid(GameManager.current_map) and GameManager.current_map.has_method("get_player_movement_scale"):
		return GameManager.current_map.get_player_movement_scale()
	return 1.0

func start_dash(dir: Vector2, speed: float, duration: float) -> void:
	dash_velocity = dir.normalized()*speed
	dash_timer = duration

func grant_shield(amount: float, duration: float) -> void:
	if amount <= 0: return
	shield_layers.append({"amount":amount,"time":duration*get_stat("duration_multiplier",1)})
	current_shield += amount
	sync_health()

func _on_ability() -> void:
	visual_animator.attack(get_ability_aim_direction())
	if character_id == "seraföhn": echo_charges = mini(3,echo_charges+1)
	if character_id == "rübenrambo": riven_charges = 3

func consume_echo() -> bool:
	if character_id != "seraföhn" or echo_charges <= 0: return false
	echo_charges -= 1
	return true

func passive_hud_text() -> String:
	if is_downed: return "PASSIVE INAKTIV · WIEDERBELEBUNG"
	match character_id:
		"seraföhn": return "ECHO · %d / 3 Ladungen" % echo_charges
		"löwina": return "SONNENBRAND · %d markierte Gegner" % solar_marks.size()
		"illaupsi": return "TENTAKELNÄHE · +8 LP/s bei eigenem Tentakel"
		"brioche": return "BLUTUNG · 2% maximales Leben je Heiltreffer"
		"yasüff": return "WIND · Bewegung lädt Schutz auf"
		"rübenrambo": return "KLINGENLADUNGEN · %d / 3" % riven_charges
		"auarora": return "GEISTER · %d getroffene Ziele" % aura_hits.size()
		"xayaya": return "FEDERN · %d / 60 am Boden" % feathers.size()
	return ""

func blocks_projectile(proj: Node2D) -> bool:
	if is_downed: return false
	if wall_time <= 0: return false
	var offset: Vector2 = proj.global_position-global_position
	return absf(offset.dot(wall_direction)-80)<35 and absf(offset.cross(wall_direction))<180

func place_feather(point: Vector2) -> void:
	if not feathers.is_empty() and point.distance_to(feathers[-1]["pos"])<5 and float(feathers[-1]["until"])-GameManager.game_time>7.8: return
	if feathers.size() >= 60: feathers.pop_front()
	feathers.append({"pos":point,"until":GameManager.game_time+8})

func modify_outgoing_damage(target: Node2D, amount: float, depth: int, attack_id: String = "") -> float:
	if depth > 0: return amount
	var distance = global_position.distance_to(target.global_position)
	if augments.has("augment_long_range"): amount*=1+0.3*clampf((distance-180)/140.0,0,1)
	if augments.has("augment_point_blank"): amount*=1+0.2*clampf((160-distance)/120.0,0,1)
	if augments.has("augment_elite_bomber") and target.get("is_elite"): amount*=1.3
	if character_id == "rübenrambo" and not attack_id.is_empty() and riven_charges > 0 and not boosted_attacks.has(attack_id):
		riven_charges -= 1
		boosted_attacks[attack_id] = true
	if boosted_attacks.has(attack_id): amount *= 1.4
	if boosted_attacks.size()>64: boosted_attacks.erase(boosted_attacks.keys()[0])
	return amount

func on_combat_hit(target: Node2D, result: Dictionary, depth: int) -> void:
	if is_downed: return
	# A direct bleed hit can satisfy both conditions; it is still one healing event.
	if character_id == "brioche" and (result.get("status","") == "bleed" or (depth == 0 and target.status_effects.has_effect("bleed"))):
		heal(get_stat("max_health")*0.02)
	if depth > 0: return
	if result["is_crit"]:
		QuestManager.notify_event("critical_hit",1,true)
		if augments.has("augment_critical_expansion"):
			crit_stacks.append(GameManager.game_time+5)
			effect_clock = 1
			if crit_stacks.size() > 100: crit_stacks.pop_front()
	var id = target.get_instance_id()
	if character_id == "löwina" and target.current_health > 0 and not target.is_queued_for_deletion():
		if solar_marks.has(id) and not target.is_queued_for_deletion():
			solar_marks.erase(id)
			RuntimeEffect.spawn(get_parent(),self,target.global_position,{"visual":"solar","radius":100,"damage":50,"duration":0.2,"once":true,"depth":1})
		else: solar_marks[id] = GameManager.game_time+3
	if character_id == "auarora" and target.current_health > 0 and not target.is_queued_for_deletion():
		aura_hits[id] = int(aura_hits.get(id,0))+1
		if aura_hits[id] >= 3:
			aura_hits.erase(id)
			DamageSystem.apply_damage({},target,target.max_health*0.05,false,self,"true",1)
			heal(get_stat("max_health")*0.02)
	if character_id == "xayaya": place_feather(target.global_position)
	if temp_buffs.has("bonus_pickpocketing") and randf()<0.2: GameManager.team_gold_earned += 1

func on_combat_kill(enemy: Node2D) -> void:
	if is_downed or GameManager.run_finalized or not is_instance_valid(enemy): return
	# Reentrant death/explosion callbacks may report the same victim twice.
	var credit_key := "kill_credit_"+str(get_instance_id())
	if enemy.has_meta(credit_key): return
	enemy.set_meta(credit_key,true)
	solar_marks.erase(enemy.get_instance_id())
	aura_hits.erase(enemy.get_instance_id())
	if character_id == "jankz":
		jinx_kills += 1
		if jinx_kills>=70 or enemy.is_elite:
			jinx_kills = 0
			jinx_excited_until = GameManager.game_time+8.0
			_update_jinx_passive()
	if augments.has("augment_death_and_taxes") and randf()<0.02:
		DropManager.spawn_gold(get_parent(),enemy.global_position,3)
		RuntimeEffect.spawn(get_parent(),self,enemy.global_position,{"visual":"impact","radius":40,"damage":100,"duration":0.2,"once":true,"depth":1})
	if augments.has("augment_pescatarian") and randf()<0.25: DropManager.spawn_health_pack(get_parent(),enemy.global_position,50)
	if augments.has("augment_elite_bomber") and enemy.is_elite:
		RuntimeEffect.spawn(get_parent(),self,enemy.global_position,{"visual":"mine","radius":120,"damage":300,"warmup":1.0,"duration":1.3,"once":true,"depth":1})
	for weapon in weapon_controller.equipped_weapons:
		if weapon.weapon_id=="weapon_radiant_field" and weapon.is_evolved and global_position.distance_to(enemy.global_position)<=weapon.effect_radius()*weapon.area_multiplier() and int(get_meta("proc_depth",0))<1:
			RuntimeEffect.spawn(get_parent(),self,enemy.global_position,{"visual":"impact","weapon_id":"weapon_radiant_field","radius":40,"damage":300,"duration":0.15,"once":true,"crit":false,"depth":1})

func is_jinx_excited() -> bool:
	return character_id=="jankz" and not is_downed and not GameManager.run_finalized and GameManager.game_time<jinx_excited_until

func jinx_passive_remaining() -> float:
	return maxf(0,jinx_excited_until-GameManager.game_time) if is_jinx_excited() else 0.0

func _jinx_speed_bonus() -> float:
	return 0.35*clampf(jinx_passive_remaining()/8.0,0,1)

func _reset_jinx_passive() -> void:
	jinx_kills=0
	jinx_excited_until=-1.0
	_jinx_last_speed_bonus=0
	_jinx_last_active=false
	# Remove legacy passive fields if a dynamic buff is still present.
	if temp_buffs.has("dynamic"):
		var legacy: Dictionary = temp_buffs["dynamic"]["stats"]
		if legacy.has("jinx_speed_pct"):
			legacy.erase("jinx_speed_pct")
			legacy["ability_haste"]=float(legacy.get("ability_haste",0))-150.0

func _update_jinx_passive() -> void:
	var active := is_jinx_excited()
	var bonus := _jinx_speed_bonus()
	# Smooth decay, exact expiry; avoid loading profile data every physics frame.
	if active!=_jinx_last_active or absf(bonus-_jinx_last_speed_bonus)>=0.003:
		_jinx_last_active=active
		_jinx_last_speed_bonus=bonus
		recalculate_stats()
		queue_redraw()

func _end_frenzy() -> void:
	frenzy_time = 0
	temp_buffs.erase("frenzy")
	recalculate_stats()
	_trigger_radial_stun_explosion(300,180)

func _runtime_update(delta: float) -> void:
	_update_jinx_passive()
	_tick_jinx_abilities(delta)
	damage_grace = maxf(0,damage_grace-delta)
	dash_timer = maxf(0,dash_timer-delta)
	wall_time = maxf(0,wall_time-delta)
	if frenzy_time > 0:
		frenzy_time -= delta
		if frenzy_time <= 0: _end_frenzy()
	# Shields consume FIFO; expire the remaining portion, never unrelated shields.
	for layer in shield_layers:
		if not layer.get("wind",false): layer["time"] -= delta
	for i in range(shield_layers.size()-1,-1,-1):
		if shield_layers[i]["time"] <= 0 or shield_layers[i]["amount"] <= 0:
			if shield_layers[i].get("iceblast",false) and has_meta("iceblast_shield_weapon"):
				get_meta("iceblast_shield_weapon")._ice_nova()
				remove_meta("iceblast_shield_weapon")
			current_shield = maxf(0,current_shield-shield_layers[i]["amount"])
			shield_layers.remove_at(i)
	feathers = feathers.filter(func(f): return f["until"]>GameManager.game_time)
	var old_stack_size = crit_stacks.size()
	crit_stacks = crit_stacks.filter(func(t): return t>GameManager.game_time)
	if old_stack_size != crit_stacks.size(): effect_clock = 1
	for id in solar_marks.keys():
		if solar_marks[id] <= GameManager.game_time: solar_marks.erase(id)
	if is_downed: return
	var moving = velocity.length_squared()>1
	var augment_dynamic := _update_augment_state(delta,moving)
	moving_time = moving_time+delta if moving else 0
	passive_clock += delta
	vacuum_clock += delta
	effect_clock += delta
	if character_id == "yasüff" and moving and current_shield < 150:
		var amount = minf(150-current_shield,delta*20)
		current_shield += amount
		if not shield_layers.is_empty() and shield_layers[-1].get("wind",false): shield_layers[-1]["amount"] += amount
		else: shield_layers.append({"amount":amount,"time":999.0,"wind":true})
	if effect_clock >= 1:
		effect_clock = 0
		# Another teammate may deliver the kill; do not retain its dead target forever.
		for target_id in aura_hits.keys():
			var marked = instance_from_id(target_id)
			if not is_instance_valid(marked) or marked.is_queued_for_deletion() or marked.current_health <= 0:
				aura_hits.erase(target_id)
		var dynamic: Dictionary = {}
		for key in augment_dynamic: dynamic[key]=float(dynamic.get(key,0))+float(augment_dynamic[key])
		dynamic["area_pct"] = crit_stacks.size()*0.01
		dynamic["area_pct"]+=float(augment_dynamic.get("area_pct",0))
		if dynamic != _last_dynamic:
			_last_dynamic = dynamic.duplicate()
			apply_temporary_buff("dynamic",2,dynamic)
		elif temp_buffs.has("dynamic"): temp_buffs["dynamic"]["duration"] = 2
		if character_id == "illaupsi":
			for effect in get_tree().get_nodes_in_group("runtime_effects"):
				if effect.source == self and effect.config.get("tentacle",false) and global_position.distance_to(effect.global_position)<300:
					heal(8)
					break
		if augments.has("augment_metabolic_overdrive"): heal(get_stat("max_health")*0.2)
		if temp_buffs.has("bonus_fired_up"): RuntimeEffect.spawn(get_parent(),self,global_position,{"radius":100,"damage":80,"duration":3,"interval":0.5,"depth":1})
		if temp_buffs.has("bonus_kart"): RuntimeEffect.spawn(get_parent(),self,global_position,{"radius":70,"damage":200,"duration":0.2,"once":true,"depth":1})
	if vacuum_clock >= 60:
		vacuum_clock = 0
		if augments.has("augment_pick_me_up"):
			for item in get_tree().get_nodes_in_group("pickups"):
				if item.item_type in [0,1]: item.start_attraction(self,"Magnet-Augment")
	if passive_clock >= 3:
		passive_clock = 0
		if temp_buffs.has("bonus_stopwaves"):
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy): enemy.apply_status_effect("freeze",1.5,1,self)

func register_augment(id: String) -> void:
	augment_state[id]={"level":GameManager.team_level,"time":GameManager.game_time,"cards":int(get_meta("cards",0)),"distance":augment_distance,"speed":get_stat("movement_speed",350)}
	effect_clock=1
	if id=="augment_pick_me_up": vacuum_clock=0

func on_incoming_damage() -> void:
	if augments.has("augment_armor_up"):
		var stacks := int(get_meta("armor_up_stacks",0)) if temp_buffs.has("armor_up") else 0
		stacks=mini(10,stacks+1)
		set_meta("armor_up_stacks",stacks)
		apply_temporary_buff("armor_up",8,{"armor":stacks*5})

func _update_augment_state(delta: float, moving: bool) -> Dictionary:
	if augment_last_position.is_finite(): augment_distance+=global_position.distance_to(augment_last_position)
	augment_last_position=global_position
	for id in augments:
		if not augment_state.has(id): register_augment(id)
	var dynamic: Dictionary = {}
	if augments.has("augment_bullet_mania"): dynamic["projectile_count"]=int((GameManager.team_level-int(augment_state["augment_bullet_mania"]["level"]))/6)
	if augments.has("augment_gathering_speed"): dynamic["speed_pct"]=(GameManager.team_level-int(augment_state["augment_gathering_speed"]["level"]))*0.03
	if augments.has("augment_card_collector"): dynamic["damage_pct"]=(int(get_meta("cards",0))-int(augment_state["augment_card_collector"]["cards"]))*0.05
	if augments.has("augment_cross_country"):
		var stacks := floorf((augment_distance-float(augment_state["augment_cross_country"]["distance"]))/4000.0)
		for key in ["damage_pct","max_health_pct","area_pct"]: dynamic[key]=(1+float(dynamic.get(key,0)))*(1+stacks*0.03)-1
	if augments.has("augment_ramming_runner"):
		var baseline := float(augment_state["augment_ramming_runner"]["speed"])
		dynamic["damage_pct"]=(1+float(dynamic.get("damage_pct",0)))*(1+(get_stat("movement_speed")-baseline)/maxf(1,float(base_stats.get("movement_speed",350)))*0.5)-1
	if augments.has("augment_circle_of_stats"):
		var phase := int((GameManager.game_time-float(augment_state["augment_circle_of_stats"]["time"]))/8)%5
		var keys := ["speed_pct","ability_haste","area_pct","projectile_count","health_regen"]
		var values := [0.3,40.0,0.6,3.0,40.0]
		dynamic[keys[phase]]=float(dynamic.get(keys[phase],0))+values[phase]
	if augments.has("augment_ebb_and_flow"):
		var phase := fposmod(GameManager.game_time-float(augment_state["augment_ebb_and_flow"]["time"]),32)/16
		dynamic["ability_haste"]=float(dynamic.get("ability_haste",0))-50+175*(phase if phase<=1 else 2-phase)
	if augments.has("augment_size_scrambler"):
		var phase := fposmod(GameManager.game_time-float(augment_state["augment_size_scrambler"]["time"]),16)/8
		dynamic["area_pct"]=float(dynamic.get("area_pct",0))-0.2+0.8*(phase if phase<=1 else 2-phase)
	if moving or not augments.has("augment_immobile_immolation"):
		immobile_stacks=0
		immobile_clock=0
	else:
		immobile_clock+=delta
		if immobile_clock>=0.5 and not is_invulnerable():
			immobile_clock-=0.5
			receive_damage(60+immobile_stacks,false,null)
			immobile_stacks+=1
			effect_clock=1
	if immobile_stacks>0: dynamic["ability_haste"]=float(dynamic.get("ability_haste",0))+immobile_stacks*20
	return dynamic

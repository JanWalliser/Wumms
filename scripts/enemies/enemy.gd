extends CharacterBody2D

# Enemy - High performance horde enemy agent supporting Flowfield navigation and separation

class_name Enemy

signal died(enemy_node: Enemy)

@export var enemy_id: String = "standard_grunt"

var max_health: float = 100.0
var current_health: float = 100.0
var death_started := false
var armor: float = 0.0
var move_speed: float = 200.0
var contact_damage: float = 15.0
var magic_damage: float = 15.0
var exp_drop: int = 3
var gold_drop: int = 2

var is_elite: bool = false
var is_boss: bool = false
var drops_access_card: bool = false

var separation_timer := 0.0
var cached_separation := Vector2.ZERO
var special_timer := 2.0
var special_windup := 0.0
const RANGED_ATTACK_RANGE := 500.0
const RANGED_ATTACK_SPEED := 360.0
const RANGED_ATTACK_WINDUP := 0.6
var pending_ranged_attack: Dictionary = {}
var _flash: Tween
var knockback_velocity: Vector2 = Vector2.ZERO
var attack_cooldown: float = 0.0
var actor_scale: float = 1.0
var visual_animator = preload("res://scripts/characters/actor_animator.gd").new()
var original_body_radius: float = 18.0
var original_hitbox_radius: float = 20.0

var status_effects: StatusEffectSystem = null
var flowfield_ref: Flowfield = null
var spatial_hash_ref: SpatialHash = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	status_effects = StatusEffectSystem.new(self)
	original_body_radius = collision_shape.shape.radius
	original_hitbox_radius = $HitboxArea/CollisionShape2D.shape.radius
	separation_timer = randf()*0.1
	_setup_from_registry()

func setup(e_id: String, flow: Flowfield, s_hash: SpatialHash) -> void:
	enemy_id = e_id
	flowfield_ref = flow
	spatial_hash_ref = s_hash
	_setup_from_registry()

func _setup_from_registry() -> void:
	actor_scale = 1.0
	if is_instance_valid(GameManager.current_map) and GameManager.current_map.has_method("get_actor_scale"):
		actor_scale = GameManager.current_map.get_actor_scale()
	var data := EnemyRegistry.get_enemy_data(enemy_id)
	var time_scaling := Vector2.ONE if bool(data.get("is_boss",false)) else GameManager.get_enemy_time_multipliers()
	var diff_mults := GameManager.get_difficulty_multipliers()
	var hp_mult := float(diff_mults.get("enemy_hp", 1.0)) * GameManager.get_player_count_hp_multiplier(enemy_id)
	var dmg_mult := float(diff_mults.get("phys_dmg", 1.0))

	max_health = float(data.get("max_health", 100.0)) * hp_mult * time_scaling.x
	current_health = max_health
	armor = float(data.get("armor", 0.0))
	move_speed = float(data.get("speed", 200.0))
	if is_instance_valid(GameManager.current_map) and GameManager.current_map.has_method("get_player_movement_scale"):
		move_speed *= GameManager.current_map.get_player_movement_scale()
	contact_damage = float(data.get("damage", 15.0)) * dmg_mult * time_scaling.y
	magic_damage = float(data.get("damage",15.0)) * float(diff_mults.get("magic_dmg",1.0)) * time_scaling.y
	exp_drop = int(data.get("exp_drop", 3))
	gold_drop = int(data.get("gold_drop", 2))
	is_elite = bool(data.get("is_elite", false))
	is_boss = bool(data.get("is_boss", false))
	drops_access_card = bool(data.get("drops_access_card", false))
	if enemy_id=="mini_boss" or is_elite or is_boss:
		add_to_group("minimap_threats")
	elif is_in_group("minimap_threats"):
		remove_from_group("minimap_threats")

	if sprite:
		sprite.texture = AssetRegistry.get_enemy_texture(enemy_id)
		sprite.scale = Vector2.ONE*actor_scale
		visual_animator.setup(sprite,enemy_id,actor_scale)
		if is_elite:
			sprite.modulate = Color(1.3, 1.2, 0.6) # Golden shine
		elif is_boss:
			sprite.modulate = Color(1.4, 0.8, 0.8)
	if collision_shape:
		var body := CircleShape2D.new()
		body.radius = original_body_radius*actor_scale
		collision_shape.shape = body
		var hitbox := CircleShape2D.new()
		hitbox.radius = original_hitbox_radius*actor_scale
		$HitboxArea/CollisionShape2D.shape = hitbox

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		velocity = Vector2.ZERO
		return
	if status_effects:
		status_effects.update(delta)
	if current_health <= 0 or is_queued_for_deletion(): return
	if has_meta("despawn_at") and GameManager.game_time>=float(get_meta("despawn_at")):
		queue_free() # Formation timeout is not a kill and cannot award XP/cards.
		return

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Decay knockback
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)

	_process_special(delta)
	var perf_move = Time.get_ticks_usec() if GameManager.profile_enabled else 0
	# Movement calculation
	var effective_speed := move_speed
	if is_boss and get("is_telegraphing"): effective_speed = 0
	if status_effects:
		effective_speed *= status_effects.get_speed_multiplier()

	var move_dir := Vector2.ZERO
	if flowfield_ref:
		move_dir = flowfield_ref.get_flow_direction(global_position)

	# Fallback to direct player tracking if flow vector is zero (e.g. inside player cell)
	if move_dir.is_zero_approx():
		var target := _find_closest_player()
		if is_instance_valid(target):
			move_dir = (target.global_position - global_position).normalized()

	# Add local separation from neighbors
	var sep := Vector2.ZERO
	if spatial_hash_ref:
		separation_timer -= delta
		if separation_timer <= 0:
			separation_timer = 0.1
			cached_separation = spatial_hash_ref.get_separation_vector(self,(35.0 if not is_boss else 80.0)*actor_scale)
		sep = cached_separation

	if special_windup > 0: effective_speed = 0
	var combined_dir := (move_dir + sep * 0.85).normalized()
	var target_vel := combined_dir * effective_speed
	velocity = target_vel + knockback_velocity

	move_and_slide()
	visual_animator.update(delta,velocity.length_squared()>1,move_dir,is_downed_check())
	if is_in_group("minimap_threats"): queue_redraw()
	if GameManager.profile_enabled: GameManager.profile_elapsed("enemy_movement",perf_move)

	# Check contact with players and corner deflection
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and collider.is_in_group("players"):
			if attack_cooldown <= 0.0 and not is_downed_check():
				if collider.has_method("take_hit"):
					DamageSystem.apply_damage({}, collider, contact_damage, false, self)
					attack_cooldown = 0.65
					visual_animator.attack()
		elif collider and (collider is StaticBody2D or collider.get_collision_layer_value(5)):
			# Deflect along wall normal to prevent sticking on obstacle corners
			var normal := col.get_normal()
			if normal.dot(combined_dir) < -0.1:
				var tangent := Vector2(-normal.y, normal.x)
				if tangent.dot(combined_dir) < 0:
					tangent = -tangent
				velocity = (velocity.slide(normal) + tangent * effective_speed * 0.4).normalized() * effective_speed

func is_downed_check() -> bool:
	return status_effects and status_effects.is_stunned_or_frozen()

func receive_damage(amount: float, is_crit: bool, attacker: Node2D = null) -> bool:
	if is_queued_for_deletion() or current_health <= 0.0:
		return false

	current_health -= amount
	queue_redraw()
	_hit_flash()


	if current_health <= 0.0:
		_die(attacker)
		return true
	return false

func apply_knockback(force: Vector2) -> void:
	if not is_boss:
		knockback_velocity += force

func _draw() -> void:
	if current_health>0 and not death_started and (enemy_id=="mini_boss" or is_elite or is_boss):
		preload("res://scripts/ui/overhead_health.gd").boss(self,visual_animator.overhead_anchor(),current_health,max_health)

func apply_status_effect(effect_name: String, duration: float, power: float = 1.0, source: Node2D = null) -> void:
	if status_effects:
		status_effects.apply_effect(effect_name, duration, power, source)

func get_armor() -> float:
	return armor + (status_effects.effect_power("armor_up") if status_effects else 0.0)

func is_invulnerable() -> bool:
	return status_effects and status_effects.is_invulnerable()

func _hit_flash() -> void:
	if not sprite or not is_instance_valid(sprite):
		return
	if is_instance_valid(_flash): _flash.kill()
	var tween = create_tween()
	_flash = tween
	sprite.modulate = Color(2.5, 2.5, 2.5)
	var reset_col := Color.WHITE
	if is_elite:
		reset_col = Color(1.3, 1.2, 0.6)
	tween.tween_property(sprite, "modulate", reset_col, 0.12)

func _die(killer: Node2D = null) -> void:
	if death_started or is_queued_for_deletion():
		return
	death_started=true
	GameManager.total_run_kills += 1
	QuestManager.notify_event("enemy_killed", 1.0, true)
	QuestManager.notify_event("total_kills", 1.0, true)
	if is_elite and not is_boss: QuestManager.notify_event("elite_kills",1,true)

	if is_instance_valid(killer) and killer.has_method("on_combat_kill") and int(killer.get_meta("proc_depth",0)) == 0: killer.on_combat_kill(self)
	GameManager.combat_event.emit("kill", {"target":self,"source":killer})
	if enemy_id == "mini_boss" and GameManager.selected_difficulty != "story": QuestManager.notify_event("miniboss_hard_kills",1,true)
	if enemy_id == "mini_boss" and GameManager.selected_map_id=="map_warehouse": QuestManager.notify_event("warehouse_miniboss_kills",1,true)
	var parent := get_parent()
	if parent and not is_boss:
		if get_meta("warehouse_divider",false):
			var spawner = parent.get_node_or_null("EnemySpawner")
			if spawner: spawner.spawn_divider_children.call_deferred(global_position,GameManager.run_id)
		# Drops
		var reward_xp := exp_drop
		if has_meta("warehouse_normal_xp_scale"):
			reward_xp=GameManager.normalized_warehouse_xp(exp_drop,float(get_meta("warehouse_normal_xp_scale")))
		DropManager.spawn_exp_orb(parent, global_position, reward_xp)
		if gold_drop > 0 and randf() < 0.4:
			DropManager.spawn_gold(parent, global_position, gold_drop)

		# Elite & Miniboss drops
		if drops_access_card:
			DropManager.spawn_access_card(parent, global_position)
			DropManager.spawn_gold(parent, global_position, 50)
			AudioManager.play_sfx("card")

		# Rare consumable drops
		var drop_roll := randf()
		if drop_roll < 0.02:
			DropManager.spawn_health_pack(parent, global_position)
		elif drop_roll < 0.028:
			DropManager.spawn_special_pickup(parent, global_position, DropItem.ItemType.VACUUM)
		elif drop_roll < 0.034:
			DropManager.spawn_special_pickup(parent, global_position, DropItem.ItemType.BOMB)

	if is_boss:
		var boss_name: String = EnemyRegistry.get_enemy_data(enemy_id).get("display_name", "Boss")
		GameManager.on_boss_killed(boss_name)

	emit_signal("died", self)
	queue_free()

func take_hit(amount: float, _critical: bool = false, attacker: Node2D = null) -> bool:
	return DamageSystem.apply_damage({},self,amount,false,attacker)["killed"]

func _process_special(delta: float) -> void:
	if is_boss: return
	if status_effects.is_stunned_or_frozen():
		pending_ranged_attack.clear()
		special_windup=0
		return
	_tick_ranged_attack(delta)
	var was_winding_up := special_windup>0
	special_windup = maxf(0,special_windup-delta)
	if was_winding_up and special_windup<=0: visual_animator.attack()
	special_timer -= delta
	if special_timer > 0: return
	if get_meta("warehouse_spawner",false):
		special_timer=5
		var spawner = get_parent().get_node_or_null("EnemySpawner")
		if spawner and spawner.active_enemies.size()<spawner.max_concurrent_enemies:
			var child = spawner._spawn_single_enemy("fast_runner",spawner.safe_position(global_position+Vector2(30,0)))
			if is_instance_valid(child): child.exp_drop=1
		return
	var target = null
	var distance = 800.0
	for p in GameManager.active_player_nodes:
		if is_instance_valid(p) and not p.is_downed and global_position.distance_to(p.global_position) < distance:
			distance = global_position.distance_to(p.global_position)
			target = p
	if target == null: return
	var direction = (target.global_position-global_position).normalized()
	if get_meta("miniboss_kind","")=="artillery":
		special_timer=3.8
		special_windup=1.4
		for i in 3:
			RuntimeEffect.spawn(get_parent(),self,target.global_position+Vector2((i-1)*85,0),{"visual":"enemy_slam","radius":46,"damage":magic_damage,"warmup":1.4,"duration":1.75,"once":true,"crit":false,"shared_tick":true,"weapon_id":"miniboss_artillery","interval":0.5})
		return
	if get_meta("miniboss_kind","")=="dasher":
		special_timer=4
		special_windup=0.7
		RuntimeEffect.spawn(get_parent(),self,global_position,{"mode":"beam","direction":direction,"length":350,"radius":24,"damage":0,"duration":0.7})
		get_tree().create_timer(0.7,false).timeout.connect(func():
			if current_health<=0 or GameManager.run_finalized: return
			knockback_velocity=direction*700)
		return
	match enemy_id:
		"ranged_spitter":
			if distance>RANGED_ATTACK_RANGE: return
			special_timer = 2.5
			_begin_ranged_attack(direction)
		"kamikaze_exploder":
			if distance > 160: return
			special_timer = 999
			special_windup = 1
			RuntimeEffect.spawn(get_parent(),self,global_position,{"radius":180,"damage":contact_damage,"warmup":0.8,"duration":0.95,"once":true,"crit":false})
			get_tree().create_timer(1.0,false).timeout.connect(func():
				if current_health > 0 and not GameManager.run_finalized:
					current_health = 0
					_die())
		"aoe_bruiser", "mini_boss":
			if distance > 300: return
			var miniboss := enemy_id=="mini_boss"
			special_timer = 4.0 if miniboss else 3.5
			special_windup = 1.4 if miniboss else 1.2
			RuntimeEffect.spawn(get_parent(),self,target.global_position,{"visual":"enemy_slam","radius":80 if miniboss else 90,"damage":contact_damage*1.4,"warmup":special_windup,"duration":special_windup+0.35,"once":true,"crit":false})
		"support_buffer":
			special_timer = 3
			RuntimeEffect.spawn(get_parent(),self,global_position,{"radius":220,"damage":0,"duration":0.5})
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.global_position.distance_to(global_position)<220:
					e.current_health = minf(e.max_health,e.current_health+e.max_health*0.08)
					e.apply_status_effect("haste",3,1.3,self)
					e.apply_status_effect("armor_up",3,10,self)

func _begin_ranged_attack(direction: Vector2) -> void:
	special_windup=RANGED_ATTACK_WINDUP
	# The warning and shot share an immutable origin, direction and endpoint.
	pending_ranged_attack={"origin":global_position,"direction":direction.normalized(),"remaining":RANGED_ATTACK_WINDUP,"run":GameManager.run_id}
	RuntimeEffect.spawn(get_parent(),self,global_position,{"mode":"beam","direction":direction.normalized(),"length":RANGED_ATTACK_RANGE,"radius":12,"damage":0,"duration":RANGED_ATTACK_WINDUP})

func _tick_ranged_attack(delta: float) -> void:
	if pending_ranged_attack.is_empty(): return
	if current_health<=0 or GameManager.run_finalized or pending_ranged_attack["run"]!=GameManager.run_id:
		pending_ranged_attack.clear()
		return
	pending_ranged_attack["remaining"]-=delta
	if float(pending_ranged_attack["remaining"])>0.00001: return
	var attack := pending_ranged_attack.duplicate()
	visual_animator.attack()
	pending_ranged_attack.clear() # Commit before spawning, so an attack cannot fire twice.
	var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
	get_parent().add_child(proj)
	proj.global_position=attack["origin"]
	proj.max_travel_distance=RANGED_ATTACK_RANGE
	proj.setup(0,attack["direction"],RANGED_ATTACK_SPEED,magic_damage,1,RANGED_ATTACK_RANGE/RANGED_ATTACK_SPEED+0.25,self,{"damage_kind":"magic"},"laser")

func _find_closest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	var closest: Node2D = null
	var min_d := 99999.0
	for p in players:
		if is_instance_valid(p) and not p.is_downed:
			var d := global_position.distance_to(p.global_position)
			if d < min_d:
				min_d = d
				closest = p
	return closest

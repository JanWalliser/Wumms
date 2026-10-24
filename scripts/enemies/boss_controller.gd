extends Enemy

# BossController - Multi-phase boss AI with telegraphed attacks and unique boss mechanics

class_name BossController

signal boss_health_updated(current_hp: float, max_hp: float)
signal boss_phase_changed(phase: int)

var boss_phase: int = 1
var attack_timer: float = 0.0
var phase_2_triggered: bool = false
var is_telegraphing: bool = false
var telegraph_direction: Vector2 = Vector2.DOWN
var attack_serial := 0
var pending_attack_effect: Node2D

func _cancel_pending_attack() -> void:
	if not is_telegraphing and not is_instance_valid(pending_attack_effect): return
	attack_serial+=1
	is_telegraphing=false
	modulate.a=1.0
	if is_instance_valid(pending_attack_effect):
		pending_attack_effect.done=true
		pending_attack_effect.queue_free()
	pending_attack_effect=null

func _ready() -> void:
	super._ready()
	is_boss = true
	GameManager.current_boss_node = self

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.GAMEPLAY or current_health <= 0: return
	super._physics_process(delta)
	if current_health <= 0 or is_queued_for_deletion(): return
	boss_health_updated.emit(current_health,max_health)
	if enemy_id in ["boss_aatrox","boss_belveth","boss_reksai","boss_briar"] and not phase_2_triggered and current_health <= max_health*0.5:
		phase_2_triggered = true
		boss_phase = 2
		boss_phase_changed.emit(2)
		_trigger_phase_transition()
	if status_effects.is_stunned_or_frozen():
		if enemy_id=="boss_reksai": _cancel_pending_attack()
		return
	attack_timer += delta
	var interval = 2.0 if (GameManager.boss_enraged_state or boss_phase == 2) else 3.8
	if enemy_id=="boss_reksai": interval=preload("res://scripts/game/warehouse_balance.gd").reksai_attack(GameManager.selected_difficulty,GameManager.boss_enraged_state or boss_phase==2)["recovery"]
	if attack_timer >= interval:
		attack_timer = 0
		_execute_boss_attack()

func _execute_boss_attack() -> void:
	if is_telegraphing: return
	if enemy_id=="boss_reksai": _cancel_pending_attack()
	var target = _find_closest_player()
	if not target: return
	var direction = (target.global_position-global_position).normalized()
	telegraph_direction = direction
	is_telegraphing = true
	var warmup = 0.65 if (GameManager.boss_enraged_state or boss_phase == 2) else 1.1
	var reksai_spec := preload("res://scripts/game/warehouse_balance.gd").reksai_attack(GameManager.selected_difficulty,GameManager.boss_enraged_state or boss_phase==2)
	if enemy_id=="boss_reksai": warmup=float(reksai_spec["warmup"])
	attack_serial+=1
	var serial := attack_serial
	var token := GameManager.run_id
	var point = target.global_position
	match enemy_id:
		"boss_reksai":
			# Burrow subterranean travel: invulnerable, underground opacity, ground tremor
			status_effects.apply_effect("invulnerable", warmup)
			modulate.a = 0.25
			AudioManager.play_sfx("explosion", 0.75)
			pending_attack_effect=RuntimeEffect.spawn(get_parent(), self, point, {"visual":"enemy_slam","radius":reksai_spec["radius"],"damage":contact_damage*1.6,"warmup":warmup,"duration":warmup+0.3,"once":true,"crit":false,"requires_commit":true,"committed":false})
		"boss_briar":
			RuntimeEffect.spawn(get_parent(),self,global_position,{"mode":"cone","direction":direction,"radius":450,"damage":contact_damage*1.2,"warmup":warmup,"duration":warmup+0.25,"once":true,"crit":false})
		"boss_belveth":
			RuntimeEffect.spawn(get_parent(),self,global_position,{"radius":80,"damage":0,"warmup":warmup,"duration":warmup+0.1})
		"boss_aatrox":
			for stage in range(3):
				RuntimeEffect.spawn(get_parent(),self,global_position+direction*(140+stage*100),{"mode":"cone" if stage<2 else "area","direction":direction,"radius":160+stage*30,"damage":contact_damage*1.3,"warmup":warmup+stage*0.45,"duration":warmup+stage*0.45+0.2,"once":true,"crit":false})
	get_tree().create_timer(warmup,false).timeout.connect(func():
		if serial!=attack_serial or token!=GameManager.run_id: return
		if current_health<=0 or GameManager.run_finalized or status_effects.is_stunned_or_frozen():
			_cancel_pending_attack()
			return
		if is_instance_valid(pending_attack_effect): pending_attack_effect.config["committed"]=true
		is_telegraphing = false
		modulate.a = 1.0
		visual_animator.attack()
		if enemy_id == "boss_reksai":
			var landing: Vector2 = point.clamp(Vector2(-1750, -1750), Vector2(1750, 1750))
			var map = GameManager.current_map
			if is_instance_valid(map) and map.has_method("get_safe_position"):
				landing = map.get_safe_position(point,maxf(55.0,collision_shape.shape.radius+7.0))
			global_position = landing
			AudioManager.play_sfx("explosion", 1.3)
			# Radial earthquake shockwaves upon unburrowing
			var wave_count := 18 if boss_phase == 2 else 12
			for i in range(wave_count):
				var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
				get_parent().add_child(proj)
				proj.global_position = global_position
				proj.setup(0, Vector2.from_angle(TAU * i / wave_count), 290, magic_damage * 0.65, 1, 3.5, self, {"damage_kind": "magic"}, "laser")
			if boss_phase == 2 and randf() < 0.65:
				_spawn_reksai_tunnels(point)
		if enemy_id == "boss_briar": knockback_velocity = direction*700
		if enemy_id in ["boss_belveth","boss_briar"] or (enemy_id == "boss_aatrox" and boss_phase == 2):
			var count = 20 if boss_phase == 2 else 12
			for i in range(count):
				var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
				get_parent().add_child(proj)
				proj.global_position = global_position
				proj.setup(0,Vector2.from_angle(TAU*i/count),300,magic_damage*0.7,1,4,self,{"damage_kind":"magic"},"laser"))

func _spawn_reksai_tunnels(center: Vector2) -> void:
	if not GameManager.current_map: return
	var spawner = GameManager.current_map.get_node_or_null("EnemySpawner")
	if not spawner: return
	for i in range(3):
		var offset := Vector2.from_angle(TAU * i / 3.0) * randf_range(110.0, 180.0)
		var spawn_pos := (center + offset).clamp(Vector2(-1700, -1700), Vector2(1700, 1700))
		spawner.spawn_enemy("fast_runner" if randf() < 0.5 else "standard_grunt", spawn_pos)

func _trigger_phase_transition() -> void:
	if enemy_id=="boss_reksai": _cancel_pending_attack()
	AudioManager.play_sfx("evolve", 0.9)
	status_effects.apply_effect("invulnerable", 2.0)
	status_effects.apply_effect("freeze", 2.0)
	var body_shape = collision_shape.shape.duplicate()
	body_shape.radius *= 1.3
	var map = GameManager.current_map
	if is_instance_valid(map) and map.has_method("get_safe_position"):
		global_position = map.get_safe_position(global_position,body_shape.radius+7.0)
	collision_shape.set_deferred("shape", body_shape)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", visual_animator.rest_scale*1.35, 0.5)
	if enemy_id == "boss_reksai":
		sprite.modulate = Color(1.6, 0.6, 0.6) # Enraged crimson aura

	if enemy_id == "boss_aatrox":
		# Trigger flood rise event on Map 4
		var current_map = GameManager.current_map
		if current_map and current_map.has_method("start_rising_flood"):
			current_map.start_rising_flood()

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

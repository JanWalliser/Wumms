extends Area2D

# Projectile - High-performance modular projectile supporting straight, homing, orbiting, boomerang, mine, and ground hazard behaviors.

class_name Projectile

enum MovementPattern {
	STRAIGHT,
	HOMING,
	ORBIT,
	BOOMERANG,
	MINE,
	GROUND_POOL,
	BEAM
}

var split_count := 0
var expired := false
var target_group := "enemies"
var shot_id: String = ""
var ricochet := false
var leaves_feather := false
var visual_style := ""
var rehit_interval := 0.25
var damage_lockouts: Dictionary = {}
var damage_lockout_time := 0.0
var knockback_strength := 30.0
var ground_target := Vector2.INF
var ground_travel_time := 0.0
var damage_falloff := 1.0
var crit_pierce := false
var bouncing_mine := false
var bounce_range := 120.0
var terrain_bounce := false
var bounce_damage_multiplier := 1.0
var aoe_damage := -1.0
var aoe_hits_primary := false
var boomerang_range := 0.0
var boomerang_split := false
var return_speed := 12.0
var shared_hit_ids: Dictionary = {}
var curve_amplitude := 0.0
var missile_texture: Texture2D
var missile_display_width := 40.0
var rocket_ability := ""
var max_travel_distance := 0.0
var _tick := 0.0
var _homing_target: Node2D
var _homing_timer := 0.0
var run_token := ""
var movement_pattern: MovementPattern = MovementPattern.STRAIGHT
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 20.0
var pierce_count: int = 1
var lifetime: float = 3.0
var elapsed_time: float = 0.0

var source_owner: Node2D = null
var attacker_stats: Dictionary = {}
var hit_radius: float = 16.0
var aoe_radius: float = 0.0
var explodes_on_death: bool = false
var explosion_damage: float = 0.0

# Orbit / Boomerang parameters
var orbit_center_node: Node2D = null
var orbit_radius: float = 120.0
var orbit_angle: float = 0.0
var orbit_speed: float = 3.5 # Radians per second
var boomerang_state: int = 0 # 0 = forward, 1 = returning
var initial_pos: Vector2 = Vector2.ZERO

# Status effects to apply on hit
var status_effects: Dictionary = {} # effect_name -> { "duration": float, "power": float }

# Hit tracking to avoid hitting the same target multiple times unless allowed
var hit_entities: Dictionary = {} # target -> hit_timestamp

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("projectiles")
	collision_layer = 4 # Projectile layer
	collision_mask = 2  # Enemy layer
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(
	pattern: MovementPattern,
	dir: Vector2,
	spd: float,
	dmg: float,
	pierce: int,
	dur: float,
	owner_node: Node2D,
	stats: Dictionary,
	tex_id: String = "bullet"
) -> void:
	movement_pattern = pattern
	direction = dir.normalized()
	speed = spd
	damage = dmg
	pierce_count = pierce
	lifetime = dur*(float(stats.get("duration_multiplier",1)) if stats.get("scale_projectile_duration",true) else 1.0)
	elapsed_time = 0.0
	source_owner = owner_node
	run_token = GameManager.run_id
	target_group = "players" if is_instance_valid(owner_node) and owner_node.is_in_group("enemies") else "enemies"
	collision_mask = 1 if target_group == "players" else 2
	attacker_stats = stats
	initial_pos = global_position
	boomerang_state = 0
	hit_entities.clear()

	if sprite:
		sprite.texture = AssetRegistry.get_projectile_texture(tex_id)
		sprite.scale = Vector2(0.8, 0.8)
		visual_style = str(stats.get("weapon_id",""))
		if visual_style.is_empty() and target_group=="players": visual_style="hostile"
		sprite.visible = visual_style.is_empty()

	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if expired or GameManager.run_id != run_token:
		_expire()
		return
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		return
	if movement_pattern==MovementPattern.ORBIT and (not is_instance_valid(source_owner) or source_owner.is_downed):
		_expire()
		return
	if max_travel_distance>0 and initial_pos.distance_to(global_position)>=max_travel_distance:
		_expire()
		return
	elapsed_time += delta
	if elapsed_time >= lifetime:
		_expire()
		return

	if ground_target.is_finite():
		if ground_travel_time>0:
			global_position=initial_pos.lerp(ground_target,clampf(elapsed_time/ground_travel_time,0,1))
			if elapsed_time>=ground_travel_time: _land_fire()
			queue_redraw()
			return
		if global_position.distance_to(ground_target)<=speed*delta:
			global_position=ground_target
			_land_fire()
			return
		global_position=global_position.move_toward(ground_target,speed*delta)
		queue_redraw()
		return
	match movement_pattern:
		MovementPattern.STRAIGHT:
			var step := direction*speed*delta
			if max_travel_distance>0: step=step.limit_length(maxf(0,max_travel_distance-initial_pos.distance_to(global_position)))
			if visual_style in ["crossbow","uwu","owo","meow"]:
				_sweep_bolt(step)
				if expired: return
			if not rocket_ability.is_empty():
				var contact := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,global_position+step,2))
				if not contact.is_empty():
					global_position=contact["position"]
					_explode_rocket()
					return
			if terrain_bounce:
				var query := PhysicsRayQueryParameters2D.create(global_position,global_position+step,16)
				var collision := get_world_2d().direct_space_state.intersect_ray(query)
				if not collision.is_empty():
					direction=direction.bounce(collision["normal"])
					rotation=direction.angle()
					damage*=bounce_damage_multiplier
					global_position=collision["position"]+direction*2
					hit_entities.clear()
				else: global_position+=step
			else:
				global_position += step
				if curve_amplitude!=0:
					var progress := clampf(elapsed_time/maxf(lifetime,0.01),0,1)
					global_position=initial_pos+direction*speed*elapsed_time+direction.orthogonal()*sin(progress*PI)*curve_amplitude

		MovementPattern.HOMING:
			_homing_timer -= delta
			if (not bouncing_mine and _homing_timer<=0) or not is_instance_valid(_homing_target):
				_homing_timer = 0.15
				_homing_target = _find_nearest_target()
			var target = _homing_target
			if bouncing_mine and not is_instance_valid(target):
				_expire()
				return
			if is_instance_valid(target):
				var target_dir = (target.global_position - global_position).normalized()
				direction = direction.slerp(target_dir, delta * 8.0).normalized()
				rotation = direction.angle()
			global_position += direction * speed * delta

		MovementPattern.ORBIT:
			if is_instance_valid(orbit_center_node):
				orbit_angle += orbit_speed * delta
				var offset := Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
				global_position = orbit_center_node.global_position + offset
				rotation = orbit_angle + PI * 0.5
			else:
				_expire()

		MovementPattern.BOOMERANG:
			if boomerang_state == 0:
				global_position += direction * speed * delta
				if boomerang_range>0: speed=maxf(80,speed-640*delta)
				if (boomerang_range>0 and initial_pos.distance_to(global_position)>=boomerang_range) or (boomerang_range<=0 and elapsed_time >= lifetime * 0.5):
					boomerang_state = 1 # A distinct return pass may hit each target once again.
					hit_entities.clear()
					if boomerang_split:
						_spawn_splits.call_deferred(weakref(get_parent()),weakref(source_owner),global_position,4,damage,attacker_stats.duplicate(),run_token)
			else:
				if is_instance_valid(source_owner):
					var return_dir := (source_owner.global_position - global_position).normalized()
					if boomerang_range>0:
						return_speed=minf(520,return_speed+380*delta)
						global_position+=return_dir*return_speed*delta
					else: global_position += return_dir * speed * 1.25 * delta
					if global_position.distance_to(source_owner.global_position) < 30.0:
						_expire()
				else:
					global_position -= direction * speed * delta

		MovementPattern.MINE, MovementPattern.GROUND_POOL:
			# Stationary on the ground
			pass

		MovementPattern.BEAM:
			# Attached to owner or directional beam
			if is_instance_valid(source_owner):
				global_position = source_owner.global_position
				rotation = direction.angle()
	if max_travel_distance>0 and initial_pos.distance_to(global_position)>=max_travel_distance-0.01:
		_expire()
		return

	if movement_pattern in [MovementPattern.GROUND_POOL,MovementPattern.ORBIT,MovementPattern.BEAM]:
		_tick -= delta
		if _tick <= 0:
			_tick = 0.25
			for body in get_overlapping_bodies(): _handle_target_hit(body)
	if target_group == "players":
		for player in GameManager.active_player_nodes:
			if is_instance_valid(player) and player.has_method("blocks_projectile") and player.blocks_projectile(self):
				_expire()
				return
	queue_redraw()

func _sweep_bolt(step: Vector2) -> void:
	var start := global_position
	var query := PhysicsRayQueryParameters2D.create(global_position,global_position+step,2)
	var ignored: Array[RID] = []
	for i in 32:
		query.exclude=ignored
		var contact := get_world_2d().direct_space_state.intersect_ray(query)
		if contact.is_empty():
			global_position=start
			return
		ignored.append(contact["rid"])
		global_position=contact["position"]
		_handle_target_hit(contact["collider"])
		if expired:
			global_position=contact["position"]
			return
	global_position=start

func _on_area_entered(area: Area2D) -> void:
	_handle_target_hit(area.get_parent())

func _on_body_entered(body: Node2D) -> void:
	_handle_target_hit(body)

func _handle_target_hit(target: Node2D) -> void:
	if ground_target.is_finite(): return
	if not is_instance_valid(source_owner): source_owner = null
	if expired or GameManager.run_finalized or not is_instance_valid(target) or target == source_owner or target.is_queued_for_deletion():
		return
	if not target.is_in_group(target_group) or not target.has_method("receive_damage"):
		return

	# Prevent hitting same target multiple times within 0.25s unless pool
	var target_id := target.get_instance_id()
	if damage_lockout_time>0:
		var stamp: float = float(damage_lockouts.get(target_id,-1000))
		if GameManager.game_time-stamp<damage_lockout_time-0.00001: return
		damage_lockouts[target_id]=GameManager.game_time
	if shared_hit_ids.has(target_id): return
	var now = elapsed_time * 1000.0
	if hit_entities.has(target_id):
		if movement_pattern not in [MovementPattern.GROUND_POOL, MovementPattern.ORBIT, MovementPattern.BEAM] or (now - hit_entities[target_id]) < rehit_interval*1000.0-1.0:
			return
	hit_entities[target_id] = now
	if curve_amplitude!=0 or visual_style=="crescent": shared_hit_ids[target_id]=true
	if not rocket_ability.is_empty():
		_explode_rocket()
		return

	# Reserve the hit budget before callbacks can cause another collision.
	var finite = movement_pattern not in [MovementPattern.ORBIT,MovementPattern.GROUND_POOL,MovementPattern.BEAM]
	if finite: pierce_count -= 1
	if finite and pierce_count <= 0: expired = true
	# Apply damage
	var result := DamageSystem.apply_damage(attacker_stats, target, damage,attacker_stats.get("can_crit",true), source_owner,attacker_stats.get("damage_kind","physical"))
	if crit_pierce and not result["is_crit"]: expired=true
	if damage_falloff<1: damage*=damage_falloff; damage_falloff=1.0
	if movement_pattern==MovementPattern.ORBIT and is_instance_valid(source_owner) and target.has_method("apply_knockback"):
		target.apply_knockback((target.global_position-source_owner.global_position).normalized()*knockback_strength)
	_spawn_impact()

	# Apply status effects
	if target.has_method("apply_status_effect"):
		for effect_name in status_effects.keys():
			var eff: Dictionary = status_effects[effect_name]
			target.apply_status_effect(effect_name, eff["duration"], eff["power"], source_owner)

	# Check AOE explosion
	if aoe_radius > 0.0:
		_trigger_aoe_damage(global_position, aoe_radius,aoe_damage if aoe_damage>=0 else damage,null if aoe_hits_primary else target)
	if bouncing_mine and not expired:
		_homing_target=_find_nearest_target()
		if is_instance_valid(_homing_target): direction=(_homing_target.global_position-global_position).normalized()
		else: expired=true

	if leaves_feather and is_instance_valid(source_owner) and source_owner.has_method("place_feather"): source_owner.place_feather(global_position)
	if ricochet and not expired:
		_homing_target = _find_nearest_target()
		if is_instance_valid(_homing_target): direction = ( _homing_target.global_position-global_position).normalized()
	if expired:
		if split_count > 0 and is_instance_valid(source_owner):
			_spawn_splits.call_deferred(weakref(get_parent()),weakref(source_owner),global_position,split_count,damage*0.4,attacker_stats.duplicate(),run_token)

		_finish_expire()

func _trigger_aoe_damage(pos: Vector2, radius: float, aoe_dmg: float, already_hit: Node2D = null) -> void:
	if not is_instance_valid(source_owner): source_owner = null
	AudioManager.play_sfx("explosion", 1.3)
	var tree := get_tree()
	if not tree:
		return
	var enemies := tree.get_nodes_in_group(target_group)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy!=already_hit and enemy.global_position.distance_to(pos) <= radius:
			DamageSystem.apply_damage(attacker_stats, enemy, aoe_dmg, false, source_owner)

func _expire() -> void:
	if expired: return
	if not rocket_ability.is_empty():
		_explode_rocket()
		return
	expired = true
	_finish_expire()

func _finish_expire() -> void:
	if GameManager.run_id == run_token and not GameManager.run_finalized and explodes_on_death and explosion_damage > 0.0:
		_trigger_aoe_damage(global_position, aoe_radius if aoe_radius > 0.0 else 80.0, explosion_damage)
	queue_free()

func _find_nearest_target() -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var enemies := tree.get_nodes_in_group(target_group)
	var nearest: Node2D = null
	var min_dist := 99999.0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not hit_entities.has(enemy.get_instance_id()):
			var d := global_position.distance_to(enemy.global_position)
			if d < min_dist and d < (bounce_range if bouncing_mine else 800.0):
				min_dist = d
				nearest = enemy
	return nearest

func configure_radius(radius: float) -> void:
	hit_radius = radius
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.set_deferred("shape",shape)

func _draw() -> void:
	if missile_texture!=null:
		var size := missile_texture.get_size()*(missile_display_width/missile_texture.get_width())
		if not rocket_ability.is_empty():
			# Remove only the old baked-in flame in the draw region; the body keeps
			# its original dimensions. The new exhaust changes frames independently.
			var body_start := 0.31 if rocket_ability=="e" else 0.21
			var nozzle_x := size.x*(body_start-0.5)
			preload("res://scripts/combat/animated_fx.gd").draw(self,"exhaust",elapsed_time,Vector2(nozzle_x-size.x*0.26,0),Vector2(size.x*0.65,size.y*0.65))
			var texture_size := missile_texture.get_size()
			draw_texture_rect_region(missile_texture,Rect2(Vector2(nozzle_x,-size.y*0.5),Vector2(size.x*(1-body_start),size.y)),Rect2(Vector2(texture_size.x*body_start,0),Vector2(texture_size.x*(1-body_start),texture_size.y)))
		else:
			draw_texture_rect(missile_texture,Rect2(-size*0.5,size),false)
		return
	if not visual_style.is_empty():
		preload("res://scripts/combat/weapon_visuals.gd").draw_projectile(self,visual_style,hit_radius,elapsed_time)
		return
	if movement_pattern == MovementPattern.GROUND_POOL:
		draw_circle(Vector2.ZERO,hit_radius,Color(0.3,0.8,0.2,0.25))
		draw_arc(Vector2.ZERO,hit_radius,0,TAU,32,Color(0.3,0.9,0.4,0.8),2)

func _spawn_impact() -> void:
	if not is_instance_valid(source_owner) or get_tree().get_nodes_in_group("runtime_effects").size()>220: return
	RuntimeEffect.spawn(get_parent(),source_owner,global_position,{"visual":"impact","weapon_id":shot_id,"radius":maxf(7,hit_radius),"damage":0,"duration":0.16})

func _land_fire() -> void:
	if expired: return
	expired=true
	if not is_instance_valid(source_owner):
		queue_free()
		return
	var area := maxf(0.3,float(attacker_stats.get("area_multiplier",1)))
	var fire_duration := float(attacker_stats.get("fire_duration",5))
	var tick_damage := float(attacker_stats.get("fire_tick_damage",damage*0.5))
	for old_fire in get_tree().get_nodes_in_group("ground_hazards"):
		if not is_instance_valid(old_fire) or old_fire.is_queued_for_deletion() or old_fire.done: continue
		if old_fire.source==source_owner and old_fire.global_position.distance_to(global_position)<=aoe_radius*0.5+0.01:
			old_fire.config["duration"]=old_fire.age+fire_duration*source_owner.get_stat("duration_multiplier",1)
			old_fire.base_damage=maxf(old_fire.base_damage,tick_damage)
			old_fire.base_radius=maxf(old_fire.base_radius,aoe_radius)
			old_fire.config["radius"]=old_fire.base_radius
			old_fire.config["evolved"]=old_fire.config.get("evolved",false) or visual_style=="embershot"
			old_fire.config["damage"]=old_fire.base_damage
			queue_free()
			return
	RuntimeEffect.spawn(get_parent(),source_owner,global_position,{"visual":"fire","weapon_id":"weapon_shortbow","radius":aoe_radius/area,"damage":tick_damage,"duration":fire_duration,"interval":0.5,"crit":false,"depth":1,"evolved":visual_style=="embershot"})
	queue_free()

func _explode_rocket() -> void:
	if expired: return
	expired=true
	if GameManager.run_id!=run_token or GameManager.run_finalized or not is_instance_valid(source_owner):
		queue_free()
		return
	var center := global_position
	RuntimeEffect.spawn(get_parent(),source_owner,center,{"visual":"rocket_explosion","radius":aoe_radius,"scale_area":false,"scale_duration":false,"duration":0.65,"damage":0,"ultimate":rocket_ability=="r"})
	for target in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or center.distance_to(target.global_position)>aoe_radius: continue
		var raw := damage
		if rocket_ability=="r": raw*=1+2*clampf(1-target.current_health/maxf(1,target.max_health),0,1)
		DamageSystem.apply_damage(attacker_stats,target,raw,false,source_owner,"true" if rocket_ability=="r" else "physical")
	queue_free()

static func _spawn_splits(parent_ref: WeakRef, owner_ref: WeakRef, pos: Vector2, count: int, damage_amount: float, stats: Dictionary, token: String) -> void:
	var parent = parent_ref.get_ref()
	var owner_node = owner_ref.get_ref()
	if GameManager.run_id != token or GameManager.run_finalized or not is_instance_valid(parent) or not is_instance_valid(owner_node): return
	if parent.is_queued_for_deletion() or not parent.is_inside_tree(): return
	for i in range(count):
		var child = load("res://scenes/combat/projectile_base.tscn").instantiate()
		parent.add_child(child)
		child.global_position = pos
		child.setup(MovementPattern.STRAIGHT,Vector2.from_angle(TAU*i/count),500,damage_amount,1,0.8,owner_node,stats,"feather")
		if stats.get("weapon_id","")=="weapon_blade_o_rang":
			child.movement_pattern=MovementPattern.BOOMERANG
			child.boomerang_range=100
			child.lifetime=1.8
			child.pierce_count=999
			child.configure_radius(5)

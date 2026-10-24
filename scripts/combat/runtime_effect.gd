extends Node2D
class_name RuntimeEffect

# Time and hit ownership stay inside the pausable map. All damage uses DamageSystem.
var source: Node2D
var config: Dictionary = {}
var age := 0.0
var tick := 0.0
var token := ""
var done := false
var hit_ids: Dictionary = {}
var direction := Vector2.RIGHT
var secondary_triggered := false
var base_radius := 0.0
var base_damage := 0.0
var explosion_texture: Texture2D
var companion_target: Node2D
var companion_hit_times: Dictionary = {}
var travel_tick := 0.0
var drone_heal_progress := 0.0
var gatling_stacks: Dictionary = {}
var last_visual_hit := -100.0
var visual_hit_position := Vector2.ZERO

static func spawn(parent: Node, owner_node: Node2D, position_world: Vector2, settings: Dictionary) -> Node2D:
	var effect = RuntimeEffect.new()
	effect.source = owner_node
	effect.config = settings.duplicate(true)
	if is_instance_valid(owner_node) and owner_node.is_in_group("players"):
		if effect.config.has("radius") and effect.config.get("scale_area",true): effect.config["radius"] *= owner_node.get_stat("area_multiplier",1)
		if effect.config.has("duration") and effect.config.get("scale_duration",true): effect.config["duration"] *= owner_node.get_stat("duration_multiplier",1)
	effect.global_position = position_world
	effect.direction = settings.get("direction",Vector2.RIGHT)
	parent.add_child(effect)
	return effect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	token = GameManager.run_id
	add_to_group("runtime_effects")
	if config.get("visual","")=="fire": add_to_group("ground_hazards")
	base_radius=float(config.get("radius",60))
	base_damage=float(config.get("damage",0))
	if config.get("visual","")=="rocket_explosion":
		explosion_texture=load("res://assets/projectiles/jinx/rocket-explosion.res")
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index = 2
	if str(config.get("visual","")) in ["fire","poison","radiant","heal"]: z_index=-1

func _physics_process(delta: float) -> void:
	if done: return
	if token != GameManager.run_id or GameManager.run_finalized or not is_instance_valid(source) or source.is_queued_for_deletion() or source.current_health <= 0:
		done = true
		queue_free()
		return
	if GameManager.current_state != GameManager.GameState.GAMEPLAY: return
	if source.is_in_group("enemies") and source.status_effects.is_stunned_or_frozen(): return
	if source.is_in_group("players") and source.is_downed:
		queue_free()
		return
	age += delta
	var mode = config.get("mode","area")
	if config.has("follow_node"):
		var followed = config["follow_node"]
		if not is_instance_valid(followed) or followed.is_queued_for_deletion() or followed.current_health<=0:
			queue_free()
			return
		global_position=followed.global_position
	if mode in ["bear","drone"]: _move_companion(delta,mode)
	if config.get("visual","")=="fire" and config.get("evolved",false):
		var growth := 1+clampf(age/3.0,0,1)
		config["radius"]=base_radius*growth
		config["damage"]=base_damage*growth
	if config.get("follow",false): global_position = source.global_position+Vector2(config.get("follow_offset",Vector2.ZERO))
	if config.get("aim_nearest",false) and source.has_method("_find_closest_enemy"):
		var target = source._find_closest_enemy()
		if is_instance_valid(target): direction=(target.global_position-global_position).normalized()
	if mode == "train":
		global_position += direction * float(config.get("speed",900.0)) * delta
		travel_tick-=delta
		if config.get("train_explosions",false) and travel_tick<=0:
			travel_tick+=0.25
			RuntimeEffect.spawn(get_parent(),source,global_position,{"visual":"impact","radius":80,"scale_area":false,"scale_duration":false,"damage":config.get("damage",0),"duration":0.2,"once":true,"weapon_id":"weapon_transit","depth":1,"status":"stun","status_duration":1.0})
	if mode == "companion":
		global_position = source.global_position + Vector2.from_angle(age*1.7+float(config.get("phase",0)))*float(config.get("orbit",110))
	if mode == "portal":
		for p in GameManager.active_player_nodes:
			if not is_instance_valid(p) or p.is_downed: continue
			var distance = p.global_position.distance_to(global_position)
			if distance > float(config.get("radius",300))-25 and distance < float(config.get("radius",300))+25 and float(p.get_meta("portal_until",0)) < GameManager.game_time:
				p.global_position = global_position - (p.global_position-global_position).normalized() * (float(config.get("radius",300))-50)
				p.set_meta("portal_until",GameManager.game_time+0.8)
	var warmup = float(config.get("warmup",0))
	# A boss warning only deals damage after its owning attack commits. A stun,
	# phase change or cancelled timer must not leave an independent delayed hit.
	if config.get("requires_commit",false) and not config.get("committed",false):
		if age>=float(config.get("duration",1)):
			done=true
			queue_free()
		queue_redraw()
		return
	if age >= warmup:
		if config.get("mine_secondary",false) and not secondary_triggered:
			secondary_triggered=true
			var centers: Array[Vector2] = []
			for index in 3: centers.append(Vector2.from_angle(TAU*index/3)*30)
			RuntimeEffect.spawn(get_parent(),source,global_position,{"visual":"mine","radius":config.get("secondary_radius",60),"centers":centers,"damage":config.get("secondary_damage",70),"duration":0.7,"warmup":0.264,"scale_duration":false,"once":true,"crit":false,"weapon_id":"weapon_ani_mines"})
		tick -= delta
		if tick <= 0:
			# Preserve fractional remainder instead of losing time on every physics frame.
			var interval := float(config.get("interval",0.5))
			if mode=="bear" and config.get("evolved",false): interval/=1+minf(0.5,age*0.01)
			tick += interval
			_damage_tick(mode)
	if age >= float(config.get("duration",1)):
		done = true
		queue_free()
	queue_redraw()

func _damage_tick(mode: String) -> void:
	if float(config.get("damage",0))<=0 and not config.get("vacuum",false) and float(config.get("heal",0))<=0: return
	var perf = Time.get_ticks_usec() if GameManager.profile_enabled else 0
	var group = "players" if source.is_in_group("enemies") else "enemies"
	var targets = get_tree().get_nodes_in_group(group)
	if config.get("vacuum",false):
		for item in get_tree().get_nodes_in_group("pickups"):
			if item.item_type == 0 and item.global_position.distance_to(global_position)<float(config.get("pickup_radius",500)): item.start_attraction(source)
	if mode == "turret" or config.get("laser",false):
		var selected: Array = []
		var distance = float(config.get("attack_range",config.get("radius",500)))
		for candidate in targets:
			if is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and global_position.distance_to(candidate.global_position)<distance: selected.append(candidate)
		selected.sort_custom(func(a,b): return global_position.distance_squared_to(a.global_position)<global_position.distance_squared_to(b.global_position))
		targets = selected.slice(0,1 if mode == "turret" else int(config.get("shots",1)))
		if not targets.is_empty(): direction = (targets[0].global_position-global_position).normalized()
	if config.get("heal",0.0) > 0 and source.has_method("heal"): source.heal(config["heal"])
	var stats: Dictionary = source.current_stats.duplicate() if source.is_in_group("players") else {}
	stats["weapon_id"] = config.get("weapon_id","")
	stats["attack_id"] = config.get("attack_id","effect:"+str(get_instance_id()))
	stats["crit_chance"]=minf(1,float(stats.get("crit_chance",0))+float(config.get("bonus_crit",0)))
	for target in targets:
		if not is_instance_valid(target) or target.is_queued_for_deletion(): continue
		var offset: Vector2 = target.global_position-global_position
		var radius = float(config.get("radius",120.0))
		var inside = offset.length() <= radius
		if config.has("centers"):
			inside=false
			for center in config["centers"]:
				if offset.distance_to(center)<=radius: inside=true
		if mode in ["beam","train","wall"]:
			var along = offset.dot(direction)
			var across = absf(offset.cross(direction))
			inside = along >= 0 and along <= float(config.get("length",600)) and across < radius
		elif mode == "cone": inside = inside and offset.normalized().dot(direction) > float(config.get("cos_angle",0.5))
		elif mode == "bear": inside=inside and offset.normalized().dot(direction)>=0
		elif mode == "drone":
			inside=inside and age-float(companion_hit_times.get(target.get_instance_id(),-100.0))>=1.0
		if config.get("laser",false): inside = offset.length()<=float(config.get("attack_range",650))
		if not inside: continue
		var id = target.get_instance_id()
		if (config.get("visual","")=="fire" and source.is_in_group("players")) or config.get("shared_tick",false):
			var fire_key := "fire_tick_"+str(source.get_instance_id()) if config.get("visual","")=="fire" else str(config.get("weapon_id",""))+"_tick_"+str(source.get_instance_id())
			if GameManager.game_time-float(target.get_meta(fire_key,-1000))<float(config.get("interval",0.5))-0.00001: continue
			target.set_meta(fire_key,GameManager.game_time)
		if config.get("once",false) and hit_ids.has(id): continue
		hit_ids[id] = int(hit_ids.get(id,0))+1
		if mode == "turret":
			for shot in range(int(config.get("shots",1))):
				if get_tree().get_nodes_in_group("projectiles").size() >= 800: break
				var projectile = load("res://scenes/combat/projectile_base.tscn").instantiate()
				get_parent().add_child(projectile)
				projectile.global_position = global_position
				projectile.setup(0,direction.rotated((shot-(int(config.get("shots",1))-1)*0.5)*0.12),600,float(config.get("damage",20)),1,1.5,source,stats,"gatling")
			continue
		var amount := float(config.get("damage",0))
		if config.get("execute_normals",false) and not target.get("is_boss") and not target.get("is_elite"):
			amount=maxf(amount,target.current_health*100)
		var result := DamageSystem.apply_damage(stats,target,amount,config.get("crit",true),source,config.get("damage_kind","physical"),int(config.get("depth",0)))
		last_visual_hit=age
		visual_hit_position=target.global_position
		if mode=="drone":
			companion_hit_times[id]=age
			if target.has_method("apply_status_effect"): target.apply_status_effect("stun",0.75,1,source)
			if config.get("evolved",false):
				_advance_drone_healing(float(result["damage"])*0.4)
		if config.get("poison_shield",false):
			var amount_shield := minf(float(result["damage"])*0.1,maxf(0,250-source.current_shield))
			if amount_shield>0: source.grant_shield(amount_shield,5)
			source.apply_temporary_buff("poison_speed",0.5,{"speed_pct":minf(0.5,hit_ids.size()*0.005)})
		if config.get("gatling_evolved",false) and target.has_method("apply_status_effect"):
			_apply_gatling_stack(target)
		if target.has_method("apply_status_effect") and not str(config.get("status","")).is_empty():
			target.apply_status_effect(config["status"],float(config.get("status_duration",1.5)),float(config.get("power",1)),source)
		if target.has_method("apply_knockback"):
			target.apply_knockback(offset.normalized()*float(config.get("knockback",0)))
	if GameManager.profile_enabled: GameManager.profile_elapsed("effects",perf)

func _advance_drone_healing(points: float) -> void:
	# Progress belongs to the fighter, including concurrent or subsequent summons.
	drone_heal_progress=float(source.get_meta("yuumibot_heal_progress",0))+points
	var packs := floori(drone_heal_progress/100.0)
	drone_heal_progress=fmod(drone_heal_progress,100.0)
	source.set_meta("yuumibot_heal_progress",drone_heal_progress)
	for i in packs: DropManager.spawn_health_pack(get_parent(),global_position,roundi(source.get_stat("max_health")*0.2))

func _apply_gatling_stack(target: Node2D) -> void:
	var id := target.get_instance_id()
	# A running stun must not be renewed forever by the next tick.
	if GameManager.game_time<float(target.get_meta("gatling_vulnerability_until",-1.0)): return
	var state: Dictionary = gatling_stacks.get(id,{"count":0,"until":-1.0})
	var count := int(state["count"]) if GameManager.game_time<float(state["until"]) else 0
	if count>=4:
		target.apply_status_effect("stun",6.0,1,source)
		target.set_meta("gatling_vulnerability_until",GameManager.game_time+6.0)
		gatling_stacks.erase(id)
	else:
		count+=1
		gatling_stacks[id]={"count":count,"until":GameManager.game_time+4.0}
		target.apply_status_effect("slow",4.0,minf(0.95,count*0.25),source)

func _move_companion(delta: float, mode: String) -> void:
	var reach := float(config.get("attack_range",180))
	var candidates: Array = []
	for target in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(target) and not target.is_queued_for_deletion() and target.current_health>0 and global_position.distance_to(target.global_position)<reach:
			if mode!="drone" or age-float(companion_hit_times.get(target.get_instance_id(),-100))>=1: candidates.append(target)
	if mode=="bear": candidates.sort_custom(func(a,b): return a.current_health>b.current_health)
	else: candidates.sort_custom(func(a,b): return global_position.distance_squared_to(a.global_position)<global_position.distance_squared_to(b.global_position))
	companion_target=candidates[0] if not candidates.is_empty() else null
	var destination: Vector2 = companion_target.global_position if is_instance_valid(companion_target) else source.global_position
	var move_speed: float = 80.0 if mode=="drone" else 80+source.get_stat("movement_speed")*0.2
	if mode=="bear" and config.get("evolved",false):
		move_speed*=minf(3,1+age*0.05)
		config["damage"]=base_damage*minf(4,1+age*0.05)
		config["radius"]=base_radius*minf(1.5,1+age*0.02)
	if destination.distance_to(global_position)>2:
		direction=(destination-global_position).normalized()
		if mode=="drone" or not is_instance_valid(companion_target) or destination.distance_to(global_position)>float(config.get("radius",75))*0.7:
			var desired := global_position.move_toward(destination,move_speed*delta)
			var ray := PhysicsRayQueryParameters2D.create(global_position,desired,16)
			if get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): global_position=desired

func _draw() -> void:
	if explosion_texture!=null:
		var progress := clampf(age/maxf(0.01,float(config.get("duration",0.65))),0,1)
		var diameter := float(config.get("radius",120))*2*(0.45+0.55*minf(1,progress*4))
		preload("res://scripts/combat/animated_fx.gd").draw(self,"explosion",age,Vector2.ZERO,Vector2.ONE*diameter,Color(1,1,1,1-progress),float(config.get("duration",0.65)))
		draw_arc(Vector2.ZERO,diameter*0.5,0,TAU,64,Color(1,0.65,0.2,(1-progress)*0.7),2,true)
		return
	if preload("res://scripts/combat/weapon_visuals.gd").draw_effect(self): return
	var radius = float(config.get("radius",120))
	var color = Color(1,0.25,0.1,0.3) if source != null and source.is_in_group("enemies") else Color(0.2,0.75,1,0.25)
	if age < float(config.get("warmup",0)): color = Color(1,0.25,0.1,0.13)
	var mode = config.get("mode","area")
	if mode == "turret":
		draw_rect(Rect2(-18,-18,36,36),Color(0.5,0.6,0.8))
		draw_line(Vector2.ZERO,direction*40,Color.WHITE,8)
	elif mode in ["beam","train","wall"]:
		var end = direction*float(config.get("length",600))
		draw_line(Vector2.ZERO,end,color,radius*2)
		draw_line(Vector2.ZERO,end,Color(color,0.8),2)
	elif mode == "cone":
		var center = direction.angle()
		var points = PackedVector2Array([Vector2.ZERO])
		for i in range(17): points.append(Vector2.from_angle(center-1.0+2.0*i/16.0)*radius)
		draw_colored_polygon(points,color)
	else:
		draw_circle(Vector2.ZERO,radius,color)
		draw_arc(Vector2.ZERO,radius,0,TAU,40,Color(color,0.8),2)
		if mode == "companion":
			draw_circle(Vector2(-8,-5),4,Color.WHITE)
			draw_circle(Vector2(8,-5),4,Color.WHITE)

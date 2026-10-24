extends RefCounted

# WeaponInstance - Runtime instance of an equipped weapon on a player

class_name WeaponInstance

var weapon_id: String = ""
var data: Dictionary = {}
var level: int = 1
var is_evolved: bool = false
var cooldown_timer: float = 0.0

var casts := 0
var effect_node: Node2D
var host_player: Node2D = null
var pending_shots: Array[Dictionary] = []
var orbit_nodes: Array[Node2D] = []
var orbit_signature := ""
var orbit_hit_times: Dictionary = {}
var last_trail_position := Vector2.INF
var poison_clouds: Array[Node2D] = []

func area_multiplier() -> float:
	return host_player.get_stat("area_multiplier",1) if data.get("scales_area",true) else 1.0

func duration_multiplier() -> float:
	return host_player.get_stat("duration_multiplier",1) if data.get("scales_duration",true) else 1.0

func effect_radius(fallback: float = 100) -> float:
	return (float(data.get("evolution_area_radius",fallback)) if is_evolved else rank_value("base_radius",float(data.get("area_radius",fallback))))*world_scale()

func world_scale() -> float:
	return 0.2 if data.get("reference_units",false) else 1.0

func rank_value(key: String, fallback: float) -> float:
	var value = data.get(key,fallback)
	return float(value[clampi(level-1,0,value.size()-1)]) if value is Array else float(value)

func _queue_shot(delay: float, direction: Vector2, damage: float, pierce: int, speed: float, duration: float, style: String, settings: Dictionary = {}) -> void:
	pending_shots.append({"delay":delay,"direction":direction,"damage":damage,"pierce":pierce,"speed":speed,"duration":duration,"style":style,"attack_id":weapon_id+":"+str(casts),"settings":settings.duplicate()})
	if delay<=0: _tick_pending(0)

func _tick_pending(delta: float) -> void:
	if not is_instance_valid(host_player) or host_player.is_downed or GameManager.run_finalized:
		pending_shots.clear()
		return
	for index in range(pending_shots.size()-1,-1,-1):
		pending_shots[index]["delay"]-=delta
		if pending_shots[index]["delay"]>0: continue
		var shot: Dictionary = pending_shots[index]
		pending_shots.remove_at(index)
		var options: Dictionary = shot["settings"]
		var shot_dir: Vector2 = shot["direction"]
		if options.get("retarget",false):
			var target = _nearest(host_player.global_position,{})
			if is_instance_valid(target): shot_dir=(target.global_position-host_player.global_position).normalized()
		var origin: Vector2 = host_player.begin_primary_shot(shot_dir) if weapon_id=="weapon_meow_meow" else host_player.global_position
		if weapon_id=="weapon_uwu_blaster":
			var offset: Vector2 = Vector2(-25,-12)*host_player.actor_scale
			var mount: Vector2 = host_player.global_position+offset
			if options.has("aim_point") and mount.distance_squared_to(options["aim_point"])>0.01: shot_dir=(Vector2(options["aim_point"])-mount).normalized()
			origin=mount+shot_dir*preload("res://scripts/combat/arsenal_vfx.gd").UWU_SIZE*0.41
			if not is_instance_valid(effect_node) or effect_node.is_queued_for_deletion():
				effect_node=_effect(mount,{"visual":"uwu_emitter","radius":0,"damage":0,"duration":0.28,"scale_duration":false,"scale_area":false,"follow":true,"follow_offset":offset})
			effect_node.direction=shot_dir
			effect_node.config["last_fire"]=effect_node.age
			effect_node.config["duration"]=effect_node.age+0.28
		if options.has("aim_point") and origin.distance_squared_to(options["aim_point"])>0.01:
			shot_dir=(Vector2(options["aim_point"])-origin).normalized()
		var projectile = _projectile(origin,shot_dir,shot["damage"],shot["pierce"],int(options.get("pattern",0)),shot["speed"],shot["duration"])
		projectile.visual_style=shot["style"]
		projectile.attacker_stats["attack_id"]=shot["attack_id"]
		for key in options:
			if key in ["pattern","retarget","aim_point"]: continue
			projectile.set(key,options[key])

func _init(w_id: String, player: Node2D) -> void:
	weapon_id = w_id
	data = WeaponRegistry.get_weapon_data(w_id)
	host_player = player
	level = 1
	is_evolved = false
	cooldown_timer = 0.0

func upgrade() -> bool:
	if is_evolved:
		return false
	if level < 5:
		level += 1
		return true
	return false

func can_evolve(has_required_passive: bool) -> bool:
	if is_evolved or level < 5:
		return false
	return has_required_passive

func evolve() -> void:
	if is_evolved: return
	# Keep the current cooldown and every existing hit lockout. Already released
	# projectiles/ground effects finish with their captured stats; no bonus cast.
	pending_shots.clear()
	is_evolved = true
	if weapon_id=="weapon_slicers" and is_instance_valid(host_player) and orbit_nodes.any(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion() and not node.expired): _sync_slicers()
	AudioManager.play_sfx("evolve")

func update(delta: float) -> void:
	_tick_pending(delta)
	if weapon_id=="weapon_paw_poison":
		_update_poison_trail()
		return
	if weapon_id=="weapon_iceblast" and host_player.get_meta("iceblast_armed",false): return
	if weapon_id=="weapon_gatling" and is_instance_valid(effect_node) and not effect_node.is_queued_for_deletion():
		# A volley already in progress finishes as the version that started it.
		if bool(effect_node.config.get("evolved",false))==is_evolved:
			effect_node.config["damage"]=get_damage()
			effect_node.config["radius"]=(float(data["evolution_range"]) if is_evolved else rank_value("base_range",725))*world_scale()*area_multiplier()
			effect_node.config["duration"]=(float(data["evolution_duration"]) if is_evolved else rank_value("base_duration",8))*duration_multiplier()
			effect_node.config["gatling_evolved"]=is_evolved
		cooldown_timer=get_effective_cooldown()
		return
	if weapon_id=="weapon_slicers":
		cooldown_timer=maxf(0,cooldown_timer-delta)
		orbit_nodes=orbit_nodes.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion() and not node.expired)
		if not orbit_nodes.is_empty():
			_sync_slicers()
			return
		if cooldown_timer<=0:
			fire()
			cooldown_timer=get_effective_cooldown()
		return
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		if weapon_id=="weapon_uwu_blaster" and not is_instance_valid(_nearest(host_player.global_position,{})): return
		fire()
		cooldown_timer += get_effective_cooldown()
		cooldown_timer=maxf(0,cooldown_timer)

func get_effective_cooldown() -> float:
	var base_cd: float = 1.0
	if is_evolved:
		base_cd = float(data.get("evolution_cooldown", 0.5))
	else:
		var cd_arr: Array = data.get("base_cooldown", [1.0, 1.0, 1.0, 1.0, 1.0])
		var idx := mini(level - 1, cd_arr.size() - 1)
		base_cd = float(cd_arr[idx])
	if not data.get("scales_haste",true): return base_cd

	var haste := 0.0
	if host_player and host_player.has_method("get_stat"):
		haste = host_player.get_stat("ability_haste", 0.0)

	return StatCalculator.calculate_effective_cooldown(base_cd, haste) * host_player.get_stat("cooldown_multiplier",1)

func get_damage() -> float:
	if is_evolved:
		return float(data.get("evolution_damage", 100.0))
	var dmg_arr: Array = data.get("base_damage", [30.0, 40.0, 50.0, 60.0, 70.0])
	var idx := mini(level - 1, dmg_arr.size() - 1)
	return float(dmg_arr[idx])

func get_hit_damage() -> float:
	var raw := get_damage()
	if weapon_id=="weapon_radiant_field": raw+=host_player.get_stat("max_health")*0.05
	if weapon_id in ["weapon_transit","weapon_iceblast"]: raw+=host_player.get_stat("armor")*(5 if weapon_id=="weapon_transit" else 2.5)
	return raw

func stat_summary() -> String:
	var damage: float = get_hit_damage()*host_player.get_stat("damage_multiplier",1)
	var units := "Ziele" if weapon_id in ["weapon_mega_blast","weapon_statikk"] else "Geschosse"
	var text := "%s: %.1f\nAbklingzeit: %.2f s" % [damage_label(),damage,get_effective_cooldown()]
	if get_projectiles()>1 or data.get("scales_projectiles",true): text+="\n%s: %d" % [units,get_projectiles()]
	if data.has("range"): text+="\nReichweite: %d" % int(data["range"])
	if data.has("base_radius"): text+="\nWirkungsradius: %d" % roundi(effect_radius()/world_scale()*area_multiplier())
	if data.has("base_duration"): text+="\nDauer: %.1f s" % ((float(data.get("evolution_duration",0)) if is_evolved else rank_value("base_duration",0))*duration_multiplier())
	if weapon_id=="weapon_slicers" and is_evolved: text="Schaden: %.1f\nDauerhafte Klingen: %d" % [damage,get_projectiles()]
	if weapon_id=="weapon_paw_poison": text="Schaden/s: %.1f\nGiftspur · 4 Ticks/s" % damage
	if weapon_id=="weapon_gatling":
		var active := is_instance_valid(effect_node) and not effect_node.is_queued_for_deletion()
		text+="\nFeuer läuft: %.1f s" % maxf(0,float(effect_node.config["duration"])-effect_node.age) if active else "\nNachladen: %.1f s" % maxf(0,cooldown_timer)
	if weapon_id=="weapon_meow_meow": text+="\nSalve ohne Krit: %.1f Schaden (%d × %.1f)" % [damage*get_projectiles(),get_projectiles(),damage]
	return text

func damage_label() -> String:
	if weapon_id in ["weapon_shortbow","weapon_paw_poison"]: return "Schaden/s"
	if weapon_id in ["weapon_radiant_field","weapon_gatling"]: return "Schaden/Tick"
	if weapon_id=="weapon_meow_meow": return "Schaden/Cluster"
	if weapon_id=="weapon_tibbers": return "Schaden/Hieb"
	return "Schaden"

func get_projectiles() -> int:
	var base_proj := 1
	if is_evolved:
		base_proj = int(data.get("evolution_projectiles", 4))
	else:
		var proj_arr: Array = data.get("base_projectiles", [1, 1, 2, 2, 3])
		var idx := mini(level - 1, proj_arr.size() - 1)
		base_proj = int(proj_arr[idx])

	var bonus_proj := 0
	if data.get("scales_projectiles",true) and host_player and host_player.has_method("get_stat"):
		bonus_proj = int(host_player.get_stat("bonus_projectiles", 0))

	return base_proj + bonus_proj

func fire() -> void:
	if not is_instance_valid(host_player) or not host_player.is_inside_tree() or host_player.is_downed: return
	casts += 1
	var pos = host_player.global_position
	var dir = Vector2.from_angle(GameManager.game_time*4) if host_player.temp_buffs.has("bonus_cruise") else host_player.get_aim_direction()
	if weapon_id == host_player.char_data.get("starter_weapon", ""):
		host_player.visual_animator.attack(dir)
	var radius = float(data.get("evolution_area_radius",data.get("area_radius",140))) if is_evolved else float(data.get("area_radius",140))
	var echo = host_player.consume_echo()
	var dmg = get_hit_damage()
	if weapon_id == "weapon_shield_slam": dmg += host_player.get_stat("armor")*3.0
	var count = get_projectiles()*(2 if echo else 1)
	if echo and weapon_id in ["weapon_iceblast","weapon_radiant_field","weapon_shield_slam","weapon_tentacle_slam","weapon_pillory_swipe","weapon_bunny_hop"]: dmg *= 2
	var duration = float(data.get("evolution_duration",4)) if is_evolved else rank_value("base_duration",3.5)
	match weapon_id:
		"weapon_meow_meow":
			var aim_point: Vector2 = host_player.primary_aim_point(dir)
			for index in count:
				_queue_shot(index*float(data.get("burst_interval",0.066)),dir,dmg,999 if is_evolved else 1,700,1500.0/3500.0,"meow",{"damage_falloff":0.4 if is_evolved else 1.0,"aim_point":aim_point})
		"weapon_crossbow":
			var facing := Vector2.from_angle(randf()*TAU)
			var step := deg_to_rad(180.0 if is_evolved else 45.0)/maxi(1,count-1)
			for index in count:
				var arrow = _projectile(pos,facing.rotated((index-(count-1)*0.5)*step),dmg,999,0,float(data["projectile_speed"])*world_scale(),float(data["range"])/float(data["projectile_speed"])+0.05)
				arrow.crit_pierce=true
				arrow.visual_style="crossbow"
				arrow.max_travel_distance=float(data["range"])*world_scale()
		"weapon_uwu_blaster":
			var target = _nearest(pos,{})
			if not is_instance_valid(target): return
			var shot_dir: Vector2 = (target.global_position-pos).normalized()
			for index in count:
				_queue_shot(index*float(data["burst_interval"]),shot_dir,dmg,1,float(data["projectile_speed"])*world_scale(),float(data["range"])/float(data["projectile_speed"]),"owo" if is_evolved else "uwu",{"max_travel_distance":float(data["range"])*world_scale(),"aim_point":target.global_position})
		"weapon_ani_mines":
			var explosion_radius := effect_radius(400)
			for index in count:
				var point: Vector2 = pos+Vector2.from_angle(TAU*index/count)*55.0
				var delay: float = 275.0/1750.0+0.5+index*0.264
				_effect(point,{"visual":"mine","radius":explosion_radius,"damage":dmg,"warmup":delay,"duration":delay+0.3,"once":true,"crit":false,"scale_duration":false,"mine_secondary":is_evolved,"secondary_damage":70,"secondary_radius":60})
		"weapon_anti_shark":
			var target = _nearest(pos,{})
			if not is_instance_valid(target): return
			var proj = _projectile(pos,(target.global_position-pos).normalized(),dmg,int(data.get("evolution_bounces",999)) if is_evolved else int(rank_value("base_bounces",3)),1,200,99999 if is_evolved else 15)
			proj.bouncing_mine=true
			proj.bounce_range=120
			proj._homing_target=target
			proj.aoe_radius=80*area_multiplier()
			proj.aoe_damage=float(data.get("evolution_explosion_damage",200)) if is_evolved else rank_value("base_explosion_damage",50)
			proj.aoe_hits_primary=true
			proj.visual_style="sea_mine"
		"weapon_blade_o_rang":
			for i in range(count):
				_queue_shot(i*0.18,dir,dmg,999,500,2.0,"weapon_blade_o_rang",{"pattern":3,"retarget":true,"boomerang_range":160.0,"boomerang_split":is_evolved})
				if is_evolved: _queue_shot(0,Vector2.from_angle(TAU*i/count),dmg,999,500,2.0,"weapon_blade_o_rang",{"pattern":3,"boomerang_range":160.0,"boomerang_split":true})
		"weapon_slicers":
			_sync_slicers()
		"weapon_batblades":
			var facing := Vector2.from_angle(randf()*TAU)
			for i in range(count):
				var proj = _projectile(pos,facing.rotated((i-(count-1)*0.5)*deg_to_rad(10)),dmg,999,0,360,2000.0/1800.0)
				proj.terrain_bounce=true
				proj.bounce_damage_multiplier=1.25 if is_evolved else 1.0
				proj.visual_style="batblade"
		"weapon_statikk":
			var origin = pos
			var targets := _targets_by_health(pos,float(data.get("range",1100))*world_scale())
			for enemy in targets.slice(0,count):
				_effect(origin,{"mode":"beam","visual":"lightning_chain","direction":(enemy.global_position-origin).normalized(),"length":origin.distance_to(enemy.global_position),"radius":6,"duration":0.15,"damage":0,"scale_duration":false,"scale_area":false})
				var stats: Dictionary = host_player.current_stats.duplicate()
				stats["weapon_id"]=weapon_id
				DamageSystem.apply_damage(stats,enemy,dmg,true,host_player)
				if is_evolved: _effect(enemy.global_position,{"visual":"electric","radius":20,"damage":80*host_player.get_stat("crit_damage",2),"duration":3,"interval":0.528,"follow_node":enemy,"crit":false})
				origin = enemy.global_position
		"weapon_transit":
			var facing := Vector2.from_angle(randf()*TAU)
			_effect(pos-facing*275,{"mode":"train","visual":"train","direction":facing,"speed":170,"length":60,"radius":50,"damage":dmg,"duration":2750.0/850.0,"scale_duration":false,"scale_area":false,"once":true,"train_explosions":is_evolved,"status":"stun" if is_evolved else "","status_duration":1.0})
		"weapon_annihilator":
			_effect(pos,{"visual":"orbital","radius":effect_radius(1700),"damage":dmg,"warmup":3.0,"duration":3.5,"scale_duration":false,"once":true,"crit":false,"execute_normals":true})
		"weapon_mega_blast":
			var targeted: Dictionary = {}
			for i in range(count if not is_evolved else 12):
				var enemy = _nearest(pos,targeted)
				if enemy: targeted[enemy.get_instance_id()]=true
				var point = enemy.global_position if enemy else pos+Vector2.from_angle(randf()*TAU)*randf_range(25,160)
				var delay: float = 0.5+(i*1.25/12.0 if is_evolved else 0)
				var blast_radius := 36.0 if not is_evolved else (18.0 if i<6 else (36.0 if i<9 else (60.0 if i<11 else 180.0)))
				_effect(point,{"visual":"orbital","radius":blast_radius,"damage":dmg,"warmup":delay,"duration":delay+0.3,"scale_duration":false,"once":true})
		"weapon_gatling":
			if is_instance_valid(effect_node) and not effect_node.is_queued_for_deletion(): return
			var reach := float(data.get("evolution_range",975)) if is_evolved else rank_value("base_range",725)
			effect_node=_effect(pos,{"mode":"cone","visual":"gatling","direction":dir,"radius":reach*world_scale(),"cos_angle":cos(deg_to_rad(float(data["cone_degrees"])*0.5)),"duration":duration,"interval":float(data["tick_interval"]),"follow":true,"aim_nearest":true,"crit":false,"damage":dmg,"gatling_evolved":is_evolved})
		"weapon_iceblast":
			host_player.set_meta("iceblast_armed",true)
			host_player.set_meta("iceblast_weapon",self)
			cooldown_timer=0
		"weapon_lioness":
			for index in count:
				var side := Vector2.RIGHT if index%2==0 else Vector2.LEFT
				var speed := (2500.0 if is_evolved else 2100.0)*world_scale()
				var reach := float(data.get("evolution_range",1250) if is_evolved else data.get("range",450))*world_scale()
				if is_evolved:
					for direction in [Vector2.RIGHT,Vector2.LEFT]: _queue_shot(1+index*0.528,direction,dmg,999,speed,reach/speed,"light_ray")
				else:
					var hit_group: Dictionary = {}
					for curve in [-1,0,1]: _queue_shot(index*0.528,side,dmg,999,speed,reach/speed,"crescent",{"shared_hit_ids":hit_group,"curve_amplitude":float(curve)*14.0})
		"weapon_paw_poison":
			_update_poison_trail()

		"weapon_radiant_field":
			var aura_radius := effect_radius(220)
			if is_instance_valid(effect_node) and not effect_node.is_queued_for_deletion():
				effect_node.config["damage"]=dmg
				effect_node.config["radius"]=aura_radius*host_player.get_stat("area_multiplier",1)
				effect_node.config["evolved"]=is_evolved
			else:
				effect_node=_effect(pos,{"visual":"radiant","radius":aura_radius,"damage":dmg,"duration":9999,"interval":0.5,"follow":true,"scale_duration":false})
		"weapon_shortbow":
			var targeted: Dictionary = {}
			var candidates: Array = host_player.get_tree().get_nodes_in_group("enemies").filter(func(enemy): return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and pos.distance_to(enemy.global_position)<=float(data["range"])*world_scale())
			candidates.shuffle()
			for index in count:
				var enemy = candidates[index] if index<candidates.size() else null
				if enemy: targeted[enemy.get_instance_id()]=true
				var landing: Vector2 = enemy.global_position if enemy else pos+Vector2.from_angle(randf()*TAU)*randf_range(60,float(data["range"])*world_scale())
				var flight_speed: float = maxf(1,pos.distance_to(landing)/float(data["flight_time"]))
				var projectile = _projectile(pos,(landing-pos).normalized(),dmg,1,0,flight_speed,0.6)
				projectile.ground_target=landing
				projectile.ground_travel_time=float(data["flight_time"])
				projectile.speed=flight_speed
				projectile.visual_style="embershot" if is_evolved else "fire_arrow"
				projectile.aoe_radius=effect_radius(200)*area_multiplier()
				projectile.attacker_stats["fire_duration"]=duration
				projectile.attacker_stats["fire_tick_damage"]=dmg*0.5
				_effect(landing,{"visual":"landing","radius":effect_radius(200),"damage":0,"duration":0.5,"scale_duration":false})
		"weapon_tibbers", "weapon_yuumibot":
			var robot = weapon_id == "weapon_yuumibot"
			if not robot and is_instance_valid(effect_node) and not effect_node.is_queued_for_deletion(): return
			effect_node = _effect(pos,{"mode":"drone" if robot else "bear","visual":"drone" if robot else "bear","radius":effect_radius(100 if robot else 375),"damage":dmg,"duration":duration,"interval":0.5,"attack_range":180 if robot else 140,"pickup_radius":300*host_player.get_stat("pickup_radius",100)/100.0*world_scale(),"evolved":is_evolved,"vacuum":robot,"crit":false})

		"weapon_vortex_glove":
			for i in range(count):
				var angle := GameManager.game_time+i*0.066
				_queue_shot(i*0.066,Vector2.from_angle(angle),dmg,999,300,0.8,"vortex")
				if is_evolved: _queue_shot(i*0.066,Vector2.from_angle(-angle),dmg,999,300,0.8,"dark_vortex")
		"weapon_shield_slam": _effect(pos,{"mode":"cone","direction":dir,"radius":radius,"damage":dmg,"duration":0.25,"once":true,"knockback":550 if is_evolved else 180,"status":"stun","status_duration":0.7})
		"weapon_tentacle_slam": _effect(pos+dir*80,{"mode":"cone","direction":dir,"radius":radius,"damage":dmg,"duration":duration,"interval":1.0,"tentacle":true})
		"weapon_pillory_swipe":
			_effect(pos,{"radius":radius,"damage":dmg,"duration":0.2,"once":true,"status":"bleed","power":dmg*0.25,"status_duration":3})
			if is_evolved: host_player.heal(8)
		"weapon_steel_tempest":
			_salvo(pos,dir,dmg,count)
			if casts%3 == 0 or is_evolved: _effect(pos,{"mode":"train","direction":dir,"speed":220,"length":40,"radius":90,"damage":dmg,"duration":3,"interval":0.5,"status":"stun","status_duration":0.5})
		"weapon_bunny_hop":
			host_player.start_dash(dir,400,0.12)
			_effect(pos,{"radius":radius,"damage":dmg,"warmup":0.15,"duration":0.35,"once":true,"knockback":150})
			if is_evolved: host_player.grant_shield(30,2)
		"weapon_guiding_hex":
			for i in range(count):
				var proj = _projectile(pos,Vector2.from_angle(TAU*i/count),dmg,4 if is_evolved else 1,1,550,3.5)
				proj.status_effects["slow"] = {"duration":1.5,"power":0.2}
				proj.ricochet = is_evolved
				proj.split_count = 2 if is_evolved else 0
		"weapon_sound_wave": _salvo(pos,dir,dmg,count,"slow")
		"weapon_winged_dagger":
			for i in range(count):
				var proj = _projectile(pos,dir.rotated((i-(count-1)*0.5)*0.15),dmg,8 if is_evolved else 3,1 if is_evolved else 0,750,2)
				proj.leaves_feather = true
				proj.ricochet = is_evolved
		_: _salvo(pos,dir,dmg,count)
	AudioManager.play_sfx("shoot",randf_range(0.9,1.1))

func _sync_slicers() -> void:
	orbit_nodes=orbit_nodes.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion() and not node.expired)
	var count := get_projectiles()
	var signature := str([count,level,is_evolved,area_multiplier(),duration_multiplier(),get_damage(),host_player.get_stat("damage_multiplier",1)])
	if signature==orbit_signature and orbit_nodes.size()==count: return
	orbit_signature=signature
	var phase: float = orbit_nodes[0].orbit_angle if not orbit_nodes.is_empty() else 0.0
	var age: float = orbit_nodes[0].elapsed_time if not orbit_nodes.is_empty() else 0.0
	while orbit_nodes.size()>count:
		var old = orbit_nodes.pop_back()
		old.expired=true
		old.queue_free()
	while orbit_nodes.size()<count:
		var blade = _projectile(host_player.global_position,Vector2.RIGHT,get_damage(),999,2,0,999999)
		blade.elapsed_time=age
		orbit_nodes.append(blade)
	for i in orbit_nodes.size():
		var blade = orbit_nodes[i]
		blade.orbit_center_node=host_player
		blade.orbit_angle=phase+TAU*i/maxi(1,count)
		blade.orbit_radius=float(data["evolution_orbit_radius"] if is_evolved else data["orbit_radius"])*world_scale()*area_multiplier()
		blade.orbit_speed=float(data["orbit_speed"])
		blade.rehit_interval=float(data["hit_lockout"])
		blade.damage_lockout_time=float(data["hit_lockout"])
		blade.damage_lockouts=orbit_hit_times
		# Enemy knockback is velocity with 900 units/s² drag, while the source value is distance.
		blade.knockback_strength=sqrt(2.0*900.0*float(data["push_distance"])*world_scale())
		blade.damage=get_damage()
		blade.attacker_stats=host_player.current_stats.duplicate()
		blade.attacker_stats["weapon_id"]=weapon_id
		blade.attacker_stats["can_crit"]=false
		blade.attacker_stats["evolved"]=is_evolved
		blade.lifetime=999999 if is_evolved else rank_value("base_duration",7)*duration_multiplier()
		blade.visual_style="slicer"
		var width := float(data["evolution_projectile_width"] if is_evolved else data["projectile_width"])*world_scale()*area_multiplier()
		blade.configure_radius(width*0.5)
		blade.missile_display_width=width*float(data["evolution_visual_size_multiplier"] if is_evolved else data["visual_size_multiplier"])
		blade.global_position=host_player.global_position+Vector2.from_angle(blade.orbit_angle)*blade.orbit_radius
		blade.rotation=blade.orbit_angle
		effect_node=blade
	for id in orbit_hit_times.keys():
		if GameManager.game_time-float(orbit_hit_times[id])>2: orbit_hit_times.erase(id)

func _projectile(pos: Vector2, dir: Vector2, dmg: float, pierce: int, pattern: int, speed: float, duration: float):
	var proj = load("res://scenes/combat/projectile_base.tscn").instantiate()
	host_player.get_parent().add_child(proj)
	proj.global_position = pos
	var stats = host_player.current_stats.duplicate()
	stats["weapon_id"] = weapon_id
	stats["evolved"] = is_evolved
	stats["attack_id"] = weapon_id+":"+str(casts)
	stats["can_crit"] = data.get("can_crit",true)
	stats["scale_projectile_duration"] = data.get("scales_duration",not data.get("reference_units",false)) and weapon_id!="weapon_shortbow"
	stats["area_multiplier"] = area_multiplier()
	stats["crit_chance"] = minf(1,float(stats.get("crit_chance",0))+ (float(data.get("evolution_bonus_crit",0)) if is_evolved else rank_value("base_bonus_crit",0)))
	var size = 1.0
	proj.setup(pattern,dir,speed*host_player.get_stat("projectile_speed_multiplier",1),dmg,pierce,duration,host_player,stats,"feather" if weapon_id == "weapon_winged_dagger" else "bullet")
	proj.configure_radius(float(data.get("projectile_width",24))*world_scale()*0.5*size*area_multiplier())
	proj.shot_id = weapon_id
	return proj

func _salvo(pos: Vector2, dir: Vector2, damage: float, count: int, status: String = "") -> void:
	var echo = 1
	var spread := 0.025 if weapon_id=="weapon_meow_meow" else 0.16
	for i in range(count*echo):
		var p = _projectile(pos,Vector2.from_angle(TAU*i/maxi(1,count*echo)) if host_player.temp_buffs.has("bonus_cruise") else dir.rotated((i-(count*echo-1)*0.5)*spread),damage,int(data.get("evolution_pierce",999)) if is_evolved else int(data.get("pierce",2)),0,float(data.get("projectile_speed",750)),2.5)
		if not status.is_empty(): p.status_effects[status] = {"duration":2,"power":damage*0.25 if status == "burn" else 0.3}
		if weapon_id == "weapon_shortbow": p.aoe_radius = (110 if is_evolved else 50)*host_player.get_stat("area_multiplier",1)
		if weapon_id == "weapon_crossbow" and is_evolved: p.split_count = 3

func _effect(pos: Vector2, settings: Dictionary) -> Node2D:
	var spec = settings.duplicate()
	spec["weapon_id"] = weapon_id
	spec["attack_id"] = weapon_id+":"+str(casts)
	spec["evolved"] = is_evolved
	spec["scale_area"] = settings.get("scale_area",data.get("scales_area",true))
	spec["scale_duration"] = settings.get("scale_duration",data.get("scales_duration",true))
	spec["crit"] = bool(settings.get("crit",data.get("can_crit",true))) and bool(data.get("can_crit",true))
	spec["bonus_crit"] = float(data.get("evolution_bonus_crit",0)) if is_evolved else rank_value("base_bonus_crit",0)
	return RuntimeEffect.spawn(host_player.get_parent(),host_player,pos,spec)

func _targets_by_health(pos: Vector2, reach: float) -> Array:
	var targets: Array = []
	for target in host_player.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(target) and not target.is_queued_for_deletion() and target.current_health>0 and pos.distance_to(target.global_position)<=reach: targets.append(target)
	targets.shuffle()
	targets.sort_custom(func(a,b): return a.current_health>b.current_health)
	return targets

func _update_poison_trail() -> void:
	var pos: Vector2 = host_player.global_position
	if not last_trail_position.is_finite():
		last_trail_position=pos
		return
	if pos.distance_to(last_trail_position)<16: return
	poison_clouds=poison_clouds.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion())
	var cloud_radius := effect_radius(150)*0.5
	for cloud in poison_clouds:
		if cloud.global_position.distance_to(pos)<cloud_radius*area_multiplier(): return
	last_trail_position=pos
	var lifetime := float(data.get("evolution_duration",7.5)) if is_evolved else rank_value("base_duration",2.5)
	var cloud := _effect(pos,{"visual":"poison","radius":cloud_radius,"damage":get_damage()*float(data["tick_interval"]),"duration":lifetime,"interval":float(data["tick_interval"]),"poison_shield":is_evolved,"crit":false,"shared_tick":true})
	poison_clouds.append(cloud)
	if poison_clouds.size()>24: poison_clouds.pop_front().queue_free()

func consume_iceblast() -> void:
	host_player.set_meta("iceblast_armed",false)
	cooldown_timer=get_effective_cooldown()
	_ice_nova()
	if is_evolved:
		var shield: float = 200+host_player.get_stat("max_health")*0.2
		host_player.grant_shield(shield,5)
		host_player.shield_layers[-1]["iceblast"]=true
		host_player.set_meta("iceblast_shield_weapon",self)

func _ice_nova() -> void:
	var freeze_time := (float(data.get("evolution_duration",5)) if is_evolved else rank_value("base_duration",2))*duration_multiplier()
	_effect(host_player.global_position,{"visual":"ice","radius":effect_radius(600),"damage":get_damage()+host_player.get_stat("armor")*2.5,"duration":0.3,"scale_duration":false,"once":true,"status":"freeze","status_duration":freeze_time,"crit":false})

func _nearest(pos: Vector2, excluded: Dictionary):
	var best = null
	var distance = float(data.get("range",650))*world_scale()
	for enemy in host_player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.current_health<=0 or excluded.has(enemy.get_instance_id()): continue
		var d = pos.distance_to(enemy.global_position)
		if d < distance:
			distance = d
			best = enemy
	return best

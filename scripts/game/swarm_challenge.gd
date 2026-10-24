extends Node2D

# Minigame goals, not proximity rewards. Parameters below are clone calibration;
# original server quest scripts were not available in the client archive.
const YUUMI := ["football","vases","yarn","chumper","boxes","beach_ball","race","marathon","laser"]
const TRIALS := ["miniboss","horde","circle","linked","meteors","darkness"]
const TITLES := {"football":"Ab ins Tor!","vases":"Antike? Weg damit!","yarn":"Wollknäuel rollen","chumper":"Fang den Chumper!","boxes":"Kisten sammeln und abliefern","beach_ball":"Strandball oben halten","race":"Rennen zum Ziel","marathon":"Marathon","laser":"Laserjagd","miniboss":"Bel’Veth: Großwildjagd","horde":"Bel’Veth: Angriffswelle","circle":"Bel’Veth: Im Kreis überleben","linked":"Bel’Veth: Zusammenbleiben"}
var kind := ""
var origin := Vector2.ZERO
var target := Vector2.ZERO
var goal := Vector2.ZERO
var ball := Vector2.ZERO
var ball_velocity := Vector2.ZERO
var points: Array[Vector2] = []
var entities: Array[Node2D] = []
var carried: Dictionary = {}
var accounted: Dictionary = {}
var progress := 0.0
var required := 1.0
var remaining := 60.0
var elapsed := 0.0
var held := 0.0
var bounce_clock := 4.0
var spawn_clock := 0.0
var result := 0
var token := ""
var director: Node2D
var hazards: Array[Dictionary] = []
var darkness: ColorRect

func begin(owner_director: Node2D, id: String, at: Vector2) -> void:
	director=owner_director
	kind=id
	token=GameManager.run_id+":"+str(get_instance_id())
	origin=at
	target=at
	goal=_open_destination(at,220)
	ball=at
	remaining=75 if kind in ["marathon","boxes","vases","yarn"] else 60
	match kind:
		"football": required=1
		"vases":
			required=15
			for i in 15:
				var vase = load("res://scenes/combat/loot_crate.tscn").instantiate()
				vase.set_script(load("res://scripts/game/challenge_vase.gd"))
				add_child(vase)
				vase.global_position=_safe(origin+Vector2.from_angle(i*2.4)*(70+(i%4)*35))
				vase.objective_destroyed.connect(_vase_destroyed)
				entities.append(vase)
		"yarn": required=650
		"boxes":
			required=5
			for i in 5: points.append(_safe(origin+Vector2.from_angle(i*TAU/5)*(90+i*25)))
		"beach_ball":
			required=6
			target=_open_destination(origin,100)
		"race","marathon","laser":
			required=6 if kind=="marathon" else (5 if kind=="laser" else 3)
			var previous := origin
			for i in int(required):
				previous=_open_destination(previous,270 if kind=="marathon" else 140)
				points.append(previous)
			target=points[0]
		"chumper","miniboss":
			required=1
			var enemy = _spawn_enemy("mini_boss",_open_destination(origin,150))
			if is_instance_valid(enemy):
				enemy.set_meta("challenge_token",token)
				enemy.drops_access_card=false
				enemy.exp_drop=0
				if kind=="chumper":
					enemy.contact_damage=0
					enemy.magic_damage=0
					enemy.drops_access_card=false
					enemy.exp_drop=0
					enemy.set_physics_process(false)
				entities.append(enemy)
		"horde": required=35
		"circle","linked","meteors","darkness": required=30
	_setup_darkness()
	queue_redraw()

func _setup_darkness() -> void:
	if kind=="darkness":
		if is_instance_valid(darkness): return
		var layer := CanvasLayer.new()
		layer.layer=0 # Above the world, below the ordinary HUD (layer 1).
		add_child(layer)
		darkness=ColorRect.new()
		darkness.mouse_filter=Control.MOUSE_FILTER_IGNORE
		layer.add_child(darkness)
		var shader := Shader.new()
		shader.code="shader_type canvas_item; uniform vec2 centers[4]; uniform int count=1; void fragment(){ float d=100000.0; for(int i=0;i<4;i++){if(i<count){d=min(d,distance(FRAGCOORD.xy,centers[i]));}} COLOR=vec4(0.015,0.02,0.04,0.92*smoothstep(180.0,280.0,d)); }"
		var material := ShaderMaterial.new()
		material.shader=shader
		darkness.material=material

func network_visual_update() -> void:
	_setup_darkness()
	if not is_instance_valid(darkness): return
	var players := _players()
	darkness.size = get_viewport_rect().size
	var centers := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for i in mini(4, players.size()): centers[i] = get_viewport().get_canvas_transform() * players[i].global_position
	darkness.material.set_shader_parameter("centers", centers)
	darkness.material.set_shader_parameter("count", mini(4, players.size()))

func _safe(at: Vector2) -> Vector2:
	var map = director.get_parent()
	return map.get_safe_position(at,22) if map.has_method("get_safe_position") else at.clamp(Vector2(-1600,-1600),Vector2(1600,1600))

func _open_destination(at: Vector2, distance: float) -> Vector2:
	for attempt in 32:
		var candidate := _safe(at+Vector2.from_angle(randf()*TAU)*distance)
		if candidate.distance_to(at)<distance*0.5: continue
		var query := PhysicsRayQueryParameters2D.create(at,candidate,16)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty(): return candidate
	return _safe(at+Vector2(60,0))

func _players() -> Array:
	return GameManager.active_player_nodes.filter(func(p): return is_instance_valid(p) and not p.is_downed)

func _spawn_enemy(id: String, at: Vector2):
	var spawner = director.get_parent().get_node_or_null("EnemySpawner")
	if not spawner or spawner.active_enemies.size()>=spawner.max_concurrent_enemies+preload("res://scripts/game/warehouse_balance.gd").TRIAL_RESERVE: return null
	return spawner._spawn_single_enemy(id,spawner.safe_position(at),preload("res://scripts/game/warehouse_balance.gd").TRIAL_RESERVE)

func update(delta: float) -> int:
	if result!=0: return result
	remaining-=delta
	elapsed+=delta
	var players := _players()
	if players.is_empty(): return _finish(-1)
	match kind:
		"football","yarn":
			for p in players:
				if p.global_position.distance_to(ball)<34:
					var away: Vector2 = ball-p.global_position
					if away.length_squared()<1: away=goal-ball
					ball_velocity=away.normalized()*230
			var old := ball
			var next := ball+ball_velocity*delta
			var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(ball,next,16))
			if hit.is_empty(): ball=next
			else: ball_velocity=ball_velocity.bounce(hit["normal"])*0.4
			ball_velocity=ball_velocity.move_toward(Vector2.ZERO,220*delta)
			if kind=="yarn": progress+=old.distance_to(ball)
			elif ball.distance_to(goal)<42: progress=1
			target=ball
		"boxes": _update_boxes(players)
		"beach_ball":
			bounce_clock-=delta
			if bounce_clock<=0:
				if not _near(players,target,55): return _finish(-1)
				progress+=1
				bounce_clock=4
				target=_open_destination(target,100)
		"race","marathon","laser":
			if _near(players,target,45):
				held+=delta
				if kind!="laser" or held>=1.0:
					progress+=1
					held=0
					if int(progress)<points.size(): target=points[int(progress)]
			else: held=0
		"chumper":
			for enemy in entities:
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
					if enemy.global_position.distance_to(goal)<25: goal=_open_destination(enemy.global_position,160)
					enemy.global_position=enemy.global_position.move_toward(goal,45*delta)
					target=enemy.global_position
		"horde","circle","linked","meteors","darkness":
			spawn_clock+=delta
			if spawn_clock>=1.5:
				spawn_clock=0
				for i in 3*players.size():
					var enemy = _spawn_enemy("fast_runner",_open_destination(origin,250))
					if is_instance_valid(enemy):
						enemy.set_meta("challenge_token",token)
						enemy.exp_drop=0 # Trial XP is paid once at completion.
						entities.append(enemy)
			if kind=="circle":
				var inside := true
				for p in players:
					if p.global_position.distance_to(origin)>170: inside=false
				if inside: progress+=delta
				else:
					held+=delta
					if held>3: return _finish(-1)
				if inside: held=0
			elif kind=="linked":
				var together := true
				for p in players:
					for other in players:
						if p.global_position.distance_to(other.global_position)>220: together=false
				if together: progress+=delta
				else:
					held+=delta
					if held>3: return _finish(-1)
				if together: held=0
			elif kind in ["meteors","darkness"]:
				progress+=delta
				if kind=="meteors": _update_meteors(delta,players)
				elif is_instance_valid(darkness):
					darkness.size=get_viewport_rect().size
					var centers := PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
					for i in mini(4,players.size()): centers[i]=get_viewport().get_canvas_transform()*players[i].global_position
					darkness.material.set_shader_parameter("centers",centers)
					darkness.material.set_shader_parameter("count",mini(4,players.size()))
	if progress>=required: return _finish(1)
	if remaining<=0: return _finish(-1)
	queue_redraw()
	return 0

func _near(players: Array, at: Vector2, radius: float) -> bool:
	for p in players:
		if p.global_position.distance_to(at)<=radius: return true
	return false

func _update_meteors(delta: float, players: Array) -> void:
	for i in range(hazards.size()-1,-1,-1):
		hazards[i]["time"]-=delta
		if float(hazards[i]["time"])<=0:
			for p in players:
				if p.global_position.distance_to(hazards[i]["position"])<65:
					DamageSystem.apply_damage({},p,150,false,null,"magic")
			hazards.remove_at(i)
	if int((elapsed-delta)/1.2)!=int(elapsed/1.2):
		for p in players: hazards.append({"position":p.global_position,"time":0.9})

func _update_boxes(players: Array) -> void:
	for id in carried.keys():
		var carrier = instance_from_id(id)
		if not is_instance_valid(carrier) or carrier.is_downed:
			points.append(_safe(carrier.global_position if is_instance_valid(carrier) else origin))
			if is_instance_valid(carrier):
				carrier.temp_buffs.erase("yuumi_box")
				carrier.recalculate_stats()
			carried.erase(id)
	for p in players:
		var id: int = p.get_instance_id()
		if carried.has(id):
			if p.global_position.distance_to(goal)<50:
				carried.erase(id)
				p.temp_buffs.erase("yuumi_box")
				p.recalculate_stats()
				progress+=1
			continue
		for i in range(points.size()-1,-1,-1):
			if p.global_position.distance_to(points[i])<35:
				points.remove_at(i)
				carried[id]=true
				p.apply_temporary_buff("yuumi_box",remaining+2,{"speed_pct":-0.25})
				break
	target=goal if not carried.is_empty() or points.is_empty() else points[0]

func record_kill(victim: Node2D) -> void:
	if result!=0 or not is_instance_valid(victim) or victim.get_meta("challenge_token","")!=token: return
	var id := victim.get_instance_id()
	if accounted.has(id): return
	accounted[id]=true
	if kind in ["horde","miniboss","chumper"]: progress+=1

func _vase_destroyed() -> void:
	if result==0: progress+=1

func _finish(outcome: int) -> int:
	result=outcome
	return result

func cleanup() -> void:
	for p in GameManager.active_player_nodes:
		if is_instance_valid(p) and p.temp_buffs.has("yuumi_box"):
			p.temp_buffs.erase("yuumi_box")
			p.recalculate_stats()
	for enemy in entities:
		if is_instance_valid(enemy) and enemy is Enemy and not enemy.is_queued_for_deletion():
			# No reward on cleanup. Never leave challenge-only enemies behind.
			enemy.queue_free()

func description() -> String:
	var details := "%d/%d" % [int(progress),int(required)]
	if kind=="football": details="Ball ins goldene Tor schieben"
	elif kind=="boxes": details="%d/5 abgeliefert · Kiste aufnehmen, zum goldenen Ziel" % int(progress)
	elif kind=="beach_ball": details="%d/6 · unter den Landekreis! %.1fs" % [int(progress),maxf(0,bounce_clock)]
	elif kind=="circle": details="%.0f/30s · im Kreis bleiben" % progress
	elif kind=="linked": details="%.0f/30s · zusammenbleiben" % progress
	var title: String = {"meteors":"Bel’Veth: Meteoren ausweichen","darkness":"Bel’Veth: Im Dunkeln überleben"}.get(kind,TITLES.get(kind,kind))
	return "%s · %s · %.0fs" % [title,details,maxf(0,remaining)]

func _draw() -> void:
	var color := Color("ffe591")
	for hazard in hazards:
		var at: Vector2 = hazard["position"]
		draw_circle(at,65,Color("ff634d",0.14))
		draw_arc(at,65,0,TAU,48,Color("ff634d"),3,true)
		draw_circle(at,65*clampf(1-float(hazard["time"])/0.9,0,1),Color("ff9b59",0.3))
	if kind in ["football","yarn"]:
		draw_circle(ball,14,Color("f8eeee") if kind=="football" else Color("ee89c5"))
		for i in 5: draw_line(ball,ball+Vector2.from_angle(i*TAU/5)*10,Color("425869"),2,true)
		if kind=="football":
			draw_arc(goal,42,0,TAU,40,color,3,true)
			draw_rect(Rect2(goal-Vector2(36,28),Vector2(72,56)),Color(color,0.12))
	elif kind=="boxes":
		draw_arc(goal,50,0,TAU,40,color,3,true)
		for point in points:
			draw_rect(Rect2(point-Vector2(13,11),Vector2(26,22)),Color("b98b58"))
			draw_line(point+Vector2(0,-11),point+Vector2(0,11),color,2,true)
		for id in carried:
			var p = instance_from_id(id)
			if is_instance_valid(p): draw_rect(Rect2(p.global_position+Vector2(-12,-35),Vector2(24,20)),Color("b98b58"))
	elif kind=="beach_ball":
		draw_circle(target,55,Color("6be7ff",0.1))
		draw_arc(target,55,0,TAU,40,Color("6be7ff"),2,true)
		draw_arc(target,55,-PI/2,-PI/2+TAU*clampf(bounce_clock/4,0,1),40,color,3,true)
		var offset := Vector2(0,-sin(clampf(1-bounce_clock/4,0,1)*PI)*100)
		draw_circle(target+offset,15,Color("fff4ce"))
		draw_arc(target+offset,13,0,PI,16,Color("ff8a83"),6,true)
	elif kind in ["race","marathon","laser"]:
		draw_arc(target,40,0,TAU,32,Color("ff6ccf") if kind=="laser" else color,3,true)
		draw_line(target,target+Vector2(0,-42),color,3,true)
		draw_colored_polygon(PackedVector2Array([target+Vector2(0,-42),target+Vector2(25,-34),target+Vector2(0,-25)]),color)
	elif kind in ["circle","linked"]:
		draw_circle(origin,170,Color("d977f6",0.06))
		draw_arc(origin,170,0,TAU,64,Color("d977f6"),3,true)
		if kind=="linked":
			var players := _players()
			for i in range(1,players.size()): draw_line(players[0].global_position,players[i].global_position,Color("d977f6"),2,true)

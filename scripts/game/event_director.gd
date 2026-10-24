extends Node2D
class_name EventDirector

signal event_updated(text: String)
var next_event := 90.0
var serial := 0
var active: Dictionary = {}
var supply_pos := Vector2.INF
var message := ""
var _clock := 0.0
var boon_timer := 0.0
var pending_spires: Array[Dictionary] = []
var scheduled: Dictionary = {}
var challenge: Node2D
var supply_capture := 0.0

func _ready() -> void:
	GameManager.combat_event.connect(_on_combat)
	GameManager.boss_defeated.connect(func(_name): _advance_stories(true))

func _feature_enabled(feature: String) -> bool:
	for player in GameManager.active_player_nodes:
		if is_instance_valid(player) and SaveManager.load_profile(player.profile_id).get("features",[]).has(feature): return true
	return false

func _living_near(at: Vector2, radius: float) -> int:
	var count := 0
	for player in GameManager.active_player_nodes:
		if is_instance_valid(player) and not player.is_downed and player.global_position.distance_to(at)<radius: count+=1
	return count

func _schedule_events() -> void:
	var schedule: Dictionary = preload("res://scripts/game/warehouse_timeline.gd").reference_data()["event_schedule"]
	for type in schedule:
		for time in schedule[type]:
			var key := str(type)+":"+str(time)
			if GameManager.game_time<float(time) or scheduled.has(key): continue
			scheduled[key]=true
			if type=="mission" and not _feature_enabled("yuumi_quests"): continue
			if type=="trial" and (GameManager.selected_difficulty=="story" or not _feature_enabled("belveth_trials")): continue
			if type=="supply" and not _feature_enabled("boons_unlocked"): continue
			pending_spires.append({"type":type,"position":_event_position(type),"expires":minf(899,float(time)+110)})
	pending_spires=pending_spires.filter(func(spire): return float(spire["expires"])>GameManager.game_time)

func _process(delta: float) -> void:
	if GameManager.current_state!=GameManager.GameState.GAMEPLAY: return
	if GameManager.is_boss_active or GameManager.run_finalized:
		if not active.is_empty(): finish_event(false)
		pending_spires.clear()
		supply_pos=Vector2.INF
		message=""
		return
	if boon_timer>0: boon_timer-=delta
	_clock+=delta
	if _clock>=1:
		_clock=0
		_advance_stories(false)
	_schedule_events()
	if active.is_empty():
		for i in pending_spires.size():
			if _living_near(pending_spires[i]["position"],65)>0:
				var spire: Dictionary = pending_spires[i]
				pending_spires.remove_at(i)
				start_event(spire["type"],spire["position"])
				break
	if not active.is_empty():
		active["remaining"]-=delta
		if active.get("phase","")=="capture":
			var nearby := _living_near(active["position"],65)
			active["held"]=float(active["held"])+delta*nearby if nearby>0 else maxf(0,float(active["held"])-delta)
			message="%s aktivieren · %.0f%%" % ["Yuumi" if active["type"]=="mission" else ("Miss Fortune" if active["type"]=="supply" else "Bel’Veth"),100*float(active["held"])/3]
			if float(active["held"])>=3:
				if active["type"]=="supply":
					active.clear()
					grant_boon(FortuneBonusRegistry.get_all_bonus_ids().pick_random())
				else: _begin_challenge()
		elif is_instance_valid(challenge):
			var outcome: int = challenge.update(delta)
			active["position"]=challenge.target
			message=challenge.description()
			if outcome!=0: finish_event(outcome>0)
		if not active.is_empty() and float(active["remaining"])<=0: finish_event(false)
	elif not pending_spires.is_empty():
		message="Optionales Ereignis: Yuumi / Bel’Veth / Miss Fortune auf der Minimap"
	# Legacy supply position remains supported for other maps and saved test fixtures.
	if supply_pos.is_finite():
		supply_capture=supply_capture+delta*_living_near(supply_pos,55) if _living_near(supply_pos,55)>0 else 0.0
		if supply_capture>=3:
			supply_pos=Vector2.INF
			supply_capture=0
			grant_boon(FortuneBonusRegistry.get_all_bonus_ids().pick_random())
	queue_redraw()

func _event_position(kind: String) -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for player in GameManager.active_player_nodes:
		if is_instance_valid(player):
			center+=player.global_position
			count+=1
	center/=maxi(1,count)
	center+=Vector2(250,0)
	return get_parent().get_event_position(kind,center) if get_parent().has_method("get_event_position") else center.clamp(Vector2(-1400,-1400),Vector2(1400,1400))

func start_event(kind: String = "mission", at: Vector2 = Vector2.INF) -> void:
	if not active.is_empty() or GameManager.is_boss_active: return
	serial+=1
	var center := _event_position(kind) if not at.is_finite() else at
	active={"id":serial,"type":kind,"phase":"capture","position":center,"origin":center,"remaining":95.0,"held":0.0,"kills":0}

func _begin_challenge(variant: String = "") -> void:
	if active.is_empty(): return
	var kit = preload("res://scripts/game/swarm_challenge.gd")
	var pool: Array = kit.YUUMI if active["type"]=="mission" else kit.TRIALS
	var choice: String = pool.pick_random() if variant.is_empty() else variant
	active["phase"]="running"
	active["variant"]=choice
	challenge=kit.new()
	add_child(challenge)
	challenge.begin(self,choice,active["origin"])
	active["remaining"]=challenge.remaining+1

func finish_event(success: bool) -> void:
	if active.is_empty(): return
	if success and active.get("phase","")=="capture": return
	var event := active.duplicate()
	active.clear() # Reserve the reward before XP/selection callbacks.
	if is_instance_valid(challenge):
		challenge.cleanup()
		challenge.queue_free()
		challenge=null
	message="Ereignis geschafft!" if success else "Ereignis beendet – keine Belohnung."
	if not success: return
	if event["type"]=="trial":
		QuestManager.notify_event("trials_completed",1,true)
		if GameManager.selected_difficulty!="story": QuestManager.notify_event("trials_hard_count",1,true)
		DropManager.spawn_access_card(get_parent(),event["position"])
		var xp := GameManager.calculate_required_exp_for_level(GameManager.team_level)+GameManager.calculate_required_exp_for_level(GameManager.team_level+1)+2
		while xp>0:
			var amount := mini(20,xp)
			DropManager.spawn_exp_orb(get_parent(),event["position"]+Vector2.from_angle(randf()*TAU)*randf_range(15,60),amount)
			xp-=amount
		GameManager.team_gold_earned+=150
		message="Bel’Veth-Prüfung bestanden: XP, Gold und Zugangskarte!"
	elif event["type"]=="mission":
		if _feature_enabled("yuumi_quests"):
			GameManager.enqueue_selection("augment",GameManager.team_level)
			message="Yuumi-Aufgabe geschafft: Augment wählen!"
		else: message="Yuumi-Aufgabe geschafft: +50 Gold (Augments noch gesperrt)."
		GameManager.team_gold_earned+=50

func get_event_markers() -> Array[Dictionary]:
	var result: Array[Dictionary] = pending_spires.duplicate()
	if not active.is_empty(): result.append({"type":active["type"],"position":active["position"]})
	return result

func grant_boon(id: String) -> void:
	var data = FortuneBonusRegistry.get_bonus_data(id)
	if data.is_empty(): return
	message = "Hasi-Hyperschub: " + data["display_name"]
	for p in GameManager.active_player_nodes:
		if not is_instance_valid(p) or p.is_downed: continue
		var profile = SaveManager.load_profile(p.profile_id)
		if not profile.get("features",[]).has("boons_unlocked"):
			GameManager.team_gold_earned += 25
			p.heal(100)
			message = "Krawall-Karton: Gold und Heilung! Hasi-Boni nach 15 Minuten Überleben freigeschaltet."
			continue
		var duration = float(data["duration"]) * (1+0.25*int(profile.get("shop_upgrades",{}).get("boon_duration",0)))
		var stats: Dictionary = {}
		match id:
			"bonus_kart": stats = {"speed_pct":1.0}
			"bonus_gun": stats = {"ability_haste":60,"projectile_count":3}
			"bonus_cruise": stats = {"speed_pct":0.5,"projectile_count":4}
			"bonus_health_back":
				p.heal(p.get_stat("max_health"))
				p.grant_shield(300,duration)
			"bonus_rapid_fire": stats = {"rapid_fire":1}
		p.apply_temporary_buff(id,duration,stats)
	boon_timer = float(data["duration"])

func _on_combat(kind: String, payload: Dictionary) -> void:
	if kind == "kill" and not active.is_empty():
		active["kills"] += 1
		if is_instance_valid(challenge): challenge.record_kill(payload.get("target"))
	if kind == "card":
		for p in GameManager.active_player_nodes:
			if is_instance_valid(p): p.set_meta("cards",int(p.get_meta("cards",0))+1)
	if kind == "level_up":
		for p in GameManager.active_player_nodes:
			if is_instance_valid(p) and p.augments.has("augment_celebration"):
				p.apply_temporary_buff("celebration",8,{"damage_pct":0.5,"speed_pct":0.5,"area_pct":0.6,"ability_haste":50})

func _advance_stories(victory: bool) -> void:
	if GameManager.practice_mode: return
	var ids = ["jankz","seraföhn","löwina","yasüff","brioche","rübenrambo","auarora","xayaya"]
	var seen: Dictionary = {}
	for p in GameManager.active_player_nodes:
		if not is_instance_valid(p) or not ids.has(p.character_id) or seen.has(p.profile_id): continue
		seen[p.profile_id] = true
		var profile = SaveManager.load_profile(p.profile_id)
		var chapters: Dictionary = profile.get("story_chapters",{})
		var stage = int(chapters.get(p.character_id,0))
		var evolved = false
		for w in p.weapon_controller.equipped_weapons:
			if w.is_evolved: evolved = true
		var advance = (stage == 0 and GameManager.team_level>=10) or (stage == 1 and evolved) or (stage == 2 and victory)
		if advance:
			chapters[p.character_id] = stage+1
			profile["story_chapters"] = chapters
			SaveManager.cache_profile(profile)
			QuestManager.dirty_profiles[p.profile_id] = true
			if stage == 2: QuestManager.notify_event("story_event_"+str(ids.find(p.character_id)+1),1,false,{"profile_id":p.profile_id})

func _draw() -> void:
	for marker in get_event_markers():
		var at: Vector2 = marker["position"]
		var color := Color("ffe47c") if marker["type"]=="mission" else (Color("f3bd61") if marker["type"]=="supply" else Color("dc77ee"))
		draw_circle(at,45,Color(color,0.12))
		draw_arc(at,45,0,TAU,40,color,2,true)
		draw_line(at+Vector2(0,-20),at+Vector2(0,14),color,5,true)
		draw_string(ThemeDB.fallback_font,at+Vector2(-65,-55),"YUUMI" if marker["type"]=="mission" else ("MISS FORTUNE" if marker["type"]=="supply" else "BEL’VETH"),HORIZONTAL_ALIGNMENT_CENTER,130,14,color)

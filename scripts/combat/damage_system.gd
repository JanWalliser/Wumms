extends RefCounted
class_name DamageSystem

static var _numbers_alive := 0

static func apply_damage(stats: Dictionary, target: Node2D, raw: float, crit_allowed: bool = true, source: Node2D = null, kind: String = "physical", proc_depth: int = 0) -> Dictionary:
	var result = {"damage":0.0,"shield_damage":0.0,"is_crit":false,"killed":false}
	if not is_instance_valid(target) or target.is_queued_for_deletion() or raw <= 0: return result
	if target.has_method("is_invulnerable") and target.is_invulnerable(): return result
	if not target.has_method("receive_damage"): return result
	if is_instance_valid(source) and source.is_in_group("players") == target.is_in_group("players"): return result
	if target.get_meta("iceblast_armed",false) and target.has_meta("iceblast_weapon"):
		target.get_meta("iceblast_weapon").consume_iceblast()
		return result
	var amount = raw * float(stats.get("damage_multiplier",1.0))
	if GameManager.game_time<float(target.get_meta("gatling_vulnerability_until",-1.0)): amount*=1.15
	if is_instance_valid(source) and source.has_method("modify_outgoing_damage"):
		amount = source.modify_outgoing_damage(target,amount,proc_depth,str(stats.get("attack_id","frame:"+str(Engine.get_physics_frames()))))
	var critical = crit_allowed and randf() < float(stats.get("crit_chance",0.0))
	if not critical and is_instance_valid(source) and source.is_in_group("players") and source.augments.has("augment_mission_critical"): amount*=0.8
	if is_instance_valid(source) and source.is_in_group("players") and source.augments.has("augment_emotional_support") and stats.get("weapon_id","") in ["weapon_tibbers","weapon_yuumibot","weapon_transit"]: amount*=1.5
	if critical: amount *= float(stats.get("crit_damage",2.0))
	var armor = target.get_armor() if target.has_method("get_armor") else 0.0
	if kind != "true": amount = StatCalculator.calculate_armor_mitigation(amount,armor)
	amount = maxf(1.0,roundf(amount))
	var perf = Time.get_ticks_usec() if GameManager.profile_enabled else 0
	var before = target.current_health
	var remaining = amount
	if target.has_method("absorb_shield"):
		remaining = target.absorb_shield(amount)
		result["shield_damage"] = amount-remaining
	if remaining>0 and target.has_method("on_incoming_damage"): target.on_incoming_damage()
	if is_instance_valid(source):
		source.set_meta("proc_depth",proc_depth)
		source.set_meta("damage_weapon",stats.get("weapon_id",""))
	if remaining > 0: result["killed"] = target.receive_damage(remaining,critical,source)
	if is_instance_valid(source): source.set_meta("proc_depth",0)
	result["damage"] = minf(maxf(0,before),remaining)
	result["is_crit"] = critical
	result["status"] = stats.get("status","")
	if target.has_method("sync_health"):
		target.damage_grace = 0.12
		target.sync_health()
	if result["damage"] > 0:
		spawn_damage_number(target.global_position,result["damage"],critical)
		if is_instance_valid(source) and source.is_in_group("players"):
			GameManager.total_damage_dealt += result["damage"]
			if source.has_method("on_combat_hit"): source.on_combat_hit(target,result,proc_depth)
		GameManager.combat_event.emit("hit", {"target":target,"source":source,"result":result,"depth":proc_depth})
	if GameManager.profile_enabled: GameManager.profile_elapsed("damage",perf)
	return result

static func spawn_damage_number(pos: Vector2, amount: float, is_critical: bool, is_heal: bool = false) -> void:
	# Add slight jitter to avoid overlapping text
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene or _numbers_alive >= 80: return
	var jitter := Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 8.0))
	var label := Label.new()
	label.text = str(int(amount))
	label.top_level = true
	label.global_position = pos + jitter - Vector2(20, 30)
	label.z_index = 100

	var col := Color.WHITE
	var scale := Vector2.ONE
	if is_heal:
		col = Color(0.2, 0.95, 0.3)
		label.text = "+" + label.text
	elif is_critical:
		col = Color(1.0, 0.75, 0.1)
		scale = Vector2(1.4, 1.4)
		label.text = label.text + "!"
	else:
		col = Color(1.0, 0.9, 0.8)

	label.modulate = col
	label.scale = scale/preload("res://scripts/maps/world_projection.gd").ground_scale()

	if tree and tree.current_scene:
		tree.current_scene.add_child(label)
		label.add_to_group("damage_numbers")
		_numbers_alive += 1
		label.tree_exited.connect(_release_number)
		var tween := label.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "global_position:y", label.global_position.y - 45.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.3)
		tween.chain().tween_callback(label.queue_free)

static func _release_number() -> void:
	_numbers_alive = maxi(0,_numbers_alive-1)

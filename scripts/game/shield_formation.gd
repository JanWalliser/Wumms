extends Node2D

## Fixed ring, separate from the ordinary enemy budget and navigation grid.
const Soldier = preload("res://scripts/enemies/shield_soldier.gd")
var center := Vector2.ZERO
var radius := 260.0
var soldier_count := 60
var starts_at := 0.0
var expires_at := 0.0
var token := ""
var deployed := false
var slots: Array[Vector2] = []
var soldiers: Array[Enemy] = []
var contact_until: Dictionary = {}
const WARNING_TIME := 0.6
const CONTACT_INTERVAL := 0.65 # Project tuning, not a recovered server attack tick.
const COOP_PLACEMENT_STATUS := "Provisional shared living-team centre; exact original distant-player placement and ring count are not verified."

func begin(spawner: Node2D, wave: Dictionary) -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("shield_formations")
	token=GameManager.run_id
	# This policy is deliberately labelled provisional, not an original-game fact.
	var living := 0
	for player in GameManager.active_player_nodes:
		if not is_instance_valid(player) or player.is_downed: continue
		center+=player.global_position
		living+=1
	if living==0:
		queue_free()
		return
	center/=living
	radius=float(wave["WaveShape"]["radius"])*0.2
	soldier_count=int(wave["MaxSpawnCount"])
	starts_at=GameManager.game_time+WARNING_TIME
	expires_at=GameManager.game_time+35.0
	set_meta("reference_wave",wave["name"])
	# Never individually snap soldiers to safe positions: that distorts the ring.
	# Terrain occupies blocked slots itself; leave those exact slots empty.
	var map := spawner.get_parent()
	for index in soldier_count:
		var point := center+Vector2.from_angle(TAU*index/soldier_count)*radius
		if map.has_method("get_safe_position") and map.get_safe_position(point,18).distance_to(point)>0.1: continue
		slots.append(point)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if token!=GameManager.run_id or GameManager.run_finalized:
		queue_free()
		return
	if GameManager.current_state!=GameManager.GameState.GAMEPLAY: return
	if GameManager.game_time>=expires_at:
		# Despawn is not a kill: no XP, cards, kill procs or drops.
		for soldier in soldiers:
			if is_instance_valid(soldier): soldier.collision_layer=0
		queue_free()
		return
	if not deployed and GameManager.game_time>=starts_at:
		_deploy()
	if deployed: _contact_damage()
	queue_redraw()

func _deploy() -> void:
	deployed=true
	var scene := preload("res://scenes/enemies/enemy_base.tscn")
	var body_radius := maxf(10.0,2.0*radius*sin(PI/soldier_count)*0.52)
	for point in slots:
		var soldier: Enemy=scene.instantiate()
		soldier.set_script(Soldier)
		add_child(soldier)
		soldier.global_position=point
		soldier.inward=(center-point).normalized()
		soldier.set_meta("reference_character","Characters/Strawberry_Enemy_Shield/CharacterRecords/Root")
		soldier.set_meta("reference_wave",get_meta("reference_wave"))
		var body := CircleShape2D.new()
		body.radius=body_radius
		soldier.collision_shape.shape=body
		soldier.get_node("HitboxArea/CollisionShape2D").shape=body.duplicate()
		soldiers.append(soldier)

func _contact_damage() -> void:
	for player in GameManager.active_player_nodes:
		if not is_instance_valid(player) or player.is_downed: continue
		var id := player.get_instance_id()
		if GameManager.game_time<float(contact_until.get(id,0)): continue
		for soldier in soldiers:
			if not is_instance_valid(soldier) or soldier.is_queued_for_deletion() or soldier.death_started: continue
			var distance: float=player.get_node("CollisionShape2D").shape.radius+soldier.collision_shape.shape.radius+2.0
			if player.global_position.distance_squared_to(soldier.global_position)>distance*distance: continue
			# Shared per-player cooldown prevents adjacent soldiers multiplying one touch.
			contact_until[id]=GameManager.game_time+CONTACT_INTERVAL
			if not soldier.is_downed_check():
				DamageSystem.apply_damage({},player,soldier.contact_damage,false,soldier)
				soldier.visual_animator.attack(soldier.get("inward"))
			break

func _draw() -> void:
	if not deployed:
		for point in slots:
			draw_circle(to_local(point),12,Color(1,0.3,0.55,0.35))
		draw_arc(to_local(center),radius,0,TAU,100,Color(1,0.4,0.6,0.55),2,true)


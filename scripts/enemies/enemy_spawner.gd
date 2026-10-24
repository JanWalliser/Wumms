extends Node2D

# EnemySpawner - Wave progression timeline, offscreen ring spawning, and horde flowfield updates

class_name EnemySpawner

var flowfield: Flowfield = null
var spatial_hash: SpatialHash = null

var spatial_timer := 0.0
var miniboss_minute := 0
var spawn_timer: float = 0.0
var flowfield_timer: float = 0.0
var max_concurrent_enemies: int = 500

var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy_base.tscn")
var boss_scene: PackedScene = preload("res://scenes/enemies/boss_base.tscn")

var active_enemies: Array[Enemy] = []
var warehouse_timeline = preload("res://scripts/game/warehouse_timeline.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if GameManager.selected_map_id=="map_warehouse": max_concurrent_enemies=preload("res://scripts/game/warehouse_balance.gd").NORMAL_LIMIT
	flowfield = Flowfield.new(60, 60, 64.0, Vector2(-1920.0, -1920.0))
	spatial_hash = SpatialHash.new(70.0)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		return

	var warehouse := GameManager.selected_map_id=="map_warehouse"
	var minute = int(GameManager.game_time / 120.0)
	if not warehouse and minute > miniboss_minute and not GameManager.is_boss_active:
		miniboss_minute = minute
		_spawn_single_enemy("mini_boss", valid_spawn())
	spatial_timer += delta
	if spatial_timer >= 0.08:
		spatial_timer = 0
		spatial_hash.clear()
		for e in active_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion(): spatial_hash.insert(e)
	# Periodically rebuild spatial hash and flowfield
	flowfield_timer += delta
	if flowfield_timer >= 0.35:
		flowfield_timer = 0.0
		_update_horde_systems()

	# Wave spawning
	if warehouse:
		warehouse_timeline.tick(self,delta)
		return
	spawn_timer += delta
	var spawn_interval := _get_current_spawn_interval()
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_wave()

func _update_horde_systems() -> void:
	spatial_hash.clear()

	# Clean dead references
	var alive_enemies: Array[Enemy] = []
	for e in active_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			alive_enemies.append(e)
			spatial_hash.insert(e)
	active_enemies = alive_enemies

	# Update flowfield targets with living players
	var player_positions: Array[Vector2] = []
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and not p.is_downed:
			player_positions.append(p.global_position)

	if not player_positions.is_empty():
		flowfield.update_field(player_positions)
		if get_parent().has_method("update_additional_navigation"):
			get_parent().update_additional_navigation(player_positions)

func _get_current_spawn_interval() -> float:
	var t: float = GameManager.game_time
	var player_mult := 1.0 / float(GameManager.get_active_player_count())

	if GameManager.is_boss_active:
		return 3.0 * player_mult # Slower spawning during boss

	if t < 60.0:
		return 1.4 * player_mult
	elif t < 180.0:
		return 1.0 * player_mult
	elif t < 360.0:
		return 0.75 * player_mult
	elif t < 600.0:
		return 0.55 * player_mult
	elif t < 850.0:
		return 0.40 * player_mult
	else:
		return 0.30 * player_mult

func _spawn_wave() -> void:
	if active_enemies.size() >= max_concurrent_enemies:
		return

	var center := _get_players_center()
	var t: float = GameManager.game_time

	# Choose archetype based on timeline
	var archetype := "standard_grunt"
	var group_size := 2

	if t < 60.0:
		archetype = "standard_grunt"
		group_size = randi_range(2, 4)
	elif t < 180.0:
		archetype = "fast_runner" if randf() < 0.4 else "standard_grunt"
		group_size = randi_range(3, 6)
	elif t < 360.0:
		var roll := randf()
		if roll < 0.35:
			archetype = "heavy_tank"
		elif roll < 0.65:
			archetype = "ranged_spitter"
		else:
			archetype = "fast_runner"
		group_size = randi_range(4, 8)
	elif t < 600.0:
		var roll := randf()
		if roll < 0.25:
			archetype = "kamikaze_exploder"
		elif roll < 0.5:
			archetype = "aoe_bruiser"
		elif roll < 0.75:
			archetype = "support_buffer"
		else:
			archetype = "heavy_tank"
		group_size = randi_range(5, 10)
	else:
		var roll := randf()
		if roll < 0.15 and not GameManager.is_boss_active:
			archetype = "elite_variant"
			group_size = 1
		elif roll < 0.35:
			archetype = "kamikaze_exploder"
			group_size = randi_range(3, 6)
		else:
			archetype = "aoe_bruiser"
			group_size = randi_range(4, 8)

	# Spawn group in cluster offscreen
	var spawn_angle := randf() * TAU
	var spawn_dist := randf_range(850.0, 1150.0)
	var spawn_base = valid_spawn()
	if spawn_base == Vector2.INF: return

	for i in range(group_size):
		if active_enemies.size() >= max_concurrent_enemies:
			break
		var jitter := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		_spawn_single_enemy(archetype, spawn_base + jitter)

func spawn_enemy(e_id: String, pos: Vector2) -> void:
	if active_enemies.size() >= max_concurrent_enemies:
		return
	_spawn_single_enemy(e_id, safe_position(pos))

func spawn_divider_children(pos: Vector2, token: String) -> void:
	if token!=GameManager.run_id or GameManager.run_finalized: return
	for side in [-1,1]:
		if active_enemies.size()>=max_concurrent_enemies: return
		var child := _spawn_single_enemy("fast_runner",safe_position(pos+Vector2(side*25,0)))
		if is_instance_valid(child):
			child.exp_drop=0
			child.gold_drop=0
			child.max_health*=0.5
			child.current_health=child.max_health

func _spawn_single_enemy(e_id: String, pos: Vector2, reserve: int = 0) -> Enemy:
	if active_enemies.size()>=max_concurrent_enemies+clampi(reserve,0,preload("res://scripts/game/warehouse_balance.gd").SPECIAL_RESERVE): return null
	if not pos.is_finite(): return null
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	var cell = flowfield.world_to_grid(pos)
	if flowfield.is_blocked(cell.x,cell.y):
		enemy.free()
		return null
	get_parent().add_child(enemy)
	enemy.setup(e_id, flowfield, spatial_hash)
	if GameManager.selected_map_id=="map_warehouse" and not enemy.is_elite and not enemy.is_boss:
		enemy.set_meta("warehouse_normal_xp_scale",1.0/GameManager.get_warehouse_density())
	if is_in_view(pos):
		# Whole-arena zoom has no offscreen location: announce the entrance before it can attack.
		enemy.apply_status_effect("freeze",1.0)
		enemy.apply_status_effect("invulnerable",1.0)
		RuntimeEffect.spawn(get_parent(),enemy,pos,{"radius":65,"damage":0,"duration":0.3})
	active_enemies.append(enemy)
	return enemy

func spawn_boss(boss_id: String, pos: Vector2) -> BossController:
	var boss: BossController = boss_scene.instantiate()
	boss.global_position = safe_position(pos)
	get_parent().add_child(boss)
	var navigation := flowfield
	if get_parent().has_method("get_navigation_field"):
		navigation = get_parent().get_navigation_field(true)
	boss.setup(boss_id, navigation, spatial_hash)
	boss.apply_status_effect("freeze",1.5)
	boss.apply_status_effect("invulnerable",1.5)
	active_enemies.append(boss)
	return boss

func _get_players_center() -> Vector2:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var count := 0
	for p in players:
		if is_instance_valid(p) and not p.is_downed and not p.is_queued_for_deletion():
			sum += p.global_position
			count += 1
	return sum / float(maxi(1, count))

func valid_spawn() -> Vector2:
	var cam = get_viewport().get_camera_2d()
	var center = cam.global_position if cam else _get_players_center()
	var half = get_viewport_rect().size / (cam.zoom if cam else Vector2.ONE) * 0.5
	for attempt in range(80):
		var direction = Vector2.from_angle(randf()*TAU)
		var distance = minf(half.x/maxf(0.001,absf(direction.x)),half.y/maxf(0.001,absf(direction.y)))+120
		var point = center + direction*distance
		if absf(point.x) > 1780 or absf(point.y) > 1780: continue
		var cell = flowfield.world_to_grid(point)
		if not flowfield.is_blocked(cell.x,cell.y): return point
	# When the camera shows the complete arena, use a distant announced entrance.
	for attempt in range(80):
		var point = Vector2(randf_range(-1750,1750),randf_range(-1750,1750))
		var cell = flowfield.world_to_grid(point)
		if flowfield.is_blocked(cell.x,cell.y): continue
		var safe = true
		for p in GameManager.active_player_nodes:
			if is_instance_valid(p) and point.distance_to(p.global_position)<650: safe = false
		if safe: return point
	return Vector2.INF

func is_in_view(point: Vector2) -> bool:
	var camera = get_viewport().get_camera_2d()
	if not camera: return false
	var half = get_viewport_rect().size/camera.zoom*0.5
	return Rect2(camera.global_position-half,half*2).has_point(point)

func safe_position(point: Vector2) -> Vector2:
	if get_parent().has_method("get_safe_position"):
		return get_parent().get_safe_position(point, 55.0)
	point = point.clamp(Vector2(-1700,-1700),Vector2(1700,1700))
	for radius in range(0,512,64):
		for i in range(8):
			var candidate = (point+Vector2.from_angle(TAU*i/8)*radius).clamp(Vector2(-1700,-1700),Vector2(1700,1700))
			var cell = flowfield.world_to_grid(candidate)
			if not flowfield.is_blocked(cell.x,cell.y): return candidate
	return Vector2.ZERO

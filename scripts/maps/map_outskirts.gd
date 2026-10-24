extends MapBase

# Map 2: Außen-Kekse (The Outskirts)
# Feature: Ionen-Irrsinn (Ion Cannon) & Böller-Batterie (Fuel Cells)

var carrier: Node2D
var cannon_pos: Vector2 = Vector2(0, 0)
var cannon_radius: float = 130.0
var cannon_active_timer: float = 0.0
var strike_timer: float = 0.0
var battery_spawn_timer: float = 0.0
var active_battery_pos: Vector2 = Vector2(250, 250)
var has_battery_spawned: bool = false

func _ready() -> void:
	map_id = "map_outskirts"
	boss_id = "boss_briar"
	super._ready()
	_spawn_battery()

func _process(delta: float) -> void:
	# Battery respawn loop
	if not has_battery_spawned and not is_instance_valid(carrier) and cannon_active_timer <= 0.0:
		battery_spawn_timer += delta
		if battery_spawn_timer >= 20.0:
			battery_spawn_timer = 0.0
			_spawn_battery()

	# Check player collecting battery and delivering to cannon
	if has_battery_spawned:
		var players := get_tree().get_nodes_in_group("players")
		for p in players:
			if is_instance_valid(p) and not p.is_downed:
				if p.global_position.distance_to(active_battery_pos) <= 50.0:
					has_battery_spawned = false
					carrier = p
					break

	if is_instance_valid(carrier):
		active_battery_pos = carrier.global_position
		if carrier.is_downed:
			has_battery_spawned = true
			carrier = null
		elif carrier.global_position.distance_to(cannon_pos)<=cannon_radius:
			carrier = null
			_activate_cannon()
	# Cannon firing loop
	if cannon_active_timer > 0.0:
		cannon_active_timer -= delta
		strike_timer += delta
		if strike_timer >= 1.2:
			strike_timer = 0.0
			_fire_orbital_strike()

	queue_redraw()

func _spawn_battery() -> void:
	has_battery_spawned = true
	var angle := randf() * TAU
	active_battery_pos = cannon_pos + Vector2.from_angle(angle) * randf_range(300.0, 500.0)

func _activate_cannon() -> void:
	cannon_active_timer = 30.0
	AudioManager.play_sfx("evolve", 1.3)

func _fire_orbital_strike() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var raw_target = enemies.pick_random()
	if not is_instance_valid(raw_target) or not (raw_target is Node2D):
		return
	var target: Node2D = raw_target
	var target_pos: Vector2 = target.global_position
	AudioManager.play_sfx("explosion", 1.5)
	DamageSystem.spawn_damage_number(target_pos, 450.0, true)
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(target_pos) <= 160.0:
			e.take_hit(450.0, true, null)

func _draw() -> void:
	draw_string(ThemeDB.fallback_font,cannon_pos+Vector2(-140,-160),"Ionen-Irrsinn: %.0fs" % cannon_active_timer if cannon_active_timer>0 else "Batterie aufnehmen und hier abgeben",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
	# Draw Ion Cannon platform
	var pad_col := Color(0.2, 0.7, 1.0, 0.35)
	if cannon_active_timer > 0.0:
		pad_col = Color(0.2, 0.9, 1.0, 0.6 + sin(Time.get_ticks_msec() * 0.01) * 0.2)
	draw_circle(cannon_pos, cannon_radius, pad_col)
	draw_arc(cannon_pos, cannon_radius, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.9), 3.0)

	# Draw Battery icon on ground if present
	if has_battery_spawned or is_instance_valid(carrier):
		draw_circle(active_battery_pos, 20.0, Color(1.0, 0.8, 0.1, 0.8))
		draw_arc(active_battery_pos, 22.0, 0, TAU, 16, Color.WHITE, 2.0)

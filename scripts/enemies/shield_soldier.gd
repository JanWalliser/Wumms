extends Enemy

## Stationary, destructible ring segment. The body blocks players (layer 6),
## while ordinary monsters ignore that layer and projectiles still hit layer 2.
var inward := Vector2.RIGHT

func _setup_from_registry() -> void:
	enemy_id="heavy_tank"
	super._setup_from_registry()
	enemy_id="shield_soldier"
	var multipliers := GameManager.get_difficulty_multipliers()
	var scaling := GameManager.get_enemy_time_multipliers()
	max_health=750.0*float(multipliers.get("enemy_hp",1.0))*GameManager.get_player_count_hp_multiplier(enemy_id)*scaling.x
	current_health=max_health
	armor=0
	contact_damage=200.0*float(multipliers.get("phys_dmg",1.0))*scaling.y
	move_speed=0
	exp_drop=1 # Explicit clone reward tuning; server-side original drops are unknown.
	gold_drop=0
	collision_layer=2|32
	collision_mask=0
	if sprite: sprite.modulate=Color(0.8,0.87,1.1)

func _physics_process(delta: float) -> void:
	if GameManager.current_state!=GameManager.GameState.GAMEPLAY: return
	if status_effects: status_effects.update(delta)
	velocity=Vector2.ZERO
	knockback_velocity=Vector2.ZERO
	visual_animator.update(delta,false,inward,is_downed_check())

func apply_knockback(_force: Vector2) -> void:
	pass

func _die(killer: Node2D = null) -> void:
	# Open the hole immediately; the node itself is retired at the frame boundary.
	collision_layer=0
	super._die(killer)

func _draw() -> void:
	# A finished metal shield silhouette distinguishes these sentries from walkers.
	var at := Vector2(0,-8)
	var points := PackedVector2Array([Vector2(-12,-13),Vector2(0,-18),Vector2(12,-13),Vector2(10,7),Vector2(0,15),Vector2(-10,7)])
	for i in points.size(): points[i]+=at
	draw_colored_polygon(points,Color("182839"))
	var inset := PackedVector2Array()
	for point in points: inset.append(at+(point-at)*0.83)
	draw_colored_polygon(inset,Color("637a96"))
	draw_line(at+Vector2(0,-14),at+Vector2(0,10),Color("df69bb"),3,true)
	draw_line(at+Vector2(-7,-9),at+Vector2(-8,3),Color("b8d6ec"),2,true)


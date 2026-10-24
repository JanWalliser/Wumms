extends MapBase

const DistrictLayout = preload("res://scripts/maps/warehouse_layout.gd")
const DistrictArt = preload("res://scripts/maps/warehouse_art.gd")

# Map 1: Warenhaus-Wahnsinn (Warehouse District)
# Feature: Heiliger Ketchupbrunnen (Healing Fountain)

var fountain_charge: float = 0.0
var fountain_cooldown: float = 0.0
var fountain_pos: Vector2 = Vector2.ZERO
var fountain_radius: float = 215.0
var layout: DistrictLayout
var district_art: DistrictArt
var boss_flowfield: Flowfield
var presentation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/warehouse/presentation.json"))
var minimap_texture: Texture2D = preload("res://assets/maps/warehouse/minimap.res")

@onready var fountain_marker: Marker2D = $FountainMarker

func _ready() -> void:
	map_id = "map_warehouse"
	boss_id = "boss_reksai"
	layout = DistrictLayout.new()
	fountain_pos = layout.locator("Fountain")
	fountain_marker.position = fountain_pos
	_build_original_obstacles()
	district_art = DistrictArt.new()
	district_art.name = "WarehouseDistrictArt"
	add_child(district_art)
	district_art.build(layout)
	super._ready()
	camera.position = layout.locator("__Spawn_T1")
	_place_supply_crates()

func _build_original_obstacles() -> void:
	for wall in layout.walls:
		var body := StaticBody2D.new()
		body.name = str(wall["id"])
		body.collision_layer = 16
		body.collision_mask = 3
		body.set_meta("source_region", wall["number"])
		var shape := CollisionPolygon2D.new()
		shape.name = "CollisionPolygon2D"
		shape.polygon = wall["polygon"]
		body.add_child(shape)
		obstacles_container.add_child(body)

func get_player_spawn_position(_slot: int, offset: Vector2) -> Vector2:
	return layout.nearest_clear(layout.locator("__Spawn_T1") + offset*get_actor_scale(), 28.0*get_actor_scale())

func get_actor_scale() -> float:
	return float(presentation["actor_scale"])

func get_ground_projection() -> float:
	return float(presentation.get("ground_projection_y",0.72))

func get_player_movement_scale() -> float:
	return float(presentation.get("player_movement_scale", 1.0))

func get_enemy_visual_scale() -> float:
	return float(presentation.get("enemy_visual_scale",1.0))

func _bake_obstacles_to_flowfield() -> void:
	# A grid cell is traversable only if its entire area plus body radius is clear.
	# Thin banks and diagonal plant corners must not disappear between grid centers.
	spawner.flowfield = Flowfield.new(120, 120, 32.0, Vector2(-1920,-1920))
	boss_flowfield = Flowfield.new(120, 120, 32.0, Vector2(-1920,-1920))
	for y in 120:
		for x in 120:
			var point := spawner.flowfield.grid_to_world(Vector2i(x,y))
			spawner.flowfield.set_blocked(x, y, not layout.is_clear(point, 18.0*get_actor_scale() + 24.0))
			# Boss phase two grows its radius from 48 to 62.4 units.
			boss_flowfield.set_blocked(x, y, not layout.is_clear(point, 64.0*get_actor_scale() + 24.0))
	spawner._update_horde_systems()

func get_navigation_field(for_boss: bool = false) -> Flowfield:
	return boss_flowfield if for_boss else spawner.flowfield

func update_additional_navigation(positions: Array[Vector2]) -> void:
	if boss_flowfield and GameManager.is_boss_active:
		boss_flowfield.update_field(positions)

func get_world_bounds() -> Rect2:
	return DistrictLayout.BOUNDS

func get_safe_position(point: Vector2, radius: float = 28.0) -> Vector2:
	if layout.is_clear(point, radius):
		return point
	return layout.nearest_clear(point, radius)

func get_event_position(kind: String, near: Vector2) -> Vector2:
	var candidates: Array[Vector2] = []
	var category := "quest_candidate" if kind == "mission" else "trial_candidate" if kind == "trial" else "spire_candidate"
	var clearance := 190.0 if kind == "mission" else 65.0
	for locator in layout.locators:
		if locator["category"] != category:
			continue
		var point: Vector2 = locator["position"]
		var cell := spawner.flowfield.world_to_grid(point)
		if layout.is_clear(point, clearance) and spawner.flowfield.cost_field[cell.y*120+cell.x] < Flowfield.INFINITE_COST:
			candidates.append(point)
	if candidates.is_empty():
		return layout.nearest_clear(near, clearance)
	candidates.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(near)<b.distance_squared_to(near))
	return candidates[randi_range(0,mini(3,candidates.size()-1))]

func _place_supply_crates() -> void:
	var crate_scene: PackedScene = preload("res://scenes/combat/loot_crate.tscn")
	var placed := 0
	for locator in layout.locators:
		if locator["category"] != "pod_candidate" or not layout.is_clear(locator["position"], 34.0):
			continue
		# Only a subset of locator candidates becomes a crate in any one run.
		if posmod(hash(locator["id"]), 4) != 0:
			continue
		var crate := crate_scene.instantiate()
		crate.position = locator["position"]
		pickups_container.add_child(crate)
		# Destructible props must not create untracked, permanent navigation blockers.
		crate.collision_layer = 2
		placed += 1
		if placed >= 14:
			break

func _on_boss_spawned(_boss_name: String) -> void:
	var position_boss := layout.nearest_clear(layout.locator("Locator_RekSaiSpawnPoint"), 80.0)
	var targets: Array[Vector2] = []
	for player in GameManager.active_player_nodes:
		if is_instance_valid(player) and not player.is_downed:
			targets.append(player.global_position)
	boss_flowfield.update_field(targets)
	GameManager.register_boss(spawner.spawn_boss(boss_id, position_boss))

func _process(delta: float) -> void:
	# Always queue redraw so the cooldown timer and visuals update every frame
	queue_redraw()

	if fountain_cooldown > 0.0:
		fountain_cooldown = maxf(0.0, fountain_cooldown - delta)
		return

	# Check players standing in the fountain area
	var players_inside := 0
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and not p.is_downed:
			if p.global_position.distance_to(fountain_pos) <= fountain_radius:
				players_inside += 1

	if players_inside > 0:
		# Charging speed scales with player count (25% per second per player)
		fountain_charge += (25.0 * players_inside) * delta
		if fountain_charge >= 100.0:
			_activate_fountain()
	else:
		fountain_charge = maxf(0.0, fountain_charge - 15.0 * delta)

func _activate_fountain() -> void:
	QuestManager.notify_event("fountain_activated",1,true)
	fountain_charge = 0.0
	fountain_cooldown = 60.0
	AudioManager.play_sfx("heal", 1.2)
	DamageSystem.spawn_damage_number(fountain_pos, 0, false, true)

	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and not p.is_downed:
			var max_hp: float = float(p.get_stat("max_health", 500.0))
			p.heal(max_hp * 0.5)

func _draw() -> void:
	# Only the local gameplay indicator redraws. Ground, buildings and foliage are static.
	var color := Color(0.20, 0.96, 0.79, 0.7)
	var progress := fountain_charge / 100.0
	if fountain_cooldown > 0:
		color = Color(0.52, 0.71, 0.74, 0.55)
		progress = 1.0-fountain_cooldown/60.0
	draw_arc(fountain_pos, fountain_radius, 0, TAU, 80, Color(color,0.22), 2.0, true)
	if progress > 0.001:
		draw_arc(fountain_pos, fountain_radius, -PI*0.5, -PI*0.5+progress*TAU, 80, color, 4.0, true)
	var near := false
	for player in GameManager.active_player_nodes:
		if is_instance_valid(player) and player.global_position.distance_to(fountain_pos)<fountain_radius+100:
			near = true
	if near:
		var text := "Brunnen · %.0fs" % fountain_cooldown if fountain_cooldown>0 else "Brunnen · %.0f%%" % fountain_charge
		var canvas_scale := get_global_transform_with_canvas().get_scale().abs()
		draw_set_transform(fountain_pos+Vector2(0,fountain_radius+28),0,Vector2.ONE/canvas_scale)
		draw_string_outline(ThemeDB.fallback_font,Vector2(-70,0),text,HORIZONTAL_ALIGNMENT_CENTER,140,14,3,Color("153340"))
		draw_string(ThemeDB.fallback_font,Vector2(-70,0),text,HORIZONTAL_ALIGNMENT_CENTER,140,14,Color("b7fff0"))
		draw_set_transform(Vector2.ZERO)


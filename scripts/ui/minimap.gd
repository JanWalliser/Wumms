extends Control
class_name Minimap

# Minimap - Dynamic radar and navigation minimap showing district geometry,
# player positions, fountain status, active events, and boss location.

const WORLD_BOUNDS := 1920.0 # -1920 to 1920
var map_rect := Rect2(8, 8, 144, 144)

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func world_to_map(world_pos: Vector2) -> Vector2:
	var bounds := Rect2(-WORLD_BOUNDS,-WORLD_BOUNDS,WORLD_BOUNDS*2,WORLD_BOUNDS*2)
	if is_instance_valid(GameManager.current_map) and GameManager.current_map.has_method("get_world_bounds"):
		bounds = GameManager.current_map.get_world_bounds()
	var norm_x := (world_pos.x-bounds.position.x)/bounds.size.x
	var norm_y := (world_pos.y-bounds.position.y)/bounds.size.y
	return Vector2(
		map_rect.position.x + clampf(norm_x, 0.0, 1.0) * map_rect.size.x,
		map_rect.position.y + clampf(norm_y, 0.0, 1.0) * map_rect.size.y
	)

func get_access_card_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for card in get_tree().get_nodes_in_group("access_cards"):
		if is_instance_valid(card) and not card.collected and not card.is_queued_for_deletion():
			result.append(card.global_position)
	return result

func get_threat_markers() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for enemy in get_tree().get_nodes_in_group("minimap_threats"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.death_started and enemy.current_health>0:
			result.append(enemy.global_position)
	return result

func _draw_threat(at: Vector2) -> void:
	var s := marker_scale()
	var triangle := PackedVector2Array([at+Vector2(0,-8)*s,at+Vector2(8,6)*s,at+Vector2(-8,6)*s])
	draw_colored_polygon(triangle,Color("dc3a4f"))
	draw_polyline(PackedVector2Array([triangle[0],triangle[1],triangle[2],triangle[0]]),Color("ffdc90"),1.2,true)
	draw_line(at+Vector2(0,-3)*s,at+Vector2(0,1)*s,Color.WHITE,2*s,true)
	draw_circle(at+Vector2(0,3.5)*s,s,Color.WHITE)

func marker_scale() -> float:
	return clampf(map_rect.size.x/184.0,0.8,1.9)

func view_outline() -> PackedVector2Array:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var viewport_size := get_viewport_rect().size
	var points := PackedVector2Array()
	for corner in [Vector2.ZERO,Vector2(viewport_size.x,0),viewport_size,Vector2(0,viewport_size.y),Vector2.ZERO]:
		points.append(world_to_map(inverse*corner))
	return points

func _draw() -> void:
	if size.x>=160 and size.y>=160: map_rect = Rect2(Vector2(8,8),size-Vector2(16,16))
	var s := marker_scale()
	# 1. Background radar panel
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.08, 0.1, 0.13, 0.85))
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.25, 0.35, 0.45, 0.9), false, 2.0)

	# Compass / district label
	draw_string(ThemeDB.fallback_font, Vector2(12, 18), "KARTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.8, 0.9, 0.8))

	# 2. Draw static obstacles from current map
	var map_obj = GameManager.current_map
	var has_original_minimap: bool = is_instance_valid(map_obj) and "minimap_texture" in map_obj
	if has_original_minimap:
		draw_texture_rect(map_obj.minimap_texture,map_rect,false)
	if is_instance_valid(map_obj): draw_polyline(view_outline(),Color(1,1,1,0.75),1.2,true)
	if is_instance_valid(map_obj) and map_obj.obstacles_container and not has_original_minimap:
		for child in GameManager.current_map.obstacles_container.get_children():
			if not (child is StaticBody2D):
				continue
			var col: CollisionShape2D = child.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col and col.shape:
				var m_pos := world_to_map(child.global_position)
				if col.shape is RectangleShape2D:
					var rect_shape: RectangleShape2D = col.shape as RectangleShape2D
					var r_size: Vector2 = rect_shape.size * (map_rect.size.x / (WORLD_BOUNDS * 2.0))
					draw_rect(Rect2(m_pos - r_size * 0.5, r_size), Color(0.28, 0.35, 0.45, 0.75))
				elif col.shape is CircleShape2D:
					var circle_shape: CircleShape2D = col.shape as CircleShape2D
					var rad: float = circle_shape.radius * (map_rect.size.x / (WORLD_BOUNDS * 2.0))
					draw_circle(m_pos, maxf(2.0, rad), Color(0.3, 0.38, 0.48, 0.75))

	# 3. Draw Heiliger Ketchupbrunnen (Healing Fountain)
	var fountain_pos: Vector2 = map_obj.fountain_pos if is_instance_valid(map_obj) and "fountain_pos" in map_obj else Vector2(0,150)
	var fountain_m := world_to_map(fountain_pos)
	var f_color := Color("73d57b")
	if map_obj and "fountain_cooldown" in map_obj and map_obj.fountain_cooldown > 0:
		f_color = Color(0.5, 0.5, 0.55)
	draw_circle(fountain_m, 5.0*s, Color("10251e"))
	draw_arc(fountain_m, 6.0*s, 0, TAU, 16, f_color, 1.0)
	draw_line(fountain_m-Vector2(3,0)*s,fountain_m+Vector2(3,0)*s,f_color,1.8*s,true)
	draw_line(fountain_m-Vector2(0,3)*s,fountain_m+Vector2(0,3)*s,f_color,1.8*s,true)

	# Optional spires and the current task remain visible simultaneously.
	if map_obj:
		var director = map_obj.get_node_or_null("EventDirector")
		if director:
			for marker in director.get_event_markers():
				var at := world_to_map(marker["position"])
				var color := Color("ffe47c") if marker["type"]=="mission" else (Color("f3bd61") if marker["type"]=="supply" else Color("dc77ee"))
				draw_circle(at,5*s,color)
				draw_arc(at,7.5*s,0,TAU,16,Color.WHITE,1.5)
			if director.supply_pos.is_finite():
				var at := world_to_map(director.supply_pos)
				draw_rect(Rect2(at-Vector2(4,4)*s,Vector2(8,8)*s),Color("f3bd61"))

	# Elites and intermediate bosses are visible from spawn, including offscreen ones.
	for position_enemy in get_threat_markers():
		var at := world_to_map(position_enemy)
		at=at.clamp(map_rect.position+Vector2.ONE*8*s,map_rect.end-Vector2.ONE*8*s)
		_draw_threat(at)

	# 6. Draw Living Players
	# Dropped upgrade cards remain marked until collection, including offscreen ones.
	for position_card in get_access_card_positions():
		var marker := world_to_map(position_card)
		draw_circle(marker,9.0*s,Color(1.0,0.82,0.15,0.25))
		var icon_rect := Rect2(marker-Vector2(4,5)*s,Vector2(8,10)*s)
		draw_rect(icon_rect,Color("221d36"))
		draw_rect(icon_rect,Color("ffdb64"),false,1.5)
		draw_line(marker+Vector2(-2,2)*s,marker+Vector2(0,-1)*s,Color("fff5bd"),1.5,true)
		draw_line(marker+Vector2(0,-1)*s,marker+Vector2(2,2)*s,Color("fff5bd"),1.5,true)

	for p in GameManager.active_player_nodes:
		if is_instance_valid(p) and not p.is_downed:
			var p_pos := world_to_map(p.global_position)
			var p_col: Color = ProfileManager.DEFAULT_PLAYER_COLORS[p.player_slot_index % 4]
			draw_circle(p_pos, 4.0*s, p_col)
			draw_arc(p_pos, 5.5*s, 0, TAU, 12, Color.WHITE, 1.2)
		elif is_instance_valid(p) and p.is_downed:
			var p_pos := world_to_map(p.global_position)
			draw_rect(Rect2(p_pos - Vector2(3, 3)*s, Vector2(6, 6)*s), Color(0.6, 0.6, 0.6))

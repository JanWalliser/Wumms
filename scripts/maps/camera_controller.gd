extends Camera2D
class_name CameraController

@export var min_zoom: float = 0.24
@export var max_zoom: float = 1.15
@export var margin: float = 64.0 # Screen pixels, independent of zoom.
@export var smooth_speed: float = 6.0

func get_playfield_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var hud = get_tree().get_first_node_in_group("game_hud")
	if is_instance_valid(hud) and hud.has_method("get_playfield_rect"):
		return hud.get_playfield_rect(viewport_size)
	return Rect2(Vector2.ZERO,viewport_size)

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	var rect := Rect2()
	var found := false
	for player in players:
		if not is_instance_valid(player): continue
		if not found:
			rect = Rect2(player.global_position,Vector2.ZERO)
			found = true
		else:
			rect = rect.expand(player.global_position)
	if not found: return
	var safe := get_playfield_rect()
	var padding := minf(margin,minf(safe.size.x,safe.size.y)*0.20)
	var available := safe.size-Vector2.ONE*padding*2
	var projection := preload("res://scripts/maps/world_projection.gd").ground_scale()
	var fit := minf(available.x/maxf(rect.size.x,1),available.y/maxf(rect.size.y*projection.y,1))
	# The normal minimum is soft: a separated team must still fit above the HUD.
	var target_zoom := minf(max_zoom,maxf(0.01,fit))
	var scalar_zoom := target_zoom if target_zoom<zoom.x else lerpf(zoom.x,target_zoom,clampf(smooth_speed*delta,0,1))
	zoom=projection*scalar_zoom
	var viewport_center := get_viewport_rect().size*0.5
	var composition_center := Vector2(viewport_center.x,get_viewport_rect().size.y*0.52)
	composition_center=composition_center.clamp(safe.position+Vector2.ONE*padding,safe.end-Vector2.ONE*padding)
	var target_center := rect.get_center()-(composition_center-viewport_center)/zoom
	var candidate := global_position.lerp(target_center,clampf(smooth_speed*delta,0,1))
	# No fixed +/-1400 clamp: players at the coast need the camera to follow
	# farther down. Clamp to the ACTUAL visible playfield after smoothing instead.
	var minimum_center := rect.end-(safe.end-viewport_center-Vector2.ONE*padding)/zoom
	var maximum_center := rect.position-(safe.position-viewport_center+Vector2.ONE*padding)/zoom
	global_position = candidate.clamp(minimum_center,maximum_center)

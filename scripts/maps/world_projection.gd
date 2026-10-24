extends RefCounted

# Orthographic 2.5D presentation. Simulation and collision stay in map coordinates.
static func ground_scale() -> Vector2:
	var map = GameManager.current_map
	if is_instance_valid(map) and map.has_method("get_ground_projection"):
		return Vector2(1,clampf(map.get_ground_projection(),0.5,1.0))
	return Vector2.ONE

static func screen_direction(world_direction: Vector2) -> Vector2:
	return (world_direction*ground_scale()).normalized()

static func world_direction(screen_direction_value: Vector2) -> Vector2:
	var strength := minf(1.0,screen_direction_value.length())
	return (screen_direction_value/ground_scale()).normalized()*strength

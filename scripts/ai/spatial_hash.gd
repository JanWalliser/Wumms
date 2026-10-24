extends RefCounted

# SpatialHash - Efficient 2D spatial partitioning for horde separation and neighbor queries

class_name SpatialHash

var cell_size: float = 80.0
var grid: Dictionary = {} # cell_coord (Vector2i) -> Array[Node2D]

func _init(c_size: float = 80.0) -> void:
	cell_size = c_size

func clear() -> void:
	grid.clear()

func _pos_to_coord(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))

func insert(entity: Node2D) -> void:
	if not is_instance_valid(entity):
		return
	var coord := _pos_to_coord(entity.global_position)
	if not grid.has(coord):
		grid[coord] = []
	grid[coord].append(entity)

func get_separation_vector(entity: Node2D, separation_radius: float) -> Vector2:
	if not is_instance_valid(entity): return Vector2.ZERO
	var perf = Time.get_ticks_usec() if GameManager.profile_enabled else 0
	var center = entity.global_position
	var base_coord = _pos_to_coord(center)
	var sep = Vector2.ZERO
	var radius_squared = separation_radius*separation_radius
	var span = ceili(separation_radius/cell_size)
	var inspected = 0
	for dy in range(-span,span+1):
		for dx in range(-span,span+1):
			for other in grid.get(base_coord+Vector2i(dx,dy),[]):
				if not is_instance_valid(other) or other == entity: continue
				var diff: Vector2 = center-other.global_position
				var d2 = diff.length_squared()
				if d2 > 0.001 and d2 < radius_squared:
					inspected += 1
					var distance = sqrt(d2)
					sep += diff/distance*(1-distance/separation_radius)
					if inspected >= 16:
						if GameManager.profile_enabled: GameManager.profile_elapsed("separation",perf)
						return sep
	if GameManager.profile_enabled: GameManager.profile_elapsed("separation",perf)
	return sep

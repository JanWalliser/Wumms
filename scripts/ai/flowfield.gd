extends RefCounted

# Flowfield - Uniform-cost multi-source grid navigation with corner-safe diagonal steering.
# Computes seamless vector flow towards all living players around static map obstacles.

class_name Flowfield

var cell_size: float = 64.0
var grid_width: int = 50
var grid_height: int = 50
var origin: Vector2 = Vector2(-1600.0, -1600.0)

# Cost and flow arrays (1D flattened for max performance)
var blocked_cells: PackedByteArray = PackedByteArray()
var cost_field: PackedInt32Array = PackedInt32Array()
var flow_field: PackedVector2Array = PackedVector2Array()

const INFINITE_COST := 999999

func _init(w: int = 60, h: int = 60, c_size: float = 64.0, orig: Vector2 = Vector2(-1920.0, -1920.0)) -> void:
	grid_width = w
	grid_height = h
	cell_size = c_size
	origin = orig

	var total := grid_width * grid_height
	blocked_cells.resize(total)
	blocked_cells.fill(0)

	cost_field.resize(total)
	cost_field.fill(INFINITE_COST)

	flow_field.resize(total)
	flow_field.fill(Vector2.ZERO)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local := world_pos - origin
	return Vector2i(
		clampi(int(local.x / cell_size), 0, grid_width - 1),
		clampi(int(local.y / cell_size), 0, grid_height - 1)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return origin + Vector2(grid_pos.x * cell_size + cell_size * 0.5, grid_pos.y * cell_size + cell_size * 0.5)

func set_blocked(grid_x: int, grid_y: int, blocked: bool) -> void:
	if grid_x >= 0 and grid_x < grid_width and grid_y >= 0 and grid_y < grid_height:
		blocked_cells[grid_y * grid_width + grid_x] = 1 if blocked else 0

func is_blocked(grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return true
	return blocked_cells[grid_y * grid_width + grid_x] == 1

# Rebuilds the costfield and directional flow vectors towards target positions (living players)
func update_field(target_positions: Array[Vector2]) -> void:
	var perf = Time.get_ticks_usec() if GameManager.profile_enabled else 0
	var total = grid_width * grid_height
	cost_field.fill(INFINITE_COST)
	flow_field.fill(Vector2.ZERO)
	var queue = PackedInt32Array()
	queue.resize(total)
	var head = 0
	var tail = 0

	for target in target_positions:
		var cell = world_to_grid(target)
		var idx = cell.y * grid_width + cell.x

		# If target is inside a blocked cell (e.g. hugging an obstacle), find the closest unblocked cell
		if blocked_cells[idx] == 1:
			var found_idx = -1
			var min_dist_sq = 999999.0
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var cx = cell.x + dx
					var cy = cell.y + dy
					if cx >= 0 and cx < grid_width and cy >= 0 and cy < grid_height:
						var c_idx = cy * grid_width + cx
						if blocked_cells[c_idx] == 0:
							var d = float(dx * dx + dy * dy)
							if d < min_dist_sq:
								min_dist_sq = d
								found_idx = c_idx
			if found_idx != -1:
				idx = found_idx
			else:
				continue

		if cost_field[idx] == 0:
			continue
		cost_field[idx] = 0
		queue[tail] = idx
		tail += 1

	while head < tail:
		var idx = queue[head]
		head += 1
		var x = idx % grid_width
		var y = idx / grid_width
		for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nx = x + step.x
			var ny = y + step.y
			if nx < 0 or ny < 0 or nx >= grid_width or ny >= grid_height:
				continue
			var neighbor = ny * grid_width + nx
			if blocked_cells[neighbor] == 1 or cost_field[neighbor] != INFINITE_COST:
				continue
			cost_field[neighbor] = cost_field[idx] + 1
			queue[tail] = neighbor
			tail += 1

	var directions = [
		Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)
	]

	for y in range(grid_height):
		for x in range(grid_width):
			var idx = y * grid_width + x
			if blocked_cells[idx] == 1:
				continue
			var cost = cost_field[idx]

			# If in target cell (cost == 0), flow directly toward the nearest player position
			if cost == 0:
				var cell_world = grid_to_world(Vector2i(x, y))
				var nearest_t = Vector2.ZERO
				var min_td = 99999999.0
				for t in target_positions:
					var td = cell_world.distance_squared_to(t)
					if td < min_td:
						min_td = td
						nearest_t = t
				var to_t = nearest_t - cell_world
				flow_field[idx] = to_t.normalized() if to_t.length_squared() > 1.0 else Vector2.ZERO
				continue

			var best = Vector2.ZERO
			for step in directions:
				var nx = x + step.x
				var ny = y + step.y
				if nx < 0 or ny < 0 or nx >= grid_width or ny >= grid_height:
					continue
				if step.x != 0 and step.y != 0 and (blocked_cells[y * grid_width + nx] == 1 or blocked_cells[ny * grid_width + x] == 1):
					continue
				var next_cost = cost_field[ny * grid_width + nx]
				if next_cost < cost:
					cost = next_cost
					best = Vector2(step).normalized()
			flow_field[idx] = best

	if GameManager.profile_enabled:
		GameManager.profile_elapsed("flowfield", perf)

func get_flow_direction(world_pos: Vector2) -> Vector2:
	var g := world_to_grid(world_pos)
	var idx := g.y * grid_width + g.x
	return flow_field[idx]

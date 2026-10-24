extends Node2D

# MapBase - Base class for all 4 playable maps in WUMMS

class_name MapBase

@export var map_id: String = "map_warehouse"
@export var boss_id: String = "boss_reksai"

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var camera: CameraController = $Camera2D
@onready var players_container: Node2D = $Players
@onready var obstacles_container: Node2D = $Obstacles
@onready var pickups_container: Node2D = $Pickups

var player_scene: PackedScene = preload("res://scenes/characters/player.tscn")

func _ready() -> void:
	GameManager.current_map = self
	_spawn_players()
	_build_bounds()
	var director = EventDirector.new()
	director.name = "EventDirector"
	add_child(director)
	_bake_obstacles_to_flowfield()
	GameManager.boss_spawned.connect(_on_boss_spawned)

func _spawn_players() -> void:
	var active_slots := ProfileManager.get_active_slots()
	var spawn_offsets := [
		Vector2(-40, -40),
		Vector2(40, -40),
		Vector2(-40, 40),
		Vector2(40, 40)
	]

	GameManager.active_player_nodes.clear()

	for i in range(ProfileManager.player_slots.size()):
		var slot = ProfileManager.player_slots[i]
		if not slot["active"]: continue
		var player: PlayerController = player_scene.instantiate()
		player.position = get_player_spawn_position(i, spawn_offsets[i])
		player.setup(i, slot["profile_id"], slot["character_id"])
		players_container.add_child(player)
		GameManager.active_player_nodes.append(player)

func get_player_spawn_position(_slot: int, offset: Vector2) -> Vector2:
	return offset

func get_actor_scale() -> float:
	return 1.0

func get_player_movement_scale() -> float:
	return 1.0

func _bake_obstacles_to_flowfield() -> void:
	if not spawner or not spawner.flowfield:
		return

	# Mark map boundaries as blocked
	var ff := spawner.flowfield
	for x in range(ff.grid_width):
		ff.set_blocked(x, 0, true)
		ff.set_blocked(x, ff.grid_height - 1, true)
	for y in range(ff.grid_height):
		ff.set_blocked(0, y, true)
		ff.set_blocked(ff.grid_width - 1, y, true)

	if obstacles_container:
		_bake_node_obstacles(obstacles_container, ff)

func _bake_node_obstacles(parent: Node, ff: Flowfield) -> void:
	for child in parent.get_children():
		if child is CollisionShape2D and child.shape:
			_bake_single_shape(child, child.shape, ff)
		elif child is CollisionPolygon2D and child.polygon.size() >= 3:
			_bake_single_polygon(child, ff)
		elif child is StaticBody2D or child is Area2D:
			for sub in child.get_children():
				if sub is CollisionShape2D and sub.shape:
					_bake_single_shape(sub, sub.shape, ff)
				elif sub is CollisionPolygon2D and sub.polygon.size() >= 3:
					_bake_single_polygon(sub, ff)
		if child.get_child_count() > 0 and not (child is StaticBody2D):
			_bake_node_obstacles(child, ff)

func _bake_single_shape(shape_node: CollisionShape2D, shape: Shape2D, ff: Flowfield) -> void:
	var pos := shape_node.global_position
	if shape is RectangleShape2D:
		var half: Vector2 = shape.size * 0.5 + Vector2(6.0, 6.0)
		var lo := ff.world_to_grid(pos - half)
		var hi := ff.world_to_grid(pos + half)
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				ff.set_blocked(x, y, true)
	elif shape is CircleShape2D:
		var r: float = shape.radius + 6.0
		var lo := ff.world_to_grid(pos - Vector2(r, r))
		var hi := ff.world_to_grid(pos + Vector2(r, r))
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var cell_center := ff.grid_to_world(Vector2i(x, y))
				if cell_center.distance_to(pos) <= (r + ff.cell_size * 0.4):
					ff.set_blocked(x, y, true)
	elif shape is CapsuleShape2D:
		var r: float = shape.radius + 6.0
		var h: float = shape.height * 0.5 + 6.0
		var lo := ff.world_to_grid(pos - Vector2(r, h))
		var hi := ff.world_to_grid(pos + Vector2(r, h))
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				ff.set_blocked(x, y, true)

func _bake_single_polygon(poly_node: CollisionPolygon2D, ff: Flowfield) -> void:
	var poly := poly_node.polygon
	if poly.size() < 3:
		return
	var xf := poly_node.global_transform
	var global_pts: PackedVector2Array = PackedVector2Array()
	var min_pt := Vector2(INF, INF)
	var max_pt := Vector2(-INF, -INF)
	for p in poly:
		var gp := xf * p
		global_pts.append(gp)
		min_pt.x = minf(min_pt.x, gp.x)
		min_pt.y = minf(min_pt.y, gp.y)
		max_pt.x = maxf(max_pt.x, gp.x)
		max_pt.y = maxf(max_pt.y, gp.y)

	var lo := ff.world_to_grid(min_pt - Vector2(6.0, 6.0))
	var hi := ff.world_to_grid(max_pt + Vector2(6.0, 6.0))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var cell_center := ff.grid_to_world(Vector2i(x, y))
			if Geometry2D.is_point_in_polygon(cell_center, global_pts):
				ff.set_blocked(x, y, true)

func _on_boss_spawned(boss_name: String) -> void:
	if spawner:
		var spawn_pos := camera.global_position + Vector2(0, -500.0)
		GameManager.register_boss(spawner.spawn_boss(boss_id, spawn_pos))

func _build_bounds() -> void:
	for rect in [Rect2(-1920,-1920,3840,64), Rect2(-1920,1856,3840,64), Rect2(-1920,-1920,64,3840), Rect2(1856,-1920,64,3840)]:
		var body = StaticBody2D.new()
		body.collision_layer = 16
		body.position = rect.get_center()
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		body.add_child(col)
		add_child(body)

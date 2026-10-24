extends RefCounted
class_name DropManager

# Construct only after deferral; deleted maps cannot leave orphaned drops.
static func _schedule(parent: Node2D, pos: Vector2, type: int, value: int) -> void:
	if value <= 0: return
	if is_instance_valid(parent): _finish_spawn.call_deferred(weakref(parent),pos,type,value,GameManager.run_id)

static func _finish_spawn(parent_ref: WeakRef, pos: Vector2, type: int, value: int, token: String) -> void:
	var parent = parent_ref.get_ref()
	if not is_instance_valid(parent) or not parent.is_inside_tree() or GameManager.run_id != token or GameManager.run_finalized: return
	var cells: Dictionary = parent.get_meta("drop_cells",{})
	var key = str(type)+":"+str(Vector2i(floor(pos.x/80),floor(pos.y/80)))
	if type in [0,1] and cells.has(key):
		var existing = cells[key].get_ref()
		if is_instance_valid(existing) and existing.get_parent()==parent and existing.global_position.distance_to(pos)<=40.0 and not existing.collected and not existing.is_attracted:
			existing.value += value
			existing._update_visuals()
			return
	var items = parent.get_tree().get_nodes_in_group("pickups")
	if items.size() >= 600:
		# Keep progression at its real location, even at the cosmetic node budget.
		if not type in [0,1,3]: return
	var item = load("res://scenes/combat/drop_item.tscn").instantiate()
	item.item_type = type
	item.value = value
	parent.add_child(item)
	item.global_position = pos
	cells[key] = weakref(item)
	parent.set_meta("drop_cells",cells)

static func spawn_exp_orb(parent: Node2D, pos: Vector2, value: int) -> void:
	_schedule(parent,pos,0,value)

static func spawn_gold(parent: Node2D, pos: Vector2, value: int) -> void:
	_schedule(parent,pos,1,value)

static func spawn_health_pack(parent: Node2D, pos: Vector2, value: int = 150) -> void:
	_schedule(parent,pos,2,value)

static func spawn_access_card(parent: Node2D, pos: Vector2) -> void:
	_schedule(parent,pos,3,1)

static func spawn_special_pickup(parent: Node2D, pos: Vector2, type: int) -> void:
	_schedule(parent,pos,type,1)

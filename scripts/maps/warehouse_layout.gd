extends RefCounted
class_name WarehouseLayout

## The archived world polygons are the single source for physics, navigation and art.
## Conversion: Godot X = (LoL X - 9000) * .2; Godot Y = (9000 - LoL Z) * .2.
const PATH := "res://assets/maps/warehouse/layout.json"
const BOUNDS := Rect2(-1800, -1800, 3600, 3600)
const SCALE := 0.2
var walls: Array[Dictionary] = []
var locators: Array[Dictionary] = []
var _by_number: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Warehouse layout is missing or invalid: " + PATH)
		return
	for raw: Dictionary in parsed.get("walls", []):
		var wall := raw.duplicate()
		wall["polygon"] = points(raw["polygon"])
		wall["rect"] = polygon_bounds(wall["polygon"])
		walls.append(wall)
		_by_number[int(raw["number"])] = wall
	for raw: Dictionary in parsed.get("locators", []):
		var locator := raw.duplicate()
		locator["position"] = Vector2(raw["position"][0], raw["position"][1])
		locators.append(locator)

static func points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in values:
		result.append(Vector2(p[0], p[1]))
	return result

static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	return rect

func wall(number: int) -> Dictionary:
	return _by_number.get(number, {})

func locator(id: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	for item in locators:
		if item["id"] == id:
			return item["position"]
	return fallback

func is_clear(point: Vector2, radius: float = 24.0) -> bool:
	if not BOUNDS.grow(-radius).has_point(point):
		return false
	for entry in walls:
		var rect: Rect2 = entry["rect"]
		if not rect.grow(radius).has_point(point):
			continue
		var polygon: PackedVector2Array = entry["polygon"]
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
		for i in range(polygon.size()):
			if Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i+1)%polygon.size()]).distance_squared_to(point) < radius * radius:
				return false
	return true

func nearest_clear(point: Vector2, radius: float = 28.0) -> Vector2:
	if is_clear(point, radius):
		return point
	for distance in range(16, 801, 16):
		for angle in range(32):
			var candidate := point + Vector2.from_angle(TAU * angle / 32.0) * distance
			if is_clear(candidate, radius):
				return candidate
	return locator("__Spawn_T1", Vector2(0, 270))

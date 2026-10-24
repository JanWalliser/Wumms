extends Node2D
class_name WarehouseArt

## Persistent map art, separate from gameplay. Sprite regions and registrations can
## be replaced without moving any physics polygon or locator.
const DistrictLayout = preload("res://scripts/maps/warehouse_layout.gd")
const GROUND: Texture2D = preload("res://assets/maps/warehouse/ground.res")
const ATLAS: Texture2D = preload("res://assets/maps/warehouse/props-atlas.res")
const WATER_SHADER: Shader = preload("res://assets/maps/warehouse/water.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/maps/warehouse/ground-fade.gdshader")
const DISTRICT_BACKDROP: Shader = preload("res://assets/maps/warehouse/district-backdrop.gdshader")
var layout: DistrictLayout
var edge_lines := PackedVector2Array()
var coast_lines := PackedVector2Array()
var _cell: Vector2
var _regions: Dictionary
var _custom_props: Dictionary

func build(source: DistrictLayout) -> void:
	layout = source
	_cell = ATLAS.get_size() / 3.0
	_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/warehouse/props.json"))["regions"]
	_custom_props = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/warehouse/custom-props.json"))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_base(PackedVector2Array([Vector2(-2600,-2600),Vector2(2600,-2600),Vector2(2600,2600),Vector2(-2600,2600)]), Color("075064"), -40)
	_build_district_backdrop()
	_build_exterior_edges()
	_build_ground()
	for wall in layout.walls:
		if wall["kind"] == "border":
			_build_boundary(wall)
		elif wall["kind"] == "small":
			_build_bench(wall)
		elif int(wall["number"]) not in [27, 28]:
			_build_landmark(wall)
	_build_fountain()
	_build_border_vegetation()
	build_edges()
	queue_redraw()

func _build_district_backdrop() -> void:
	# The camera can see beyond the playable square. Continue the industrial floor
	# there instead of exposing the global water fallback beside the factories.
	# Reflect only the outer texture strip; keep the south waterfront at its Y.
	var corners := PackedVector2Array([Vector2(-6000,-6000),Vector2(6000,-6000),Vector2(6000,6000),Vector2(-6000,6000)])
	var backdrop := _base(corners, Color.WHITE, -35)
	backdrop.name = "DistrictBackdrop"
	backdrop.texture = GROUND
	var uv := PackedVector2Array()
	for point in corners:
		uv.append((point+Vector2(1800,1800))/3600.0*GROUND.get_size())
	backdrop.uv = uv
	var material_backdrop := ShaderMaterial.new()
	material_backdrop.shader = DISTRICT_BACKDROP
	backdrop.material = material_backdrop

func _build_ground() -> void:
	# Ground registration is an art transform only. Never move walls to match pixels.
	# Measured landmark correspondences compensate for the unavailable original UV mesh.
	var registration: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/warehouse/ground-registration.json"))["anchors"]
	var source := PackedVector2Array()
	var target := PackedVector2Array()
	for anchor: Dictionary in registration:
		source.append(Vector2(anchor["atlas"][0], anchor["atlas"][1]))
		target.append(Vector2(anchor["map"][0], anchor["map"][1]))
	var indices := Geometry2D.triangulate_delaunay(source)
	var floor_mesh := Polygon2D.new()
	floor_mesh.name = "RegisteredOriginalGround"
	floor_mesh.z_index = -30
	floor_mesh.texture = GROUND
	var material_ground := ShaderMaterial.new()
	material_ground.shader = GROUND_SHADER
	floor_mesh.material = material_ground
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in source.size():
		vertices.append(target[i] / 1024.0 * 3600.0 - Vector2(1800, 1800))
		uvs.append(source[i] / 1024.0 * GROUND.get_size())
	floor_mesh.polygon = vertices
	floor_mesh.uv = uvs
	var triangles: Array[PackedInt32Array] = []
	for i in range(0, indices.size(), 3):
		triangles.append(PackedInt32Array([indices[i], indices[i+1], indices[i+2]]))
	floor_mesh.polygons = triangles
	add_child(floor_mesh)

func _build_exterior_edges() -> void:
	# Off-map floor continuation must not suggest traversable industrial streets.
	var exterior_roof := _base(PackedVector2Array([Vector2(1800,-6000),Vector2(6000,-6000),Vector2(6000,645),Vector2(1800,645)]),Color("303c49"),-34)
	_style_roof(exterior_roof)
	for bounds in [Rect2(1800,645,4200,5355),Rect2(-6000,1800,12000,4200)]:
		_water_surface(PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]),-34)

func _water_surface(poly: PackedVector2Array, level: int) -> Polygon2D:
	var water := _base(poly,Color.WHITE,level)
	water.texture = GROUND
	var uv := PackedVector2Array()
	for point in poly:
		uv.append(Vector2(clampf((point.x+1800)/3600.0,0.01,0.99),0.90+0.06*clampf((point.y+1800)/3600.0,0,1))*GROUND.get_size())
	water.uv = uv
	return water

func _style_roof(roof: Polygon2D) -> void:
	roof.texture = load("res://assets/maps/warehouse/roof-tile.res")
	roof.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var uv := PackedVector2Array()
	for point in roof.polygon: uv.append(point*1.3)
	roof.uv = uv
	roof.modulate = Color(0.65,0.70,0.76)

func _base(polygon: PackedVector2Array, color: Color, level: int = -18) -> Polygon2D:
	var node := Polygon2D.new()
	node.polygon = polygon
	node.color = color
	node.z_index = level
	add_child(node)
	return node

func _region(cell: Vector2i) -> Rect2:
	var region: Array = _regions[str(cell.x)+","+str(cell.y)]
	return Rect2(region[0],region[1],region[2],region[3])

func _build_pond(wall: Dictionary) -> void:
	# Water deliberately follows its shoreline. Buildings use complete sprites instead.
	var poly: PackedVector2Array = wall["polygon"]
	var bounds: Rect2 = wall["rect"]
	var shadow := PackedVector2Array()
	for point in poly: shadow.append(point+Vector2(13,18))
	_base(shadow,Color(0.02,0.03,0.04,0.23),-25)
	_base(poly, Color("126d72"))
	var water := _base(poly, Color.WHITE, -16)
	water.name = str(wall["id"]) + "_Water"
	water.texture = ATLAS
	var region := _region(Vector2i(1,0))
	var uv := PackedVector2Array()
	for point in poly:
		uv.append(region.position + (point-bounds.position)/bounds.size*region.size)
	water.uv = uv
	var material_water := ShaderMaterial.new()
	material_water.shader = WATER_SHADER
	material_water.set_shader_parameter("region_min", region.position / ATLAS.get_size())
	material_water.set_shader_parameter("region_size", region.size / ATLAS.get_size())
	water.material = material_water
	_outline(poly, Color("94a6a7"), 3.0, -15)

func _sprite(cell: Vector2i, center: Vector2, dimensions: Vector2, level: int = -12, angle: float = 0.0) -> Sprite2D:
	var region := AtlasTexture.new()
	region.atlas = ATLAS
	region.region = _region(cell)
	region.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = region
	sprite.position = center
	var fit := dimensions / region.region.size
	sprite.scale = Vector2.ONE * minf(fit.x,fit.y)
	sprite.rotation = angle
	sprite.z_index = level
	add_child(sprite)
	return sprite

func _outline(poly: PackedVector2Array, color: Color, width: float, level: int) -> void:
	var line := Line2D.new()
	line.points = poly
	line.closed = true
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.z_index = level
	add_child(line)

func _build_landmark(wall: Dictionary) -> void:
	var number := int(wall["number"])
	match number:
		24:
			_build_pond(wall)
			_outline(wall["polygon"], Color("c4c1b0"), 7.0, -14)
		25:
			var statue := _sprite(Vector2i(2, 0), wall["rect"].get_center(), wall["rect"].size)
			statue.name = str(wall["id"]) + "_Art"
		7, 8, 9, 10, 26:
			_build_custom_prop(wall)

func _build_custom_prop(wall: Dictionary) -> void:
	# Physics outlines are not texture masks. Keep every roof, pipe and facade intact.
	var config: Dictionary = _custom_props[str(int(wall["number"]))]
	var sprite := Sprite2D.new()
	sprite.name = str(wall["id"]) + "_Art"
	sprite.texture = load("res://assets/maps/warehouse/" + str(config["file"]))
	var guide_size := Vector2(config["guide_size"][0], config["guide_size"][1])
	var image_anchor := Vector2(config["guide_anchor"][0], config["guide_anchor"][1]) / guide_size * sprite.texture.get_size()
	var uniform_scale := float(config["world_per_guide_pixel"]) * guide_size.x / sprite.texture.get_width()
	sprite.centered = false
	sprite.scale = Vector2.ONE * uniform_scale
	sprite.position = Vector2(config["world_center"][0], config["world_center"][1]) - image_anchor * uniform_scale
	sprite.z_index = -12
	add_child(sprite)

func _build_fountain() -> void:
	# The registered ground already supplies the single circular stone plinth.
	# The transparent sprite contains only the basin, fixtures and monument.
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/warehouse/presentation.json"))["fountain"]
	var sprite := Sprite2D.new()
	sprite.name = "HealingFountainArt"
	sprite.texture = load("res://assets/maps/warehouse/custom/fountain-core.res")
	# Height is a projected monument, not the extent of the ground collision region.
	var uniform_scale := float(config["basin_width_world"])/float(config["basin_width_pixels"])
	var basin_center := Vector2(config["basin_center_pixels"][0],config["basin_center_pixels"][1])
	sprite.centered = false
	sprite.scale = Vector2.ONE*uniform_scale
	sprite.position = layout.locator("Fountain") - basin_center*uniform_scale
	sprite.z_index = -12
	add_child(sprite)

func _build_bench(wall: Dictionary) -> void:
	var poly: PackedVector2Array = wall["polygon"]
	var bounds: Rect2 = wall["rect"]
	_base(poly, Color("788284"), -17)
	_outline(poly, Color("b7b8a9"), 1.5, -16)
	var longest := Vector2.ZERO
	for i in poly.size():
		var edge := poly[(i+1)%poly.size()] - poly[i]
		if edge.length_squared() > longest.length_squared():
			longest = edge
	var length := longest.length()
	var depth := maxf(12.0, absf((poly[1]-poly[0]).cross(poly[2]-poly[0]))/maxf(length, 1.0))
	var angle := longest.angle() - PI*0.5
	var sprite := _sprite(Vector2i(1, 2), bounds.get_center(), Vector2(depth*1.08, length*1.08), -11, angle)
	sprite.name = str(wall["id"]) + "_Bench"
	var lamp_texture := AtlasTexture.new()
	lamp_texture.atlas = ATLAS
	var lamp_rect: Array = _regions["lamp"]
	lamp_texture.region = Rect2(lamp_rect[0],lamp_rect[1],lamp_rect[2],lamp_rect[3])
	lamp_texture.filter_clip = true
	var lamp := Sprite2D.new()
	lamp.texture = lamp_texture
	lamp.position = bounds.get_center()+Vector2(depth*1.4,0).rotated(angle)-Vector2(0,55)
	lamp.scale = Vector2(34,110)/lamp_texture.get_size()
	lamp.z_index = -10
	add_child(lamp)

func _build_boundary(wall: Dictionary) -> void:
	var number := int(wall["number"])
	var poly: PackedVector2Array = wall["polygon"]
	var north_city := number in [1, 2, 3, 4, 5, 18, 19, 20, 21, 22, 23, 29]
	if north_city:
		var roof := _base(poly, Color("303c49"), -23)
		roof.name = str(wall["id"]) + "_DistrictRoof"
		_style_roof(roof)
	else:
		var water := _water_surface(poly,-24)
		water.name = str(wall["id"])+"_RestrictedWater"
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var steps := maxi(1, ceili(a.distance_to(b) / 48.0))
		var normal := (b-a).normalized().orthogonal()*12.0
		for step in steps:
			var start := a.lerp(b, float(step)/steps)
			var end := a.lerp(b, float(step+1)/steps)
			var midpoint := (start+end)*0.5
			if layout.is_clear(midpoint+normal, 0.0) or layout.is_clear(midpoint-normal, 0.0):
				var lines := edge_lines if north_city else coast_lines
				lines.append(start)
				lines.append(end)
				if north_city: edge_lines = lines
				else: coast_lines = lines

func _build_border_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1416
	for y in range(-1250, 600, 170):
		var point := Vector2(-1450+rng.randf_range(-35, 35), y)
		if not layout.is_clear(point, 0.0):
			var sprite := _sprite(Vector2i(0, 2), point, Vector2(220, 250), -10)
			sprite.modulate = Color(0.9, 0.96, 0.84)

func build_edges() -> void:
	var edges := Node2D.new()
	edges.name = "DistrictEdges"
	edges.z_index = -13
	add_child(edges)
	edges.draw.connect(func():
		if not edge_lines.is_empty():
			edges.draw_multiline(edge_lines, Color("192933"), 17.0, true)
			edges.draw_multiline(edge_lines, Color("80969c"), 4.0, true)
		# Draw the actual collision edge, after masking misleading pavement outside it.
		if not coast_lines.is_empty():
			edges.draw_multiline(coast_lines,Color("13252c"),16.0,true)
			edges.draw_multiline(coast_lines,Color("9a8557"),4.0,true)
	)
	edges.queue_redraw()

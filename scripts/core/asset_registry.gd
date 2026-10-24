extends Node

# AssetRegistry - Centralized asset loader and procedural placeholder generator.
# Allows transparent swapping: If an image file exists in res://assets/, it is loaded.
# Otherwise, generates crisp, distinguishable cartoon-styled placeholder textures dynamically.

var _texture_cache: Dictionary = {}

func get_character_texture(char_id: String) -> Texture2D:
	var key = "char_"+char_id
	if _texture_cache.has(key): return _texture_cache[key]
	if char_id=="jankz" and ResourceLoader.exists("res://assets/actors/animated/jankz.res"):
		var frames: SpriteFrames = load("res://assets/actors/animated/jankz.res")
		var portrait := AtlasTexture.new()
		portrait.atlas=frames.get_frame_texture("idle",0)
		portrait.region=Rect2(91,8,100,105)
		portrait.filter_clip=true
		_texture_cache[key]=portrait
		return portrait
	var path = "res://assets/characters/%s.png" % char_id
	var texture = load(path) if ResourceLoader.exists(path) else _generate_character_texture(char_id)
	_texture_cache[key] = texture
	return texture

func get_enemy_texture(enemy_type: String) -> Texture2D:
	var key = "enemy_"+enemy_type
	if _texture_cache.has(key): return _texture_cache[key]
	var path = "res://assets/enemies/%s.png" % enemy_type
	var texture = load(path) if ResourceLoader.exists(path) else _generate_enemy_texture(enemy_type)
	_texture_cache[key] = texture
	return texture

func get_projectile_texture(proj_type: String) -> Texture2D:
	var key = "proj_"+proj_type
	if _texture_cache.has(key): return _texture_cache[key]
	var path = "res://assets/projectiles/%s.png" % proj_type
	var texture = load(path) if ResourceLoader.exists(path) else _generate_projectile_texture(proj_type)
	_texture_cache[key] = texture
	return texture

func get_pickup_texture(pickup_type: String) -> Texture2D:
	var key = "pickup_"+pickup_type
	if _texture_cache.has(key): return _texture_cache[key]
	var path = "res://assets/pickups/%s.png" % pickup_type
	var texture = load(path) if ResourceLoader.exists(path) else _generate_pickup_texture(pickup_type)
	_texture_cache[key] = texture
	return texture

func get_crate_texture() -> Texture2D:
	var key = "misc_crate"
	if _texture_cache.has(key): return _texture_cache[key]
	var img := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.35, 0.18)) # Wood brown
	_draw_rect_on_image(img, Rect2i(0, 0, 36, 3), Color(0.35, 0.22, 0.1))
	_draw_rect_on_image(img, Rect2i(0, 33, 36, 3), Color(0.35, 0.22, 0.1))
	_draw_rect_on_image(img, Rect2i(0, 0, 3, 36), Color(0.35, 0.22, 0.1))
	_draw_rect_on_image(img, Rect2i(33, 0, 3, 36), Color(0.35, 0.22, 0.1))
	_draw_rect_on_image(img, Rect2i(3, 16, 30, 4), Color(0.42, 0.26, 0.12))
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[key] = tex
	return tex

func _generate_character_texture(char_id: String) -> ImageTexture:
	var size := Vector2i(64, 64)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var base_col: Color
	var accent_col: Color
	var feature_type: String = "circle"

	match char_id:
		"jankz":
			base_col = Color(0.95, 0.2, 0.6) # Neon Hot Pink
			accent_col = Color(0.2, 0.9, 0.9) # Cyan braids
			feature_type = "pigtails"
		"seraföhn":
			base_col = Color(0.25, 0.85, 0.85) # Vibrant Aqua
			accent_col = Color(0.95, 0.5, 0.8) # Pink melody
			feature_type = "microphone"
		"löwina":
			base_col = Color(0.98, 0.82, 0.15) # Radiant Gold
			accent_col = Color(0.85, 0.45, 0.1) # Solar bronze
			feature_type = "shield"
		"illaupsi":
			base_col = Color(0.18, 0.72, 0.48) # Sea Priestess Green
			accent_col = Color(0.1, 0.35, 0.25) # Deep abyss
			feature_type = "tentacle"
		"brioche":
			base_col = Color(0.85, 0.15, 0.25) # Berserk Crimson
			accent_col = Color(0.95, 0.75, 0.6) # Pastry dough
			feature_type = "horns"
		"yasüff":
			base_col = Color(0.2, 0.5, 0.95) # Tempest Blue
			accent_col = Color(0.85, 0.9, 1.0) # Wind blade
			feature_type = "topknot"
		"rübenrambo":
			base_col = Color(1.0, 0.5, 0.1) # Fierce Orange Carrot
			accent_col = Color(0.3, 0.85, 0.3) # Carrot greens
			feature_type = "ears"
		"auarora":
			base_col = Color(0.68, 0.35, 0.92) # Spirit Lavender
			accent_col = Color(0.95, 0.85, 1.0) # Ghost glow
			feature_type = "witch_hat"
		"xayaya":
			base_col = Color(0.55, 0.15, 0.65) # Dark Plum Feather
			accent_col = Color(0.95, 0.3, 0.5) # Razor wing
			feature_type = "quills"
		_:
			base_col = Color(0.7, 0.7, 0.7)
			accent_col = Color(1, 1, 1)

	var center := Vector2(32, 34)
	var radius := 22.0

	# Draw body shadow / outline
	for y in range(size.y):
		for x in range(size.x):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius + 2.0:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.12, 0.9))
			if dist <= radius:
				img.set_pixel(x, y, base_col)
			if dist <= radius - 4.0 and y < 32:
				# Highlight top
				img.set_pixel(x, y, base_col.lightened(0.2))

	# Draw eye highlights
	_draw_circle_on_image(img, Vector2(25, 30), 4.0, Color.WHITE)
	_draw_circle_on_image(img, Vector2(39, 30), 4.0, Color.WHITE)
	_draw_circle_on_image(img, Vector2(26, 30), 2.0, Color(0.1, 0.1, 0.1))
	_draw_circle_on_image(img, Vector2(40, 30), 2.0, Color(0.1, 0.1, 0.1))

	# Draw distinct character features
	match feature_type:
		"pigtails":
			_draw_circle_on_image(img, Vector2(10, 24), 7.0, accent_col)
			_draw_circle_on_image(img, Vector2(54, 24), 7.0, accent_col)
		"microphone":
			_draw_circle_on_image(img, Vector2(32, 12), 6.0, accent_col)
			_draw_circle_on_image(img, Vector2(32, 46), 4.0, accent_col)
		"shield":
			_draw_rect_on_image(img, Rect2i(27, 8, 10, 10), accent_col)
			_draw_circle_on_image(img, Vector2(32, 13), 3.0, Color.WHITE)
		"tentacle":
			_draw_circle_on_image(img, Vector2(14, 14), 6.0, accent_col)
			_draw_circle_on_image(img, Vector2(50, 14), 6.0, accent_col)
		"horns":
			_draw_circle_on_image(img, Vector2(18, 14), 5.0, accent_col)
			_draw_circle_on_image(img, Vector2(46, 14), 5.0, accent_col)
		"topknot":
			_draw_rect_on_image(img, Rect2i(30, 4, 5, 12), accent_col)
		"ears":
			_draw_rect_on_image(img, Rect2i(22, 4, 6, 15), accent_col)
			_draw_rect_on_image(img, Rect2i(36, 4, 6, 15), accent_col)
		"witch_hat":
			_draw_rect_on_image(img, Rect2i(18, 10, 28, 6), accent_col)
			_draw_circle_on_image(img, Vector2(32, 8), 6.0, accent_col)
		"quills":
			_draw_rect_on_image(img, Rect2i(8, 20, 10, 5), accent_col)
			_draw_rect_on_image(img, Rect2i(46, 20, 10, 5), accent_col)

	return ImageTexture.create_from_image(img)

func _generate_enemy_texture(enemy_type: String) -> ImageTexture:
	var size := Vector2i(48, 48)
	var col := Color(0.7, 0.2, 0.2)
	var eye_col := Color(1.0, 0.9, 0.2)
	var radius := 16.0

	match enemy_type:
		"standard_grunt": # Standard-Gurkengang
			col = Color(0.3, 0.65, 0.3) # Pickle green
			radius = 14.0
		"fast_runner": # Schneller Nahkampfgegner
			col = Color(0.9, 0.45, 0.1) # Fast orange
			radius = 12.0
		"heavy_tank": # Schwer gepanzerter Gegner
			size = Vector2i(64, 64)
			col = Color(0.4, 0.45, 0.55) # Armored iron
			radius = 26.0
		"ranged_spitter": # Fernkampfangreifer
			col = Color(0.75, 0.25, 0.85) # Purple spitter
			radius = 14.0
		"kamikaze_exploder": # Explodierender Gegner
			col = Color(0.95, 0.15, 0.15) # Ticking red bomb
			radius = 15.0
		"aoe_bruiser": # Gegner mit Flächenangriffen
			size = Vector2i(56, 56)
			col = Color(0.85, 0.3, 0.1)
			radius = 22.0
		"support_buffer": # Unterstützungs-/Spezialgegner
			col = Color(0.2, 0.8, 0.7)
			radius = 13.0
		"elite_variant": # Premium-Pöbel
			size = Vector2i(64, 64)
			col = Color(0.95, 0.85, 0.2) # Golden glowing elite
			radius = 24.0
		"mini_boss": # Halbstarke Hauptgegner
			size = Vector2i(80, 80)
			col = Color(0.8, 0.1, 0.4)
			radius = 32.0
		"boss_reksai": # Urzeit-Rexi
			size = Vector2i(120, 120)
			col = Color(0.3, 0.15, 0.45) # Deep void purple burrower
			radius = 48.0
		"boss_briar": # Ur-Brioche
			size = Vector2i(120, 120)
			col = Color(0.85, 0.1, 0.2) # Blood red frenzy
			radius = 46.0
		"boss_belveth": # Bella-Viech Prime
			size = Vector2i(140, 140)
			col = Color(0.6, 0.1, 0.7) # Royal void empress
			radius = 54.0
		"boss_aatrox": # Aua-Trox
			size = Vector2i(160, 160)
			col = Color(0.9, 0.1, 0.15) # Giant darkin blood god
			radius = 64.0

	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size.x * 0.5, size.y * 0.5)

	# Draw outline & body
	for y in range(size.y):
		for x in range(size.x):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius + 2.0:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05, 0.95))
			if dist <= radius:
				img.set_pixel(x, y, col)

	# Draw mean eyes
	var eye_offset := radius * 0.4
	_draw_circle_on_image(img, center + Vector2(-eye_offset, -radius * 0.2), maxf(2.0, radius * 0.15), eye_col)
	_draw_circle_on_image(img, center + Vector2(eye_offset, -radius * 0.2), maxf(2.0, radius * 0.15), eye_col)

	return ImageTexture.create_from_image(img)

func _generate_projectile_texture(proj_type: String) -> ImageTexture:
	var size := Vector2i(32, 32)
	var col := Color.WHITE
	match proj_type:
		"laser", "uwu":
			col = Color(0.95, 0.2, 0.8)
		"bullet", "gatling":
			col = Color(1.0, 0.8, 0.2)
		"rocket":
			col = Color(1.0, 0.3, 0.2)
		"boomerang":
			col = Color(0.2, 0.85, 1.0)
		"saw", "cyclone":
			col = Color(0.7, 0.9, 1.0)
		"tentacle":
			col = Color(0.2, 0.8, 0.5)
		"mine":
			col = Color(0.9, 0.3, 0.1)
		"lightning":
			col = Color(0.3, 0.7, 1.0)
		"feather":
			col = Color(0.8, 0.2, 0.9)
		"arrow":
			col = Color(0.4, 0.9, 0.4)
		"ice":
			col = Color(0.6, 0.9, 1.0)
		_:
			col = Color(1, 1, 0.5)

	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(16, 16)
	_draw_circle_on_image(img, center, 10.0, Color(0, 0, 0, 0.7))
	_draw_circle_on_image(img, center, 8.0, col)
	_draw_circle_on_image(img, center, 4.0, Color.WHITE)

	return ImageTexture.create_from_image(img)

func _generate_pickup_texture(pickup_type: String) -> ImageTexture:
	var size := Vector2i(24, 24)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(12, 12)

	match pickup_type:
		"exp_orb", "exp_orb_blue", "exp_orb_purple", "exp_orb_gold":
			var orb_color := Color("55c8ff")
			if pickup_type == "exp_orb_purple": orb_color = Color("ba77ff")
			if pickup_type == "exp_orb_gold": orb_color = Color("ffd66b")
			_draw_circle_on_image(img, center, 8.0, orb_color)
			_draw_circle_on_image(img, center, 4.0, Color(0.8, 0.95, 1.0))
		"gold": # Dönerdublonen
			_draw_circle_on_image(img, center, 9.0, Color(1.0, 0.8, 0.1))
			_draw_circle_on_image(img, center, 6.0, Color(0.85, 0.6, 0.05))
		"health_pack": # Sanitäter-Semmel
			_draw_circle_on_image(img, center, 10.0, Color(0.2, 0.8, 0.3))
			_draw_rect_on_image(img, Rect2i(10, 5, 4, 14), Color.WHITE)
			_draw_rect_on_image(img, Rect2i(5, 10, 14, 4), Color.WHITE)
		"access_card": # Zutritts-Zwieback
			_draw_rect_on_image(img, Rect2i(4, 3, 16, 18), Color(0.9, 0.75, 0.2))
			_draw_rect_on_image(img, Rect2i(6, 5, 12, 14), Color(0.15, 0.15, 0.3))
		"vacuum": # Super-Staubsauger-Saugnapf
			_draw_circle_on_image(img, center, 10.0, Color(0.9, 0.2, 0.5))
			_draw_circle_on_image(img, center, 5.0, Color.WHITE)
		"bomb": # Bumm-Birne
			_draw_circle_on_image(img, center, 9.0, Color(0.2, 0.2, 0.2))
			_draw_circle_on_image(img, center + Vector2(2, -2), 3.0, Color.RED)
		_:
			_draw_circle_on_image(img, center, 8.0, Color.WHITE)

	return ImageTexture.create_from_image(img)

func _draw_circle_on_image(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2 := radius * radius
	var min_x := maxi(0, int(center.x - radius))
	var max_x := mini(img.get_width() - 1, int(center.x + radius))
	var min_y := maxi(0, int(center.y - radius))
	var max_y := mini(img.get_height() - 1, int(center.y + radius))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var d2 := (Vector2(x, y) - center).length_squared()
			if d2 <= r2:
				img.set_pixel(x, y, color)

func _draw_rect_on_image(img: Image, rect: Rect2i, color: Color) -> void:
	var min_x := maxi(0, rect.position.x)
	var max_x := mini(img.get_width() - 1, rect.position.x + rect.size.x - 1)
	var min_y := maxi(0, rect.position.y)
	var max_y := mini(img.get_height() - 1, rect.position.y + rect.size.y - 1)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			img.set_pixel(x, y, color)

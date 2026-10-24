extends SceneTree

## Reproducible texture compilation without an interactive editor session.
## Pixel colors and alpha are preserved; mipmaps prevent distant texture flicker.
func _initialize() -> void:
	for directory in ["res://assets/ui/swarm/jinx-items/","res://assets/projectiles/arsenal/"]:
		for file in DirAccess.get_files_at(directory):
			if file.get_extension() not in ["svg","png"]: continue
			if directory.ends_with("arsenal/") and not file.begins_with("world-"): continue
			var icon := Image.load_from_file(directory+file)
			if icon==null or icon.is_empty():
				push_error("Invalid authored icon: "+file)
				quit(1)
				return
			icon.generate_mipmaps()
			if directory.contains("jinx-items"):
				# HUD cells are at most ~80 screen pixels. Keep originals as artwork,
				# compile a 256px mipmapped runtime texture instead of 69 huge paintings.
				if icon.get_width()>256 or icon.get_height()>256: icon.resize(256,256,Image.INTERPOLATE_LANCZOS)
				icon.generate_mipmaps()
			if ResourceSaver.save(ImageTexture.create_from_image(icon),directory+file.get_basename()+".res",ResourceSaver.FLAG_COMPRESS)!=OK:
				quit(1)
				return
	for rocket_file in ["ultimate-rocket","small-rocket","rocket-explosion"]:
		var rocket_image := Image.load_from_file("res://assets/projectiles/jinx/"+rocket_file+".png")
		if rocket_image==null or rocket_image.is_empty():
			push_error("Missing Jinx effect: "+rocket_file)
			quit(1)
			return
		rocket_image.generate_mipmaps()
		if ResourceSaver.save(ImageTexture.create_from_image(rocket_image),"res://assets/projectiles/jinx/"+rocket_file+".res",ResourceSaver.FLAG_COMPRESS)!=OK:
			quit(1)
			return
	for asset in ["bunny-bolt","snack-arrow","schnitzel-slicer","ember-pool","uwu-pulse","gatling-turret","arsenal-companions","painted-boomerang","painted-batblade","painted-crescent"]:
		var source := Image.load_from_file("res://assets/projectiles/arsenal/"+asset+".png")
		if source==null or source.is_empty() or source.detect_alpha()==Image.ALPHA_NONE:
			push_error("Missing transparent arsenal artwork: "+asset)
			quit(1)
			return
		source.generate_mipmaps()
		if ResourceSaver.save(ImageTexture.create_from_image(source),"res://assets/projectiles/arsenal/"+asset+".res",ResourceSaver.FLAG_COMPRESS)!=OK:
			quit(1)
			return
	var names := ["ground.jpg", "props-atlas.png", "fountain.png", "roof-tile.png", "minimap.png"]
	for number in [7, 8, 9, 10, 26]:
		names.append("custom/prop-"+str(number)+".png")
	names.append("custom/fountain-core.png")
	for ui_file in ["hud-frame","choice-card","access-card","icons"]:
		var ui_image := Image.load_from_file("res://assets/ui/swarm/"+ui_file+".png")
		ui_image.generate_mipmaps()
		var ui_texture := ImageTexture.create_from_image(ui_image)
		if ResourceSaver.save(ui_texture,"res://assets/ui/swarm/"+ui_file+".res",ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Cannot compile UI texture: "+ui_file)
			quit(1)
			return
	for icon in ["jinx-standard","jinx-ultimate","mega-blast","bunny-bow","snack-bow","schnitzel-icon"]:
		var icon_image := Image.load_from_file("res://assets/ui/swarm/"+icon+".svg")
		icon_image.generate_mipmaps()
		if ResourceSaver.save(ImageTexture.create_from_image(icon_image),"res://assets/ui/swarm/"+icon+".res",ResourceSaver.FLAG_COMPRESS)!=OK:
			quit(1)
			return
	for file: String in names:
		var image := Image.load_from_file("res://assets/maps/warehouse/"+file)
		if image == null or image.is_empty():
			push_error("Missing warehouse art: "+file)
			quit(1)
			return
		image.generate_mipmaps()
		var texture := ImageTexture.create_from_image(image)
		var target := "res://assets/maps/warehouse/"+file.get_basename()+".res"
		var result := ResourceSaver.save(texture,target,ResourceSaver.FLAG_COMPRESS)
		if result != OK:
			push_error("Cannot compile warehouse art: "+target)
			quit(1)
			return
		print("COMPILED ",file," ",image.get_size())
	print("WAREHOUSE ASSETS COMPILED")
	quit()

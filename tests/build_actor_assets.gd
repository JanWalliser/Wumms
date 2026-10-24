extends SceneTree

const ROOT := "res://assets/actors/animated/"

func _initialize() -> void:
	for entry in [["jankz","jankz-sheet",1,2],["standard_grunt","enemy-light-sheet",0,4],["fast_runner","enemy-light-sheet",1,4],["ranged_spitter","enemy-light-sheet",2,4],["kamikaze_exploder","enemy-light-sheet",3,4],["heavy_tank","enemy-heavy-sheet",0,4],["aoe_bruiser","enemy-heavy-sheet",1,4],["support_buffer","enemy-heavy-sheet",2,4],["elite_variant","enemy-heavy-sheet",3,4],["mini_boss","enemy-boss-sheet",0,4],["boss_reksai","enemy-boss-sheet",1,4],["boss_briar","enemy-boss-sheet",2,4],["boss_belveth","enemy-boss-sheet",3,4]]:
		var source := Image.load_from_file(ROOT+entry[1]+".png")
		if source==null: quit(1); return
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("walk")
		frames.set_animation_speed("walk",10 if entry[0]=="jankz" else 8)
		frames.add_animation("idle")
		frames.set_animation_speed("idle",3)
		for column in 4:
			frames.add_frame("walk",cell(source,column,float(entry[2])/entry[3],float(entry[2]+1)/entry[3]))
			if entry[0]=="jankz": frames.add_frame("idle",cell(source,column,0,0.5))
		if entry[0]!="jankz": frames.add_frame("idle",frames.get_frame_texture("walk",0))
		if ResourceSaver.save(frames,ROOT+entry[0]+".res",ResourceSaver.FLAG_COMPRESS)!=OK: quit(1); return
	var fx := Image.load_from_file(ROOT+"weapon-fx-sheet.png")
	var effects := SpriteFrames.new()
	effects.remove_animation("default")
	var bounds := [0.0,0.25,0.5,0.67,1.0]
	var names := ["exhaust","muzzle","pellet","explosion"]
	for row in 4:
		effects.add_animation(names[row])
		effects.set_animation_speed(names[row],16)
		effects.set_animation_loop(names[row],row!=3)
		for column in 4: effects.add_frame(names[row],cell(fx,column,bounds[row],bounds[row+1]))
	if ResourceSaver.save(effects,ROOT+"weapon-fx.res",ResourceSaver.FLAG_COMPRESS)!=OK: quit(1); return
	compile_character_assets()
	compile_jinx_directional()
	compile_arsenal_vfx()
	print("ACTOR ASSETS: 13 actors, 56 unique actor frames and 16 VFX frames compiled")
	quit()

func compile_arsenal_vfx() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for entry in [["elemental",["flame","frost","electric","poison"]],["arcane",["vortex","radiant","shield","orbital"]],["combat",["slash","feather","tentacle"]],["uwu",["uwu_gun","uwu_bolt","uwu_flash","uwu_hit"]]]:
		var source := Image.load_from_file("res://assets/vfx/arsenal/"+entry[0]+".png")
		var names: Array = entry[1]
		for row in names.size():
			frames.add_animation(names[row])
			frames.set_animation_speed(names[row],12)
			for column in 4: frames.add_frame(names[row],cell(source,column,float(row)/names.size(),float(row+1)/names.size()))
	if ResourceSaver.save(frames,"res://assets/vfx/arsenal/animations.res",ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot compile arsenal VFX")

func compile_jinx_directional() -> void:
	var frames: SpriteFrames = load(ROOT+"jankz.res").duplicate(true)
	for entry in [["e","east-southeast",0,4],["se","east-southeast",2,4],["s","north-south",0,4],["n","north-south",2,4],["ne","northeast",0,2]]:
		var source := Image.load_from_file(ROOT+"jinx-directional/"+entry[1]+".png")
		for state in ["walk","shoot","idle"]:
			var name: String = state+"_"+entry[0]
			frames.add_animation(name)
			frames.set_animation_speed(name,24 if state=="shoot" else (10 if state=="walk" else 3))
			var row: int = entry[2]+(1 if state=="shoot" else 0)
			for column in (1 if state=="idle" else 4):
				frames.add_frame(name,directional_cell(source,column,float(row)/entry[3],float(row+1)/entry[3]))
	# Anchors are authored in the final 256px frame, measured at each painted muzzle.
	frames.set_meta("muzzle_e",[Vector2(245,109),Vector2(246,117),Vector2(244,112),Vector2(245,113)])
	frames.set_meta("muzzle_se",[Vector2(237,156),Vector2(242,165),Vector2(239,160),Vector2(239,169)])
	frames.set_meta("muzzle_s",[Vector2(159,195),Vector2(160,194),Vector2(154,195),Vector2(142,196)])
	frames.set_meta("muzzle_n",[Vector2(146,6),Vector2(145,6),Vector2(142,6),Vector2(123,6)])
	frames.set_meta("muzzle_ne",[Vector2(226,39),Vector2(227,32),Vector2(225,33),Vector2(239,32)])
	frames.set_meta("frame_center",Vector2(140,140))
	for direction in ["e","se","s","n","ne"]:
		var points: Array = frames.get_meta("muzzle_"+direction)
		for index in points.size(): points[index]+=Vector2(12,12)
		frames.set_meta("muzzle_"+direction,points)
	if ResourceSaver.save(frames,ROOT+"jankz-directional.res",ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot save directional Jinx")
	var source := Image.load_from_file(ROOT+"jinx-directional/primary-single-round.png")
	var fx := SpriteFrames.new()
	fx.remove_animation("default")
	for row in 3:
		var name: String = ["jinx_round","jinx_muzzle","jinx_hit"][row]
		fx.add_animation(name)
		fx.set_animation_speed(name,24)
		for column in 4: fx.add_frame(name,cell(source,column,row/3.0,(row+1)/3.0))
	if ResourceSaver.save(fx,ROOT+"jinx-primary-fx.res",ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot save primary VFX")

func directional_cell(source: Image, column: int, top: float, bottom: float) -> Texture2D:
	# A small gutter recovers braids/barrels reaching outside the nominal grid.
	# Keep the actor's connected silhouette; discard neighboring-frame fragments.
	var x := roundi(source.get_width()*column/4.0)
	var end := roundi(source.get_width()*(column+1)/4.0)
	var y := roundi(source.get_height()*top)
	var height := roundi(source.get_height()*bottom)-y
	var rect := Rect2i(x-16,y-16,end-x+32,height+32)
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO,source.get_size()))
	var image := Image.create(rect.size.x,rect.size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.blit_rect(source,clipped,clipped.position-rect.position)
	var width := image.get_width()
	var count := width*image.get_height()
	var alpha := PackedByteArray()
	alpha.resize(count)
	for py in image.get_height():
		for px in width: alpha[py*width+px]=1 if image.get_pixel(px,py).a>0.3 else 0
	var largest := PackedInt32Array()
	for start in count:
		if alpha[start]!=1: continue
		var component := PackedInt32Array([start])
		alpha[start]=2
		var head := 0
		while head<component.size():
			var at := component[head]
			head+=1
			for next in [at-1,at+1,at-width,at+width]:
				if next<0 or next>=count or abs(next%width-at%width)>1 or alpha[next]!=1: continue
				alpha[next]=2
				component.append(next)
		if component.size()>largest.size(): largest=component
	var keep := PackedByteArray()
	keep.resize(count)
	for at in largest:
		for dy in range(-2,3):
			for dx in range(-2,3):
				var px := at%width+dx
				var py := at/width+dy
				if px>=0 and px<width and py>=0 and py<image.get_height(): keep[py*width+px]=1
	for py in image.get_height():
		for px in width:
			if keep[py*width+px]==0: image.set_pixel(px,py,Color.TRANSPARENT)
	var factor := 240.0/maxi(end-x,height)
	image.resize(roundi(image.get_width()*factor),roundi(image.get_height()*factor),Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(280,280,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),(Vector2i(280,280)-image.get_size())/2)
	canvas.generate_mipmaps()
	return ImageTexture.create_from_image(canvas)

func cell(source: Image, column: int, top: float, bottom: float) -> Texture2D:
	var x := roundi(source.get_width()*column/4.0)
	var end := roundi(source.get_width()*(column+1)/4.0)
	var y := roundi(source.get_height()*top)
	var image := source.get_region(Rect2i(x,y,end-x,roundi(source.get_height()*bottom)-y))
	image.convert(Image.FORMAT_RGBA8)
	var factor := 240.0/maxi(image.get_width(),image.get_height())
	image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(256,256,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),(Vector2i(256,256)-image.get_size())/2)
	canvas.generate_mipmaps()
	return ImageTexture.create_from_image(canvas)

func compile_character_assets() -> void:
	var icons := Image.load_from_file("res://assets/ui/swarm/characters/abilities.png")
	for row in 6:
		for column in 4:
			var texture := cell(icons,column,row/6.0,(row+1)/6.0)
			var path := "res://assets/ui/swarm/characters/ability-"+str(200+row*4+column)+".res"
			if ResourceSaver.save(texture,path,ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot save character icon: "+path)
	for id in ["seraföhn","löwina"]:
		var source := Image.load_from_file(ROOT+id+"-sheet.png")
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for row in 3:
			var name: String = ["idle","walk","shoot"][row]
			frames.add_animation(name)
			frames.set_animation_speed(name,[4,8,24][row])
			for column in 4: frames.add_frame(name,cell(source,column,row/3.0,(row+1)/3.0))
		if ResourceSaver.save(frames,ROOT+id+".res",ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot save character frames: "+id)

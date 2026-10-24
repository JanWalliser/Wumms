extends RefCounted
static var artwork: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not artwork.has(id):
		var path := "res://assets/projectiles/arsenal/"+id+".res"
		if not FileAccess.file_exists(path): return null
		artwork[id]=load(path)
	return artwork[id]

static func companion_texture(id: String) -> Texture2D:
	var key := "companion-"+id
	if not artwork.has(key):
		var sheet := texture("arsenal-companions")
		if sheet==null: return null
		var regions := {"bear":Rect2(0,0,680,615),"drone":Rect2(695,55,585,565),"train":Rect2(0,625,720,585),"mine":Rect2(730,645,550,565)}
		var part := AtlasTexture.new()
		part.atlas=sheet
		part.region=regions[id]
		part.filter_clip=true
		artwork[key]=part
	return artwork[key]

static func sprite(item, image: Texture2D, center: Vector2, width: float, tint := Color.WHITE) -> void:
	if image==null: return
	var size := image.get_size()*width/image.get_width()
	item.draw_texture_rect(image,Rect2(center-size*0.5,size),false,tint)

# Runtime vector effects: the visible footprint and hit footprint use one radius.
static func palette(style: String) -> Color:
	if style=="dark_vortex": return Color("bb79ff")
	if style=="vortex": return Color("86a8ff")
	if style.contains("fire") or style.contains("shortbow") or style.contains("gatling") or style=="pickup_bomb": return Color("ffa83d")
	if style.contains("ember") or style.contains("owo"): return Color("d58cff")
	if style.contains("lioness") or style in ["crescent","light_ray"]: return Color("ffe9a0")
	if style.contains("blade") or style=="slicer": return Color("b6a4ff")
	if style.contains("meow"): return Color("ff77c8")
	return Color("69edff")

static func glow(item, center: Vector2, radius: float, color: Color, opacity: float = 0.12) -> void:
	for layer in range(4,0,-1):
		item.draw_circle(center,radius*(0.6+layer*0.28),Color(color,opacity/float(layer)),true,-1,true)

static func draw_projectile(item, style: String, radius: float, time: float) -> void:
	if preload("res://scripts/combat/arsenal_vfx.gd").projectile(item,style,time): return
	var color := palette(style)
	var r := clampf(radius,3.0,22.0)
	if style=="hostile":
		preload("res://scripts/combat/animated_fx.gd").draw(item,"pellet",time,Vector2.ZERO,Vector2(28,20),Color(1,0.45,0.25))
		return
	if style in ["uwu","owo"] and texture("uwu-pulse")!=null:
		var tint := Color("efb1ff") if style=="owo" else Color.WHITE
		# Each shot is a compact pellet. Its short wake never joins the next shot.
		preload("res://scripts/combat/animated_fx.gd").draw(item,"pellet",time,Vector2.ZERO,Vector2.ONE*30,tint)
		return
	if style=="sea_mine" and companion_texture("mine")!=null:
		item.draw_set_transform(Vector2.ZERO,sin(time*5)*0.12,Vector2.ONE)
		sprite(item,companion_texture("mine"),Vector2.ZERO,25)
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return
	var shaped := {"weapon_blade_o_rang":"painted-boomerang","batblade":"painted-batblade","crescent":"painted-crescent","light_ray":"painted-crescent"}
	if shaped.has(style) and texture(shaped[style])!=null:
		var spin := time*12 if style=="weapon_blade_o_rang" else 0.0
		item.draw_set_transform(Vector2.ZERO,spin,Vector2.ONE)
		sprite(item,texture(shaped[style]),Vector2.ZERO,35 if style!="light_ray" else 48)
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return
	if style in ["crossbow","fire_arrow","embershot","slicer"]:
		var image := texture("schnitzel-slicer" if style=="slicer" else ("bunny-bolt" if style=="crossbow" else "snack-arrow"))
		if image!=null:
			var evolved: bool = item.attacker_stats.get("evolved",false)
			var fade := minf(1,time/0.09)*clampf((item.lifetime-time)/0.15,0,1)
			var at := Vector2.ZERO
			if style in ["fire_arrow","embershot"]:
				at=Vector2(0,-sin(clampf(time/0.5,0,1)*PI)*36).rotated(-item.rotation)
			var width: float = item.missile_display_width if style=="slicer" else (36.0 if style!="crossbow" else 32.0)
			var size := image.get_size()*(width/image.get_width())
			var tint := Color("e6c8ff") if evolved else Color.WHITE
			if style=="slicer":
				for i in range(3,0,-1):
					item.draw_set_transform(Vector2.ZERO,time*7-i*0.13,Vector2.ONE)
					item.draw_texture_rect(image,Rect2(-size*0.5,size),false,Color(tint,fade*0.035))
				item.draw_set_transform(Vector2.ZERO,time*7,Vector2.ONE)
				item.draw_texture_rect(image,Rect2(-size*0.5,size),false,Color(tint,fade))
				item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			else:
				var trail := Color("ffbc63") if style!="crossbow" else Color("74e5ee")
				if style in ["fire_arrow","embershot"]:
					preload("res://scripts/combat/arsenal_vfx.gd").draw(item,"flame",time,at-Vector2(11,0),Vector2(18,12),Color(1,1,1,fade*0.7))
				item.draw_line(at-Vector2(24,0),at-Vector2(6,0),Color(trail,fade*0.22),3,true)
				item.draw_texture_rect(image,Rect2(at-size*0.5,size),false,Color(tint,fade))
			return
	if style in ["fire_arrow","embershot"]:
		var lift := -sin(clampf(time/maxf(0.15,item.initial_pos.distance_to(item.ground_target)/maxf(1,item.speed)),0,1)*PI)*25
		var center := Vector2(0,lift).rotated(-item.rotation)
		glow(item,center,r*1.3,color)
		item.draw_line(center-Vector2(20,0),center,color,4,true)
		item.draw_colored_polygon(PackedVector2Array([center+Vector2(9,0),center+Vector2(-4,-5),center+Vector2(-1,0),center+Vector2(-4,5)]),Color("fff0ad"))
	elif style in ["crescent","light_ray"] or style.contains("lioness"):
		var extent := 20.0 if style!="light_ray" else 42.0
		glow(item,Vector2.ZERO,extent*0.7,color,0.07)
		item.draw_arc(Vector2(-extent*0.5,0),extent,-1.15,1.15,20,color,4,true)
		item.draw_arc(Vector2(-extent*0.5,0),extent*0.82,-1.08,1.08,20,Color("fff9e6"),1.5,true)
	elif style=="slicer" or style.contains("slicers") or style.contains("blade_o_rang"):
		item.draw_set_transform(Vector2.ZERO,time*9,Vector2.ONE)
		glow(item,Vector2.ZERO,r,color,0.08)
		for index in 3:
			var a := TAU*index/3
			var points := PackedVector2Array([Vector2.ZERO,Vector2.from_angle(a)*r*1.4,Vector2.from_angle(a+0.55)*r,Vector2.from_angle(a+1.4)*r*0.4])
			item.draw_colored_polygon(points,Color("b8cddd"))
			item.draw_line(points[1],points[2],color,2,true)
		item.draw_circle(Vector2.ZERO,r*0.25,color)
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	elif style in ["vortex","dark_vortex"]:
		glow(item,Vector2.ZERO,r*1.8,color,0.13)
		for index in 3:
			var angle := time*8+index*TAU/3
			item.draw_arc(Vector2.ZERO,r*(0.55+index*0.3),angle,angle+PI*1.2,16,color,1.8,true)
		item.draw_circle(Vector2.ZERO,r*0.4,Color("f3e7ff"))
	elif style=="meow":
		# Three visual rounds remain ONE damage cluster, never three hit callbacks.
		for index in 3:
			preload("res://scripts/combat/animated_fx.gd").draw(item,"jinx_round",time+index*0.015,Vector2(-index*2,(index-1)*2.5),Vector2(15,9))
	elif style in ["crossbow","batblade"]:
		var points := PackedVector2Array([Vector2(12,0),Vector2(-7,-4),Vector2(-3,0),Vector2(-7,4)])
		item.draw_colored_polygon(points,Color("d9aaff") if style=="batblade" else Color("9beeff"))
	elif style=="sea_mine":
		item.draw_circle(Vector2.ZERO,8,Color("435163"))
		for index in 6:
			var direction := Vector2.from_angle(index*TAU/6+time*3)
			item.draw_line(direction*7,direction*12,Color("efa860"),3,true)
		item.draw_circle(Vector2.ZERO,3,Color("ffeb8d"))
	else:
		glow(item,Vector2.ZERO,r*1.5,color,0.15)
		var tail := 18.0 if style in ["uwu","owo"] else 12.0
		item.draw_line(Vector2(-tail,0),Vector2.ZERO,Color(color,0.35),r*2.2,true)
		item.draw_line(Vector2(-tail*0.7,0),Vector2.ZERO,color,r*1.15,true)
		item.draw_circle(Vector2.ZERO,r,Color("e8fcff"))
		item.draw_arc(Vector2.ZERO,r*1.4,0,TAU,16,color,1.2,true)

static func draw_effect(item) -> bool:
	var visual: String = item.config.get("visual","")
	if visual=="impact" and item.config.get("weapon_id","")=="weapon_meow_meow":
		preload("res://scripts/combat/animated_fx.gd").draw(item,"jinx_hit",item.age,Vector2.ZERO,Vector2.ONE*18,Color.WHITE,0.16)
		return true
	if preload("res://scripts/combat/arsenal_vfx.gd").effect(item): return true
	if visual=="lightning_chain":
		var end: Vector2 = item.direction*float(item.config.get("length",100))
		var points := PackedVector2Array([Vector2.ZERO])
		for i in range(1,9): points.append(end*float(i)/9+item.direction.orthogonal()*sin(i*2.3+item.age*80)*5)
		points.append(end)
		var fade := 1-clampf(item.age/0.15,0,1)
		item.draw_polyline(points,Color(0.5,0.55,1,fade*0.22),7,true)
		item.draw_polyline(points,Color(0.85,0.88,1,fade),1.6,true)
		return true
	if visual=="landing":
		var radius := float(item.config.get("radius",40))
		var progress := clampf(item.age/0.5,0,1)
		item.draw_circle(Vector2.ZERO,radius,Color("ffc26d",0.045))
		item.draw_arc(Vector2.ZERO,radius,0,TAU,48,Color("ffc26d",0.35),1,true)
		item.draw_arc(Vector2.ZERO,radius*progress,-PI/2,TAU-PI/2,48,Color("ffe1a7",0.6),1.5,true)
		return true
	if visual=="fire" and texture("ember-pool")!=null:
		var radius := float(item.config.get("radius",40))
		var duration := float(item.config.get("duration",5))
		var fade := minf(1,item.age/0.12)*clampf((duration-item.age)/0.4,0,1)
		var tint := Color("d0a5ff") if item.config.get("evolved",false) else Color.WHITE
		var image := texture("ember-pool")
		for layer in 2:
			var angle: float = item.age*(0.12 if layer==0 else -0.09)+layer*1.7
			var pulse: float = 1+0.018*sin(item.age*5+layer)
			item.draw_set_transform(Vector2.ZERO,angle,Vector2.ONE*pulse)
			item.draw_texture_rect(image,Rect2(-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(tint,fade*(0.65 if layer==0 else 0.22)))
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		for i in 7:
			var phase := fposmod(item.age*0.7+i*0.173,1)
			var at := Vector2.from_angle(i*2.4)*radius*0.65+Vector2(sin(item.age*2+i)*3,-phase*15)
			item.draw_circle(at,1.0,Color(tint,(1-phase)*fade*0.6))
		return true
	var warmup := float(item.config.get("warmup",0))
	if visual.is_empty() and warmup<=0: return false
	var radius := float(item.config.get("radius",60))
	var color := palette(str(item.config.get("weapon_id",visual)))
	var hostile: bool = is_instance_valid(item.source) and item.source.is_in_group("enemies")
	if hostile: color=Color("ff624c")
	if visual in ["bear","drone"]:
		var image := companion_texture(visual)
		if image!=null:
			var size := 36.0 if visual=="drone" else 57.0
			var pulse := 1+sin(item.age*8)*0.025
			if item.config.get("evolved",false): size*=1.25
			var shadow := PackedVector2Array()
			for i in 24: shadow.append(Vector2(cos(i*TAU/24)*size*0.36,9+sin(i*TAU/24)*size*0.12))
			item.draw_colored_polygon(shadow,Color(0,0,0,0.23))
			sprite(item,image,Vector2(0,sin(item.age*6)*1.2 if visual=="drone" else -absf(sin(item.age*9))*1.4),size*pulse)
			if item.age-item.last_visual_hit<0.2:
				preload("res://scripts/combat/arsenal_vfx.gd").draw(item,"slash" if visual=="bear" else "electric",item.age-item.last_visual_hit,item.to_local(item.visual_hit_position),Vector2.ONE*(radius if visual=="bear" else 26),Color.WHITE,0.2)
			if visual=="bear" and fposmod(item.age,0.5)<0.15:
				item.draw_arc(Vector2.ZERO,radius,item.direction.angle()-0.6,item.direction.angle()+0.6,16,Color("ffd195",0.5),2,true)
			return true
		var size := 12.0 if visual=="drone" else 23.0
		if item.config.get("evolved",false): size*=1.35
		item.draw_circle(Vector2.ZERO,size,Color("304c65"))
		item.draw_arc(Vector2.ZERO,size,0,TAU,24,Color("7cddff"),2,true)
		for side in [-1,1]:
			item.draw_circle(Vector2(side*size*0.65,-size*0.75),size*0.4,Color("ff8cd4") if visual=="drone" else Color("b9855d"))
			item.draw_circle(Vector2(side*size*0.3,-size*0.15),2.2,Color("91f6ff"))
		if visual=="bear": item.draw_arc(Vector2.ZERO,radius,item.direction.angle()-PI/2,item.direction.angle()+PI/2,24,Color("ffb36c",0.3),2,true)
		return true
	if visual=="train":
		item.draw_set_transform(Vector2.ZERO,item.direction.angle(),Vector2.ONE)
		if companion_texture("train")!=null:
			preload("res://scripts/combat/arsenal_vfx.gd").draw(item,"flame",item.age,Vector2(-25,0),Vector2.ONE*22,Color(1,1,1,0.55))
			# Artwork engine faces down/right in the sheet; compensate its painted heading.
			item.draw_set_transform(Vector2.ZERO,item.direction.angle()-0.55,Vector2.ONE)
			sprite(item,companion_texture("train"),Vector2.ZERO,110)
			item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			return true
		item.draw_style_box(_train_box(),Rect2(-30,-radius,60,radius*2))
		for index in 4: item.draw_rect(Rect2(-23,index*radius*0.45-radius*0.85,25,radius*0.25),Color("70ecff"))
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return true
	if visual in ["ice","electric","poison"]:
		color=Color("9deaff") if visual=="ice" else (Color("b0f47a") if visual=="poison" else Color("aa9bff"))
		item.draw_circle(Vector2.ZERO,radius,Color(color,0.12))
		item.draw_arc(Vector2.ZERO,radius,0,TAU,40,Color(color,0.5),1.3,true)
		for index in 12:
			var at := Vector2.from_angle(index*2.4)*radius*(0.3+float(index%4)*0.17)
			if visual=="poison":
				var phase := fposmod(item.age*0.6+index*0.17,1)
				item.draw_circle(at+Vector2(sin(item.age*2+index)*3,-phase*12),radius*(0.13+phase*0.06),Color(color,(1-phase)*0.16))
			elif visual=="ice":
				var ray := at.normalized()
				item.draw_colored_polygon(PackedVector2Array([at-ray*7,at+ray*10,at+ray.orthogonal()*4]),Color(color,0.7))
			else:
				item.draw_polyline(PackedVector2Array([at,at+Vector2(5,-9),at+Vector2(-3,-13),at+Vector2(2,-20)]),Color(color,0.6),1.5,true)
		return true
	if visual=="gatling":
		var angle: float = item.direction.angle()
		var half_angle := acos(float(item.config.get("cos_angle",0.97)))
		var footprint := PackedVector2Array([Vector2.ZERO])
		for index in 17: footprint.append(Vector2.from_angle(angle-half_angle+half_angle*2*index/16)*radius)
		item.draw_colored_polygon(footprint,Color(color,0.015))
		for index in 9:
			var ray := Vector2.from_angle(angle-half_angle+half_angle*2*index/8)
			var progress := fposmod(item.age*4+index*0.137,1)
			item.draw_set_transform(ray*(23+progress*maxf(0,radius-23)),ray.angle(),Vector2.ONE)
			preload("res://scripts/combat/animated_fx.gd").draw(item,"jinx_round",item.age+index*0.017,Vector2.ZERO,Vector2(13,7),Color(1,0.85,0.6))
			item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		glow(item,item.direction*12,9,color,0.18)
		if texture("gatling-turret")!=null:
			item.draw_set_transform(Vector2.ZERO,angle,Vector2.ONE)
			sprite(item,texture("gatling-turret"),Vector2(10-sin(item.age*45)*0.5,0),preload("res://scripts/combat/arsenal_vfx.gd").GATLING_SIZE)
			if fposmod(item.age,0.1)<0.07:
				preload("res://scripts/combat/animated_fx.gd").draw(item,"muzzle",item.age,Vector2(23,0),Vector2.ONE*14)
			item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return true
	if visual=="radiant":
		color=Color("9b91ff") if item.config.get("evolved",false) else Color("8af4ed")
		item.draw_circle(Vector2.ZERO,radius,Color(color,0.045))
		item.draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(color,0.35),1.2,true)
		for index in 8:
			var angle: float = index*TAU/8+item.age*0.35
			var position := Vector2.from_angle(angle)*radius*0.82
			item.draw_arc(Vector2.ZERO,radius*(0.25+fposmod(item.age*0.4,0.6)),angle,angle+0.3,8,Color(color,0.24),2,true)
			item.draw_circle(position,1.8,Color(color,0.8))
		return true
	if item.age<warmup or visual=="landing":
		var progress := clampf(item.age/maxf(0.01,warmup),0,1)
		item.draw_circle(Vector2.ZERO,radius,Color(color,0.045))
		item.draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(color,0.65),1.5,true)
		item.draw_arc(Vector2.ZERO,radius*0.85,-PI/2,-PI/2+TAU*progress,64,color,2.5,true)
		for index in 4:
			var ray := Vector2.from_angle(index*PI/2)
			item.draw_line(ray*radius*0.55,ray*radius*0.8,color,2,true)
		if visual=="mine":
			if companion_texture("mine")!=null:
				sprite(item,companion_texture("mine"),Vector2.ZERO,25)
				return true
			glow(item,Vector2.ZERO,11,Color("f4a64e"))
			item.draw_circle(Vector2.ZERO,9,Color("263c52"))
			item.draw_arc(Vector2.ZERO,9,0,TAU,20,Color("c9d5dc"),2,true)
			for index in 6:
				var ray := Vector2.from_angle(index*TAU/6)
				item.draw_line(ray*7,ray*14,Color("c9d5dc"),3,true)
			item.draw_circle(Vector2.ZERO,3,Color("ff9250"))
		return true
	if visual=="fire":
		color=Color("c894ff") if item.config.get("evolved",false) else Color("ff9a32")
		item.draw_circle(Vector2.ZERO,radius,Color("241823",0.25))
		item.draw_circle(Vector2.ZERO,radius*0.92,Color(color,0.08))
		item.draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(color,0.65),1.5,true)
		for index in 13:
			var a := index*2.4
			var at := Vector2.from_angle(a)*radius*(0.2+0.55*float(index%5)/4)
			var height := 8+5*sin(item.age*7+index)
			var flame := PackedVector2Array([at+Vector2(-4,0),at+Vector2(-2,-height),at+Vector2(1,-height*0.6),at+Vector2(4,-height*1.3),at+Vector2(5,0)])
			item.draw_colored_polygon(flame,Color(color,0.6))
			item.draw_circle(at+Vector2(0,-2),2,Color("fff0b5"))
		return true
	if visual in ["orbital","mine","impact"] or warmup>0:
		var progress := clampf((item.age-warmup)/maxf(0.05,float(item.config.get("duration",1))-warmup),0,1)
		var fade := 1.0-progress
		glow(item,Vector2.ZERO,radius*(0.3+progress*0.5),color,0.13*fade)
		item.draw_arc(Vector2.ZERO,radius*(0.2+progress*0.8),0,TAU,64,Color(color,fade),3,true)
		if visual=="orbital":
			item.draw_line(Vector2(0,-radius*4),Vector2.ZERO,Color(color,fade*0.18),radius*0.7,true)
			item.draw_line(Vector2(0,-radius*4),Vector2.ZERO,Color("fff8dc",fade*0.65),8,true)
		for index in 8:
			var ray := Vector2.from_angle(index*TAU/8+0.2)
			item.draw_line(ray*radius*progress*0.45,ray*radius*progress,Color(color,fade),2,true)
		return true
	return false

static func _train_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color=Color("365068")
	box.border_color=Color("f4ba60")
	box.set_border_width_all(3)
	box.set_corner_radius_all(5)
	return box

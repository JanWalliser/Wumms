extends RefCounted

static var frames: SpriteFrames
const GATLING_SIZE := 30.0
const UWU_SIZE := 22.0

static func texture(name: String, age: float, duration: float = 0) -> Texture2D:
	if frames==null: frames=load("res://assets/vfx/arsenal/animations.res")
	var index := mini(3,int(clampf(age/maxf(0.001,duration),0,1)*4)) if duration>0 else int(age*12)%4
	if name=="flame" and duration<=0: index=[0,1,2,1][int(age*8)%4]
	return frames.get_frame_texture(name,index)

static func draw(item: CanvasItem, name: String, age: float, center: Vector2, size: Vector2, tint := Color.WHITE, duration: float = 0) -> void:
	item.draw_texture_rect(texture(name,age,duration),Rect2(center-size*0.5,size),false,tint)

static func projectile(item, style: String, age: float) -> bool:
	if style in ["uwu","owo"]:
		draw(item,"uwu_bolt",age,Vector2.ZERO,Vector2(24,16),Color("e6bdff") if style=="owo" else Color.WHITE)
		return true
	if style in ["vortex","dark_vortex"]:
		draw(item,"vortex",age,Vector2.ZERO,Vector2.ONE*32,Color("c9a0ff") if style=="dark_vortex" else Color.WHITE)
		return true
	if style=="weapon_winged_dagger":
		draw(item,"feather",age,Vector2.ZERO,Vector2(30,20))
		return true
	if style in ["weapon_sound_wave","weapon_guiding_hex","weapon_steel_tempest"]:
		draw(item,"radiant" if style=="weapon_sound_wave" else "vortex",age,Vector2.ZERO,Vector2.ONE*25)
		return true
	return false

static func effect(item) -> bool:
	var visual: String = item.config.get("visual","")
	var weapon: String = item.config.get("weapon_id","")
	var radius := float(item.config.get("radius",40))
	var duration := float(item.config.get("duration",1))
	var warmup := float(item.config.get("warmup",0))
	var hostile: bool = is_instance_valid(item.source) and item.source.is_in_group("enemies")
	if visual=="uwu_emitter":
		item.draw_set_transform(Vector2.ZERO,item.direction.angle(),Vector2.ONE)
		draw(item,"uwu_gun",item.age,Vector2(0,-4.5),Vector2.ONE*UWU_SIZE)
		var fired: float = item.age-float(item.config.get("last_fire",0))
		if fired<0.14: draw(item,"uwu_flash",fired,Vector2(UWU_SIZE*0.41,0),Vector2.ONE*15,Color.WHITE,0.14)
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return true
	if visual=="landing":
		draw(item,"radiant",item.age,Vector2.ZERO,Vector2.ONE*radius*2,Color(1,0.65,0.25,0.35))
		item.draw_arc(Vector2.ZERO,radius,-PI/2,-PI/2+TAU*clampf(item.age/maxf(0.001,duration),0,1),64,Color(1,0.72,0.3,0.7),1.4,true)
		return true
	if visual in ["sound","solar","eclipse"]:
		var tint := Color("ff9edb") if visual=="sound" else Color("ffcb69")
		var fade := clampf((duration-item.age)/0.2,0,1)
		if item.age < warmup:
			item.draw_circle(Vector2.ZERO,radius,Color(tint,0.07),true,-1,true)
			item.draw_arc(Vector2.ZERO,radius,-PI/2,-PI/2+TAU*item.age/maxf(warmup,0.001),64,Color(tint,0.8),2,true)
		else:
			var progress := clampf((item.age-warmup)/maxf(0.01,duration-warmup),0,1)
			draw(item,"radiant" if visual!="solar" else "orbital",item.age-warmup,Vector2.ZERO,Vector2.ONE*radius*2,Color(tint,0.55*fade))
			item.draw_arc(Vector2.ZERO,radius*(0.4+0.6*progress),0,TAU,64,Color(tint,0.5*fade),1.5,true)
		return true
	if visual=="enemy_slam":
		if item.age<warmup:
			var progress := clampf(item.age/maxf(0.001,warmup),0,1)
			item.draw_circle(Vector2.ZERO,radius,Color(0.5,0.06,0.02,0.12),true,-1,true)
			draw(item,"radiant",item.age,Vector2.ZERO,Vector2.ONE*radius*2,Color(1,0.32,0.18,0.45))
			item.draw_circle(Vector2.ZERO,radius*progress,Color(1,0.19,0.05,0.08),true,-1,true)
			item.draw_arc(Vector2.ZERO,radius,-PI/2,-PI/2+TAU*progress,72,Color(1,0.55,0.16,0.9),2,true)
			item.draw_arc(Vector2.ZERO,radius,0,TAU,72,Color(1,0.3,0.12,0.5),1,true)
		else:
			draw(item,"orbital",item.age-warmup,Vector2.ZERO,Vector2.ONE*radius*2,Color.WHITE,maxf(0.1,duration-warmup))
		return true
	if visual in ["fire","poison","ice","electric","radiant","heal"]:
		var name: String = {"fire":"flame","ice":"frost","heal":"radiant"}.get(visual,visual)
		var fade := minf(1,item.age/0.12)*clampf((duration-item.age)/0.45,0,1)
		var tint := Color("cba4ff") if item.config.get("evolved",false) else Color.WHITE
		if visual=="heal": tint=Color("9affb0")
		var alpha := 0.45 if visual in ["radiant","heal"] else (0.65 if visual=="fire" else 0.75)
		draw(item,name,item.age,Vector2.ZERO,Vector2.ONE*radius*2,Color(tint,alpha*fade))
		return true
	if visual=="lightning_chain":
		var end: Vector2 = item.direction*float(item.config.get("length",100))
		var points := PackedVector2Array([Vector2.ZERO])
		for index in range(1,12): points.append(end*index/12+item.direction.orthogonal()*sin(index*2.4+item.age*70)*4)
		points.append(end)
		item.draw_polyline(points,Color(0.5,0.4,1,0.25),7,true)
		item.draw_polyline(points,Color(0.85,0.85,1,0.9),1.3,true)
		draw(item,"electric",item.age,end,Vector2.ONE*23,Color.WHITE,0.15)
		return true
	var type := ""
	if visual=="orbital": type="orbital"
	elif visual=="mine": type="orbital"
	elif visual=="impact": type="uwu_hit" if weapon=="weapon_uwu_blaster" else ("slash" if weapon in ["weapon_slicers","weapon_blade_o_rang","weapon_batblades","weapon_lioness"] else "electric")
	elif weapon=="weapon_shield_slam": type="shield"
	elif weapon=="weapon_tentacle_slam": type="tentacle"
	elif weapon=="weapon_pillory_swipe": type="slash"
	elif weapon=="weapon_steel_tempest": type="vortex" if item.config.get("mode","")=="train" else "slash"
	elif weapon=="weapon_bunny_hop": type="orbital"
	if not type.is_empty():
		if item.age<warmup: return false # Existing precise charge marker remains visible.
		var age: float = item.age-warmup
		var fade := clampf((duration-item.age)/0.15,0,1)
		if str(item.config.get("mode",""))=="cone": item.draw_set_transform(Vector2.ZERO,item.direction.angle(),Vector2.ONE)
		var interval := float(item.config.get("interval",0.5))
		var playback: float = fposmod(age,interval) if duration>1 and warmup<=0 else age
		draw(item,type,playback,Vector2.ZERO,Vector2.ONE*radius*2,Color(1,0.65,0.45,fade) if hostile else Color(1,1,1,fade),interval if duration>1 and warmup<=0 else duration-warmup)
		item.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return true
	return false

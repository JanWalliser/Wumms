extends RefCounted

static var frames: SpriteFrames
static var jinx_frames: SpriteFrames

static func texture(animation: String, age: float, duration: float = 0.0) -> Texture2D:
	if frames==null: frames=load("res://assets/actors/animated/weapon-fx.res")
	if animation.begins_with("jinx_"):
		if jinx_frames==null: jinx_frames=load("res://assets/actors/animated/jinx-primary-fx.res")
		return jinx_frames.get_frame_texture(animation,int(age*24)%4 if duration<=0 else mini(3,int(clampf(age/duration,0,1)*4)))
	if frames==null or not frames.has_animation(animation): return null
	var count := frames.get_frame_count(animation)
	var index := mini(count-1,int(clampf(age/maxf(duration,0.001),0,1)*count)) if duration>0 else int(age*frames.get_animation_speed(animation))%count
	return frames.get_frame_texture(animation,index)

static func draw(item: CanvasItem, animation: String, age: float, center: Vector2, size: Vector2, tint: Color = Color.WHITE, duration: float = 0.0) -> void:
	var image := texture(animation,age,duration)
	if image!=null: item.draw_texture_rect(image,Rect2(center-size*0.5,size),false,tint)

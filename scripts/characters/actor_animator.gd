extends RefCounted

# Shared frame resources; one small clock per actor, no per-actor texture allocation.
static var cache: Dictionary = {}
static var bounds_cache: Dictionary = {}
const VISUAL_MULTIPLIERS := {"jankz":1.8,"mini_boss":3.8}
var visual_top := -32.0
const SIZES := {"jankz":48.0,"seraföhn":48.0,"löwina":48.0,"standard_grunt":36.0,"fast_runner":32.0,"ranged_spitter":36.0,"kamikaze_exploder":36.0,"heavy_tank":64.0,"aoe_bruiser":56.0,"support_buffer":36.0,"elite_variant":64.0,"mini_boss":112.0,"boss_reksai":120.0,"boss_briar":120.0,"boss_belveth":120.0}
var frames: SpriteFrames
var sprite: Sprite2D
var clock := 0.0
var recoil := 0.0
var base_position := Vector2.ZERO
var canvas_size := 0.0
var animation := "idle"
var frame_index := 0
var rest_scale := Vector2.ONE
var directional := false
var facing_sector := 0
var fire_direction := Vector2.RIGHT
var fire_clock := 0.0
var attack_duration := 0.14
const DIRECTIONS := ["e","se","s","se","e","ne","n","ne"]

static func sector(direction: Vector2) -> int:
	return posmod(roundi(preload("res://scripts/maps/world_projection.gd").screen_direction(direction).angle()/(PI/4)),8)

func setup(target: Sprite2D, id: String, actor_scale: float) -> void:
	sprite=target
	frames=null
	directional=false
	facing_sector=0
	fire_direction=Vector2.RIGHT
	fire_clock=0
	sprite.position=Vector2.ZERO
	sprite.rotation=0
	sprite.flip_h=false
	rest_scale=sprite.scale
	visual_top=-sprite.texture.get_height()*sprite.scale.y*0.5 if sprite.texture else -32.0
	if not SIZES.has(id):
		sprite.scale.y/=preload("res://scripts/maps/world_projection.gd").ground_scale().y
		rest_scale=sprite.scale
		visual_top=-sprite.texture.get_height()*sprite.scale.y*0.5 if sprite.texture else -32.0
		return
	directional=id=="jankz"
	var path := "res://assets/actors/animated/"+id+("-directional" if directional else "")+".res"
	if not cache.has(id): cache[id]=load(path)
	frames=cache[id]
	attack_duration = 0.14
	if not directional and frames.has_animation("shoot"):
		attack_duration = frames.get_frame_count("shoot")/frames.get_animation_speed("shoot")
	canvas_size=SIZES[id]
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale=Vector2.ONE*(canvas_size/256.0)*actor_scale*float(VISUAL_MULTIPLIERS.get(id,1.0))
	var enemy_scale := 1.0
	if EnemyRegistry.enemies.has(id) and is_instance_valid(GameManager.current_map) and GameManager.current_map.has_method("get_enemy_visual_scale"):
		enemy_scale=GameManager.current_map.get_enemy_visual_scale()
		sprite.scale*=enemy_scale
	rest_scale=sprite.scale
	base_position=Vector2(0,-canvas_size*0.29)*actor_scale*enemy_scale
	var projection_y: float=preload("res://scripts/maps/world_projection.gd").ground_scale().y
	sprite.scale.y/=projection_y
	rest_scale=sprite.scale
	base_position.y/=projection_y
	var reference: Texture2D = frames.get_frame_texture("idle_e" if directional else "idle",0)
	if not bounds_cache.has(id):
		var top := float(reference.get_height())
		for name in frames.get_animation_names():
			for index in frames.get_frame_count(name):
				top=minf(top,frames.get_frame_texture(name,index).get_image().get_used_rect().position.y)
		bounds_cache[id]={"top":top,"bottom":reference.get_image().get_used_rect().end.y,"height":reference.get_height()}
	var bounds: Dictionary = bounds_cache[id]
	if VISUAL_MULTIPLIERS.has(id) or EnemyRegistry.enemies.has(id):
		# Enlarge painted art around its ground contact, independently of physics.
		base_position.y=-(float(bounds["bottom"])-float(bounds["height"])*0.5)*sprite.scale.y
	visual_top=base_position.y+(float(bounds["top"])-float(bounds["height"])*0.5)*sprite.scale.y
	clock=fmod(float(sprite.get_instance_id()),97)/97.0
	recoil=0
	update(0,false,Vector2.RIGHT)

func attack(direction: Vector2 = Vector2.ZERO) -> void:
	if recoil<=0: fire_clock=0
	if not direction.is_zero_approx(): fire_direction=direction.normalized()
	recoil=attack_duration
	if directional: update(0,false,Vector2.ZERO)

func update(delta: float, moving: bool, direction: Vector2, frozen: bool = false) -> void:
	if frames==null or not is_instance_valid(sprite): return
	if not frozen:
		clock+=delta
		if recoil>0: fire_clock+=delta
		recoil=maxf(0,recoil-delta)
	animation="walk" if moving and not frozen else "idle"
	var playback_clock := clock
	if not directional and recoil > 0 and not frozen and frames.has_animation("shoot"):
		animation = "shoot"
		playback_clock = fire_clock
	if directional:
		if moving and not direction.is_zero_approx(): facing_sector=sector(direction)
		if recoil>0 and not frozen:
			facing_sector=sector(fire_direction)
			animation="shoot"
			playback_clock=fire_clock
		animation+="_"+DIRECTIONS[facing_sector]
		sprite.flip_h=facing_sector in [3,4,5]
	frame_index=int(playback_clock*frames.get_animation_speed(animation))%frames.get_frame_count(animation)
	var image := frames.get_frame_texture(animation,frame_index)
	if sprite.texture!=image: sprite.texture=image
	if not directional and absf(direction.x)>0.1: sprite.flip_h=direction.x<0
	var breathe := sin(clock*4)*0.35 if not moving and not frozen else 0.0
	var kick := sin(recoil/attack_duration*PI)*1.2
	var offset := -fire_direction*kick if directional else Vector2(-signf(direction.x)*kick,0)
	sprite.position=base_position+offset+Vector2(0,breathe)
	sprite.rotation=(-0.035 if sprite.flip_h else 0.035)*kick

func muzzle_position() -> Vector2:
	if frames==null or not directional: return sprite.global_position
	var anchors: Array = frames.get_meta("muzzle_"+DIRECTIONS[facing_sector])
	var point: Vector2 = anchors[frame_index%anchors.size()]-Vector2(frames.get_meta("frame_center",Vector2(128,128)))
	if sprite.flip_h: point.x=-point.x
	return sprite.to_global(point)

func overhead_anchor() -> Vector2:
	var growth := sprite.scale.y/maxf(0.0001,rest_scale.y) if is_instance_valid(sprite) else 1.0
	return Vector2(0,base_position.y+(visual_top-base_position.y)*growth-5.0)

extends RefCounted

const Animator = preload("res://scripts/characters/actor_animator.gd")
const FX = preload("res://scripts/combat/animated_fx.gd")

static func run(player: Node2D, suite: Node, enemy: Node2D) -> void:
	var animation = player.visual_animator
	animation.recoil=0
	suite.check(animation.frames!=null and animation.frames.get_frame_count("walk")==4 and animation.frames.get_frame_count("idle")==4,"Jinx has actual walk and idle image sequences")
	var position: Vector2 = player.global_position
	var radius: float = player.get_node("CollisionShape2D").shape.radius
	var stats: Dictionary = player.current_stats.duplicate(true)
	animation.clock=0
	animation.update(0,true,Vector2.RIGHT)
	var first: Texture2D = player.sprite.texture
	animation.update(0.1,true,Vector2.LEFT)
	suite.check(player.sprite.texture!=first and player.sprite.flip_h,"walk changes image and mirrors facing")
	animation.update(0.3,true,Vector2.RIGHT)
	suite.check(animation.frame_index==0 and not player.sprite.flip_h,"walk loops cleanly after four frames")
	animation.update(0.34,false,Vector2.RIGHT)
	suite.check(animation.animation=="idle_e" and animation.frame_index==0,"standing retains its directional idle pose")
	var clock: float = animation.clock
	animation.update(10,false,Vector2.RIGHT,true)
	suite.check(animation.clock==clock,"stun freezes actor animation clock")
	animation.attack()
	animation.update(0.07,false,Vector2.RIGHT)
	suite.check(animation.recoil>0 and absf(player.sprite.rotation)>0,"shooting adds a visible short recoil")
	suite.check(player.global_position==position and radius==player.get_node("CollisionShape2D").shape.radius and player.current_stats==stats,"animation cannot alter movement, stats or collision")
	for id in Animator.SIZES:
		var frames: SpriteFrames = load("res://assets/actors/animated/"+id+".res")
		suite.check(frames.get_frame_count("walk")==4,"four movement images for "+id)
		var hashes: Array = []
		for index in 4:
			var image := frames.get_frame_texture("walk",index).get_image()
			suite.check(image.get_size()==Vector2i(256,256) and image.has_mipmaps() and image.detect_alpha()!=Image.ALPHA_NONE,"transparent mipmapped animation frame "+id+str(index))
			hashes.append(image.get_data().hex_encode().hash())
		suite.check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2] and hashes[2]!=hashes[3],"movement images really differ for "+id)
	var other := Animator.new()
	var sprite := Sprite2D.new()
	other.setup(sprite,enemy.enemy_id,enemy.actor_scale)
	suite.check(other.frames==enemy.visual_animator.frames,"hundreds of enemies share the same frame resource")
	sprite.free()
	for kind in ["exhaust","muzzle","pellet","explosion"]:
		var a := FX.texture(kind,0)
		var b := FX.texture(kind,0.07)
		suite.check(a!=null and b!=null and a!=b,"VFX has changing painted frames: "+kind)
	animation.update(1,false,Vector2.RIGHT)

static func capture(player: Node2D, suite: Node) -> void:
	suite.clear_combat()
	for number in suite.get_tree().get_nodes_in_group("damage_numbers"): number.free()
	var actors: Array = []
	var ids := ["standard_grunt","fast_runner","ranged_spitter","kamikaze_exploder","heavy_tank","aoe_bruiser","support_buffer","elite_variant"]
	player.current_health=player.get_stat("max_health")
	player.is_downed=false
	for i in ids.size():
		var enemy = load("res://scenes/enemies/enemy_base.tscn").instantiate()
		enemy.enemy_id=ids[i]
		player.get_parent().add_child(enemy)
		enemy.set_physics_process(false)
		enemy.global_position=player.global_position+Vector2((i%4-1.5)*48,(-1 if i<4 else 1)*65)
		actors.append(enemy)
	for frame in 2:
		player.visual_animator.clock=frame*0.12
		player.visual_animator.update(0,true,Vector2.RIGHT)
		player.visual_animator.attack()
		for enemy in actors:
			enemy.visual_animator.clock=frame*0.13
			enemy.visual_animator.update(0,true,player.global_position-enemy.global_position)
		var rocket = player._spawn_jinx_rocket(Vector2.RIGHT,0,"r")
		rocket.global_position=player.global_position+Vector2(130,-15)
		rocket.elapsed_time=frame*0.08
		rocket.set_physics_process(false)
		for tick in 3: await suite.get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
		suite.get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/animated-actors-ingame-"+str(frame)+".png")
		rocket.free()
	for enemy in actors: enemy.free()

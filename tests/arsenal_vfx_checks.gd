extends RefCounted

const VFX = preload("res://scripts/combat/arsenal_vfx.gd")
const Animator = preload("res://scripts/characters/actor_animator.gd")

static func run(player: Node2D, suite: Node, enemy: Node2D) -> void:
	var saved := {"time":GameManager.game_time,"stats":player.current_stats.duplicate(true),"hp":player.current_health,"pos":player.global_position,"enemy_pos":enemy.global_position,"armor":enemy.armor,"enemy_hp":enemy.current_health,"augments":player.augments.duplicate()}
	suite.clear_combat()
	for name in ["flame","frost","electric","poison","vortex","radiant","shield","orbital","slash","feather","tentacle","uwu_gun","uwu_bolt","uwu_flash","uwu_hit"]:
		var a := VFX.texture(name,0)
		var b := VFX.texture(name,0.14)
		suite.check(a!=null and a!=b,"painted VFX changes image: "+name)
		for frame in 4:
			var image := VFX.frames.get_frame_texture(name,frame).get_image()
			suite.check(image.detect_alpha()!=Image.ALPHA_NONE and image.get_pixel(0,0).a==0 and image.has_mipmaps(),"transparent finished VFX with clean outer gutter: "+name+str(frame))
	suite.check(VFX.GATLING_SIZE==30 and Animator.SIZES["mini_boss"]==112,"smaller gatling and forty percent larger miniboss art")
	player.current_stats["damage_multiplier"]=1.8
	player.current_stats["crit_chance"]=1
	player.augments.clear()
	enemy.armor=100
	for rank in range(1,6):
		GameManager.game_time=200+rank*2
		var knives := WeaponInstance.new("weapon_slicers",player)
		knives.level=rank
		knives.fire()
		var health: float = enemy.current_health
		for blade in suite.owned_projectiles(player):
			for callback in 3: blade._handle_target_hit(enemy)
		var expected := roundf([55,55,60,60,65][rank-1]*1.8*0.5)
		suite.check(enemy.current_health==health-expected,"knife rank "+str(rank)+": damage bonus and armor applied once, no crit or blade-count multiplication")
		knives.evolve()
		knives.update(0)
		for blade in suite.owned_projectiles(player): blade._handle_target_hit(enemy)
		suite.check(enemy.current_health==health-expected,"evolution cannot bypass knife target lockout")
		suite.clear_combat()
	enemy.armor=0
	enemy.global_position=player.global_position+Vector2(100,0)
	var uwu := WeaponInstance.new("weapon_uwu_blaster",player)
	uwu.fire()
	var shot = suite.owned_projectiles(player)[0]
	var emitter = uwu.effect_node
	suite.check(emitter.config["visual"]=="uwu_emitter" and emitter.config["damage"]==0,"UwU has its own harmless animated gun")
	suite.check(shot.initial_pos.is_equal_approx(emitter.global_position+emitter.direction*VFX.UWU_SIZE*0.41),"UwU shot leaves its visible barrel instead of Jinx center")
	suite.check(shot.direction.is_equal_approx((enemy.global_position-shot.initial_pos).normalized()),"UwU emitter offset does not spoil targeting")
	emitter._physics_process(0.3)
	suite.check(emitter.done,"UwU firing mount expires after its burst instead of leaving a ghost weapon")
	suite.clear_combat()
	var mini = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	mini.enemy_id="mini_boss"
	player.get_parent().add_child(mini)
	mini.set_physics_process(false)
	mini.global_position=player.global_position+Vector2(60,0)
	mini.special_timer=0
	mini._process_special(0)
	var warning = suite.get_tree().get_nodes_in_group("runtime_effects")[0]
	suite.check(warning.config["radius"]==80 and warning.config["warmup"]==1.4,"miniboss slam has smaller exact radius and longer warning")
	var locked: Vector2 = warning.global_position
	warning._physics_process(1.39)
	suite.check(warning.hit_ids.is_empty(),"warning cannot deal early damage")
	player.global_position=locked+Vector2(81,0)
	warning._physics_process(0.02)
	suite.check(warning.global_position==locked and warning.hit_ids.is_empty(),"walking beyond the warned edge avoids the slam; marker does not track player")
	player.global_position=locked
	suite.clear_combat()
	mini.set_meta("miniboss_kind","artillery")
	mini.special_timer=0
	mini._process_special(0)
	player.global_position=locked+Vector2(42,0)
	var hits := 0
	for area in suite.get_tree().get_nodes_in_group("runtime_effects"):
		area._physics_process(1.4)
		hits+=area.hit_ids.size()
	suite.check(hits==1,"overlapping artillery zones share one damage budget per volley (hits="+str(hits)+", state="+str(GameManager.current_state)+")")
	mini.free()
	suite.clear_combat()
	player.set_meta("next_heal_visual",-1)
	player.current_health=player.get_stat("max_health")-50
	var before: float = player.current_health
	player.heal(10)
	var heal = suite.get_tree().get_nodes_in_group("runtime_effects")[0]
	heal._physics_process(0.2)
	suite.check(player.current_health==before+10 and heal.config["damage"]==0,"passive healing animation adds no extra healing or damage")
	suite.clear_combat()
	GameManager.game_time=saved["time"]
	player.current_stats=saved["stats"]
	player.current_health=saved["hp"]
	player.global_position=saved["pos"]
	player.augments=saved["augments"]
	enemy.global_position=saved["enemy_pos"]
	enemy.armor=saved["armor"]
	enemy.current_health=saved["enemy_hp"]

static func capture(player: Node2D, suite: Node) -> void:
	suite.clear_combat()
	for number in suite.get_tree().get_nodes_in_group("damage_numbers"): number.free()
	var mini = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	mini.enemy_id="mini_boss"
	player.get_parent().add_child(mini)
	mini.set_physics_process(false)
	mini.global_position=player.global_position+Vector2(140,-50)
	mini.visual_animator.update(0,true,Vector2.LEFT)
	for stage in 3:
		var effect := RuntimeEffect.spawn(player.get_parent(),mini,player.global_position+Vector2(115,55),{"visual":"enemy_slam","radius":80,"warmup":1.4,"duration":1.75,"damage":0})
		effect.age=[0.3,1.1,1.5][stage]
		effect.set_physics_process(false)
		effect.queue_redraw()
		for frame in 4: await suite.get_tree().process_frame
		RenderingServer.force_draw(false,1.0/60)
		suite.get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/miniboss-slam-stage-"+str(stage)+".png")
		effect.free()
	mini.free()

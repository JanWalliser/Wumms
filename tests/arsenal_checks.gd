extends RefCounted

static func run(player: Node2D, suite: Node, enemy: Node2D, second: Node2D) -> void:
	var time := GameManager.game_time
	var original_position: Vector2 = player.global_position
	var enemy_position: Vector2 = enemy.global_position
	var second_position: Vector2 = second.global_position
	player.passives.clear()
	player.augments.clear()
	player.temp_buffs.clear()
	player.recalculate_stats()
	player.current_stats["crit_chance"]=0
	player.current_stats["damage_multiplier"]=1
	GameManager.game_time=100
	var slicer := WeaponInstance.new("weapon_slicers",player)
	slicer.level=5
	slicer.fire()
	var blades: Array = suite.owned_projectiles(player)
	suite.check(blades.size()==6,"rank five has six slicers")
	for blade in blades:
		suite.check(is_equal_approx(blade.global_position.distance_to(player.global_position),40),"slicer starts on its orbit rather than overlapping at player center")
		suite.check(blade.hit_radius==10 and blade.orbit_speed==-2.5,"archived width and angular speed")
	var hp: float = enemy.current_health
	enemy.knockback_velocity=Vector2.ZERO
	for blade in blades:
		blade._handle_target_hit(enemy)
		blade._handle_target_hit(enemy)
	suite.check(enemy.current_health==hp-65,"six blades and duplicate collision callbacks share one target lockout")
	suite.check(is_equal_approx(enemy.knockback_velocity.length(),sqrt(54000.0)),"push distance converts to one bounded knockback impulse")
	GameManager.game_time+=0.999
	for blade in blades:
		blade.elapsed_time=0.999
		blade._handle_target_hit(enemy)
	suite.check(enemy.current_health==hp-65,"slicer cannot rehit before one second")
	GameManager.game_time+=0.002
	for blade in blades:
		blade.elapsed_time=1.001
		blade._handle_target_hit(enemy)
	suite.check(enemy.current_health==hp-130,"one new slicer hit is allowed after lockout")
	player.current_stats["bonus_projectiles"]=3
	slicer.update(0)
	suite.check(suite.owned_projectiles(player).size()==9,"projectile bonus updates existing ring without another bank")
	for blade in suite.owned_projectiles(player): blade._handle_target_hit(enemy)
	suite.check(enemy.current_health==hp-130,"new blades cannot bypass an existing shared lockout")
	slicer.evolve()
	slicer.update(0)
	suite.check(suite.owned_projectiles(player).size()==9,"evolution replaces ring state without duplicating blades")
	for blade in suite.owned_projectiles(player):
		suite.check(blade.hit_radius==13 and blade.orbit_radius==70 and blade.lifetime>10000,"evolved ring has archived radius/width and permanent lifetime")
	player.current_stats["area_multiplier"]=1.5
	slicer.update(0)
	suite.check(suite.owned_projectiles(player)[0].orbit_radius==105 and suite.owned_projectiles(player)[0].hit_radius==19.5,"area scales path and collision once")
	player.is_downed=true
	for blade in suite.owned_projectiles(player): blade._physics_process(0.01)
	suite.check(suite.owned_projectiles(player).is_empty(),"downing removes orbit damage immediately")
	player.is_downed=false
	suite.clear_combat()
	player.current_stats["bonus_projectiles"]=0
	player.current_stats["area_multiplier"]=1
	var crossbow := WeaponInstance.new("weapon_crossbow",player)
	crossbow.is_evolved=true
	crossbow.fire()
	var arrows: Array = suite.owned_projectiles(player)
	var mean := Vector2.ZERO
	for arrow in arrows: mean+=arrow.direction
	mean=mean.normalized()
	for arrow in arrows: suite.check(arrow.direction.dot(mean)>=-0.0001,"evolved ballista remains inside one semicircle")
	var bolt = arrows[0]
	bolt.attacker_stats["crit_chance"]=0
	hp=enemy.current_health
	bolt._handle_target_hit(enemy)
	bolt._handle_target_hit(enemy)
	suite.check(enemy.current_health==hp-170 and bolt.expired,"noncrit bolt deals one hit and stops")
	bolt=arrows[1]
	bolt.attacker_stats["crit_chance"]=1
	var hp_second: float = second.current_health
	bolt._handle_target_hit(second)
	suite.check(not bolt.expired and second.current_health==hp_second-340,"critical bolt deals critical damage and pierces")
	suite.clear_combat()
	player.global_position=Vector2(5000,5000)
	crossbow.fire()
	bolt=suite.owned_projectiles(player)[0]
	for i in 10:
		if not bolt.expired: bolt._physics_process(0.1)
	suite.check(bolt.expired and is_equal_approx(bolt.global_position.distance_to(bolt.initial_pos),340),"bolt reaches exact archived maximum range")
	suite.check(get_tree_effects(suite).is_empty(),"a bolt cannot turn into a rocket explosion at range end")
	suite.clear_combat()
	player.global_position=original_position
	var bow := WeaponInstance.new("weapon_shortbow",player)
	bow.fire()
	var arrow = suite.owned_projectiles(player)[0]
	arrow.ground_target=player.global_position+Vector2(180,0)
	arrow._physics_process(0.49)
	suite.check(suite.get_tree().get_nodes_in_group("ground_hazards").is_empty(),"shortbow waits its full half-second flight")
	arrow._physics_process(0.011)
	var fire = suite.get_tree().get_nodes_in_group("ground_hazards")[0]
	suite.check(arrow.expired and fire.global_position.distance_to(arrow.ground_target)<0.001,"shortbow lands at the fixed-time endpoint")
	enemy.global_position=fire.global_position
	hp=enemy.current_health
	GameManager.game_time+=10
	fire._damage_tick("area")
	var overlap := RuntimeEffect.spawn(player.get_parent(),player,fire.global_position+Vector2(25,0),{"visual":"fire","radius":40,"damage":20,"duration":5,"interval":0.5,"weapon_id":"weapon_shortbow","crit":false})
	overlap._damage_tick("area")
	suite.check(enemy.current_health==hp-20,"overlapping shortbow fire cannot multiply a single tick")
	GameManager.game_time+=0.5
	overlap._damage_tick("area")
	suite.check(enemy.current_health==hp-40,"fire ticks again after half a second")
	for id in ["bunny-bolt","snack-arrow","schnitzel-slicer","ember-pool"]:
		var image = preload("res://scripts/combat/weapon_visuals.gd").texture(id)
		suite.check(image!=null and image.get_image().detect_alpha()!=Image.ALPHA_NONE,"production artwork has real alpha: "+id)
	suite.clear_combat()
	enemy.global_position=enemy_position
	second.global_position=second_position
	GameManager.game_time=time
	player.recalculate_stats()

static func get_tree_effects(suite: Node) -> Array:
	return suite.get_tree().get_nodes_in_group("runtime_effects").filter(func(effect): return effect.config.get("visual","")=="rocket_explosion")
